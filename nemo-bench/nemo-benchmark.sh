#!/bin/bash
set -eo pipefail

# Check if LOG_DIR is set
if [ -z "$LOG_DIR" ]; then
    export LOG_DIR="/data/nemo/manual_run_$(date +%s)"
    mkdir -p $LOG_DIR
fi

echo ">>> Setting up NeMo Environment for Llama 375B Benchmark..."
HOSTFILE="/opt/hostfile"
NEMO_DIR="/opt/NeMo"

# Install NeMo if missing
if ! python -c "import nemo" &> /dev/null; then
    echo "NeMo not found. Installing..."
    pip install git+https://github.com/NVIDIA/NeMo.git@main#egg=nemo_toolkit[nlp]
fi

# Clone NeMo repo
if [ ! -d "$NEMO_DIR" ]; then
    echo "Cloning NeMo repo..."
    git clone https://github.com/NVIDIA/NeMo.git $NEMO_DIR
fi

# --- FIX: Patch Megatron Base Model for TypeError ---
MEGATRON_BASE_MODEL="$NEMO_DIR/nemo/collections/nlp/models/language_modeling/megatron_base_model.py"
if [ -f "$MEGATRON_BASE_MODEL" ]; then
    echo "Patching $MEGATRON_BASE_MODEL to fix TypeError..."
    # Replace the failing line with 'return False' to bypass the check safely
    sed -i 's/return re.fullmatch("\[0-9\]\[0-9\]\\\.\[0-9\]\[0-9\].\*", nvidia_torch_version).*/return False # Patched/' "$MEGATRON_BASE_MODEL"
else
    echo "Warning: $MEGATRON_BASE_MODEL not found. Skipping patch."
fi

# --- CONFIGURATION ---
# Llama-like 375B Config
# Approx 375B params
SEQ_LEN=8192
HIDDEN_SIZE=16384
FFN_HIDDEN_SIZE=65536
NUM_LAYERS=120
NUM_HEADS=128

# Parallelism for 3832 GPUs (479 nodes)
# We use TP=8, PP=8. This requires groups of 8 nodes.
# 479 nodes / 8 = 59.875. We use 59 * 8 = 472 nodes.
TP_SIZE=8
PP_SIZE=8
GPUS_PER_NODE=8

TOTAL_NODES=$(wc -l < $HOSTFILE)
USED_NODES=$(( (TOTAL_NODES / PP_SIZE) * PP_SIZE )) # Ensure divisible by PP_SIZE (assuming TP fits in node)
# Actually, for TP=8 (1 node), PP=8, we need 8 nodes per replica.
# So USED_NODES must be divisible by 8.

if [ "$USED_NODES" -eq 0 ]; then
    echo "Error: Not enough nodes for PP=$PP_SIZE"
    exit 1
fi

echo "Total Nodes Available: $TOTAL_NODES"
echo "Used Nodes: $USED_NODES"

# Create used hostfile
head -n $USED_NODES $HOSTFILE > /tmp/hostfile_used
HOSTS=($(cat /tmp/hostfile_used | awk '{print $1}'))

WORLD_SIZE=$((USED_NODES * GPUS_PER_NODE))
DP_SIZE=$((WORLD_SIZE / (TP_SIZE * PP_SIZE)))
MICRO_BATCH_SIZE=1
GLOBAL_BATCH_SIZE=$((DP_SIZE * MICRO_BATCH_SIZE)) 

echo ">>> Configuration:"
echo "  Model: Llama ~375B (H=$HIDDEN_SIZE, L=$NUM_LAYERS)"
echo "  Parallelism: TP=$TP_SIZE, PP=$PP_SIZE, DP=$DP_SIZE"
echo "  Nodes: $USED_NODES ($WORLD_SIZE GPUs)"
echo "  Batch Size: Global=$GLOBAL_BATCH_SIZE, Micro=$MICRO_BATCH_SIZE"

# --- TORCHRUN LAUNCH ---
MASTER_ADDR=$(hostname -i)
MASTER_PORT=29500

# Optimization Flags
# - Distributed Optimizer (ZeRO-1 equivalent for optimizer states)
# - Flash Attention
# - Transformer Engine (FP8)
# - Sequence Parallelism (reduces activation memory)

CMD="torchrun \
  --nproc_per_node=$GPUS_PER_NODE \
  --nnodes=$USED_NODES \
  --rdzv_id=nemo_bench \
  --rdzv_backend=c10d \
  --rdzv_endpoint=$MASTER_ADDR:$MASTER_PORT \
  $NEMO_DIR/examples/nlp/language_modeling/megatron_gpt_pretraining.py \
  --config-path=conf \
  --config-name=megatron_gpt_config \
  trainer.devices=$GPUS_PER_NODE \
  trainer.num_nodes=$USED_NODES \
  trainer.accelerator=gpu \
  trainer.precision=bf16 \
  trainer.max_steps=50 \
  trainer.log_every_n_steps=1 \
  trainer.val_check_interval=0 \
  trainer.limit_val_batches=0 \
  exp_manager.exp_dir=$LOG_DIR \
  exp_manager.name='llama_375b_bench' \
  exp_manager.create_checkpoint_callback=False \
  model.micro_batch_size=$MICRO_BATCH_SIZE \
  model.global_batch_size=$GLOBAL_BATCH_SIZE \
  model.tensor_model_parallel_size=$TP_SIZE \
  model.pipeline_model_parallel_size=$PP_SIZE \
  model.encoder_seq_length=$SEQ_LEN \
  model.hidden_size=$HIDDEN_SIZE \
  model.ffn_hidden_size=$FFN_HIDDEN_SIZE \
  model.num_layers=$NUM_LAYERS \
  model.num_attention_heads=$NUM_HEADS \
  model.use_cpu_initialization=True \
  model.activation=swiglu \
  model.position_embedding_type=rope \
  model.normalization=rmsnorm \
  +model.transformer_engine.enabled=True \
  +model.transformer_engine.fp8_enabled=True \
  model.data.data_impl='mock' \
  model.data.data_prefix="/tmp/dummy" \
  model.optim.name=distributed_fused_adam \
  +model.optim.bucket_cap_mb=200 \
  +model.optim.overlap_grad_sync=True \
  +model.optim.overlap_param_sync=True \
  model.sequence_parallel=True \
  "

echo ">>> Launching Torchrun on $USED_NODES nodes..."
echo "Results will be saved to: $LOG_DIR"

pids=()
for i in "${!HOSTS[@]}"; do
    NODE=${HOSTS[$i]}
    # echo "Starting on $NODE (Rank $i)..."
    # Use ssh to run command. 
    # We assume passwordless SSH is set up (which it is by env-nemo.sh)
    ssh -n $NODE "cd $PWD; export NODE_RANK=$i; $CMD" &
    pids+=($!)
done

# Wait for all processes
FAILED=0
for pid in "${pids[@]}"; do
    wait $pid || FAILED=1
done

if [ $FAILED -eq 0 ]; then
    echo ">>> Benchmark Completed Successfully."
else
    echo ">>> Benchmark Failed."
    exit 1
fi
