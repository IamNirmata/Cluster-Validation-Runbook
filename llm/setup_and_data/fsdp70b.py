import os, json, inspect, time
import datetime
from typing import Tuple

import torch
import torch.distributed as dist
from datasets import Dataset, DatasetDict, load_from_disk
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainerCallback
from peft import LoraConfig, get_peft_model
from trl import SFTConfig, SFTTrainer

# -------------------- Env --------------------
MODEL_PATH   = os.environ.get("MODEL_PATH",   "/mnt/data/models/Llama-3.3-70B-Instruct")
DATASET_PATH = os.environ.get("DATASET_PATH", "/mnt/data/datasets/xlam-function-calling-60k")
OUTPUT_DIR   = os.environ.get("OUTPUT_DIR",   "/mnt/data/output/llama-3-70b-hybrid-shard")

os.environ.setdefault("WANDB_PROJECT", "func_calls_llm_hybrid")
os.environ.setdefault("WANDB_LOG_MODEL", "false") # Disable model logging to avoid massive upload

def _setup_ddp() -> Tuple[int, int, bool]:
    if not dist.is_available() or not torch.cuda.is_available():
        raise RuntimeError("Distributed training requires torch.distributed + CUDA.")
    
    # Initialize process group if not already initialized (Trainer might do it, but safe to check)
    if not dist.is_initialized():
        dist.init_process_group(backend="nccl", timeout=datetime.timedelta(seconds=7200))
    
    local_rank  = int(os.environ.get("LOCAL_RANK", 0))
    global_rank = int(os.environ.get("RANK", 0))
    torch.cuda.set_device(local_rank)
    
    is_main = (global_rank == 0)
    if is_main:
        print(f"Initialized DDP/FSDP: world={dist.get_world_size()} rank={global_rank} local_rank={local_rank}", flush=True)
    return global_rank, local_rank, is_main

def _format_example(example: dict, eos_token: str) -> dict:
    try:
        query      = example.get("query", "")
        tools_raw  = example.get("tools", "[]")
        answers_raw= example.get("answers", "[]")
        try:
            tools = "\n".join(str(x) for x in json.loads(tools_raw))
        except Exception:
            tools = str(tools_raw)
        try:
            answers = "\n".join(str(x) for x in json.loads(answers_raw))
        except Exception:
            answers = str(answers_raw)
        text = f"<user>{query}</user>\n\n<tools>{tools}</tools>\n\n<calls>{answers}</calls>{eos_token}"
        return {"text": text}
    except Exception as e:
        print(f"format error: {e}", flush=True)
        return {"text": ""}

def _load_splits(path: str) -> Tuple[Dataset, Dataset]:
    data = load_from_disk(path)
    if isinstance(data, DatasetDict):
        train_split = data.get("train") or next(iter(data.values()))
        eval_split  = data.get("validation") or data.get("test")
        if eval_split is None:
            split = train_split.train_test_split(test_size=0.01, seed=42) # Reduced test size for speed
            train_split, eval_split = split["train"], split["test"]
    else:
        split = data.train_test_split(test_size=0.01, seed=42)
        train_split, eval_split = split["train"], split["test"]
    return train_split, eval_split

class ThroughputCallback(TrainerCallback):
    def __init__(self, total_batch_size, seq_len):
        self.total_batch_size = total_batch_size
        self.seq_len = seq_len
        self.last_time = None

    def on_step_begin(self, args, state, control, **kwargs):
        self.last_time = time.time()

    def on_step_end(self, args, state, control, **kwargs):
        if self.last_time is None:
            return
        current_time = time.time()
        elapsed = current_time - self.last_time
        if elapsed > 0:
            tokens = self.total_batch_size * self.seq_len
            tps = tokens / elapsed
            print(f"Step {state.global_step}: {tps:,.2f} tokens/sec (approx) | Batch={self.total_batch_size}", flush=True)

def main():
    global_rank, local_rank, is_main = _setup_ddp()

    if is_main: print("Loading tokenizer...", flush=True)
    tokenizer = AutoTokenizer.from_pretrained(MODEL_PATH, trust_remote_code=True)
    if tokenizer.pad_token_id is None:
        if tokenizer.eos_token_id is not None:
            tokenizer.pad_token = tokenizer.eos_token
        else:
            tokenizer.add_special_tokens({"pad_token": "<|pad|>"})
            tokenizer.pad_token = "<|pad|>"
    tokenizer.padding_side = "right"

    train_raw, eval_raw = _load_splits(DATASET_PATH)
    train_ds = train_raw.map(lambda r: _format_example(r, tokenizer.eos_token),
                             remove_columns=train_raw.column_names, desc="Formatting train").filter(lambda r: len(r["text"])>0)
    eval_ds  = eval_raw.map(lambda r: _format_example(r, tokenizer.eos_token),
                             remove_columns=eval_raw.column_names,  desc="Formatting eval").filter(lambda r: len(r["text"])>0)

    # --- Training Config ---
    max_seq_length = 2048
    training_args = SFTConfig(
        output_dir=OUTPUT_DIR,
        dataset_text_field="text",
        max_length=max_seq_length,
        remove_unused_columns=False,
        report_to="wandb",  # Ensure WANDB_API_KEY is set or use "none"

        # BATCH SIZE configuration
        per_device_train_batch_size=4, 
        gradient_accumulation_steps=1, # Reduced from 8 since you have 3800 GPUs (Global Batch = 15,200)
        
        # --- HYBRID SHARDING CONFIGURATION ---
        # "hybrid_shard": Shards within node (8 GPUs), Replicates across nodes (475 nodes)
        fsdp="hybrid_shard auto_wrap", 
        fsdp_config={
            "fsdp_timeout": 7200,       # Increased for massive cluster
            "use_orig_params": True,
            "fsdp_transformer_layer_cls_to_wrap": ["LlamaDecoderLayer"],
            "activation_checkpointing": True,
            "limit_all_gathers": True,  # Helps reduce VRAM spikes
        },

        max_steps=50,  # Short run for benchmarking
        warmup_ratio=0.05,
        logging_steps=1,
        save_strategy="no", # Disable saving for pure performance benchmark
        learning_rate=1e-4,
        bf16=True,
        ddp_find_unused_parameters=False,
    )

    # --- Model Loading ---
    if is_main: print("Loading model...", flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_PATH, 
        torch_dtype=torch.bfloat16, 
        attn_implementation="flash_attention_2"
    )
    
    # LoRA Config
    peft_cfg = LoraConfig(
        r=16, lora_alpha=16, lora_dropout=0.05, bias="none", task_type="CAUSAL_LM",
        target_modules=["q_proj","k_proj","v_proj","o_proj","gate_proj","down_proj","up_proj"],
    )
    model = get_peft_model(model, peft_cfg)

    # Calculate global batch size for throughput logging
    world_size = dist.get_world_size() if dist.is_initialized() else 1
    total_batch_size = training_args.per_device_train_batch_size * training_args.gradient_accumulation_steps * world_size

    trainer = SFTTrainer(
        model=model,
        args=training_args,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        processing_class=tokenizer,
        max_seq_length=max_seq_length,
    )
    
    trainer.add_callback(ThroughputCallback(total_batch_size, max_seq_length))

    if is_main: print("Starting Hybrid Shard training...", flush=True)
    trainer.train()

    if is_main: print("Benchmark complete.", flush=True)
    dist.destroy_process_group()

if __name__ == "__main__":
    main()