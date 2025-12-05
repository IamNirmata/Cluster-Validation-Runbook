#!/bin/bash
set -eo pipefail

# Check if LOG_DIR is set (from server-nemo.sh), default if missing
if [ -z "$LOG_DIR" ]; then
    export LOG_DIR="/data/nemo/manual_run_$(date +%s)"
    mkdir -p $LOG_DIR
fi

echo ">>> Setting up NeMo Environment..."
HOSTFILE="/opt/hostfile"
NEMO_DIR="/opt/NeMo"

# Install NeMo if missing
if ! python -c "import nemo" &> /dev/null; then
    echo "NeMo not found. Installing..."
    pip install git+https://github.com/NVIDIA/NeMo.git@main#egg=nemo_toolkit[nlp]
fi

# Clone NeMo repo for the examples script
if [ ! -d "$NEMO_DIR" ]; then
    echo "Cloning NeMo repo..."
    git clone https://github.com/NVIDIA/NeMo.git $NEMO_DIR
fi

# Calculate World Size
NNODES=$(wc -l < $HOSTFILE)
GPUS_PER_NODE=8
WORLD_SIZE=$((NNODES * GPUS_PER_NODE))

echo "Running on $NNODES nodes ($WORLD_SIZE GPUs total)"

# Benchmark Config (Synthetic Data)
SEQ_LEN=2048
HIDDEN_SIZE=1024
FFN_HIDDEN_SIZE=4096
NUM_LAYERS=24
NUM_HEADS=16
MICRO_BATCH_SIZE=4
GLOBAL_BATCH_SIZE=$((WORLD_SIZE * MICRO_BATCH_SIZE)) 

echo ">>> Starting MPI Run..."
echo "Results will be saved to: $LOG_DIR"

# Run MPI
# We add `tee` here as a backup to capture specifically the mpirun output 
mpirun --allow-run-as-root \
  --hostfile $HOSTFILE \
  -np $WORLD_SIZE \
  -npernode $GPUS_PER_NODE \
  --bind-to none \
  --map-by slot \
  -x NCCL_DEBUG=INFO \
  -x MASTER_ADDR=$MASTER_ADDR \
  -x MASTER_PORT=$MASTER_PORT \
  -x PATH \
  -x LD_LIBRARY_PATH \
  -x PYTHONPATH=$NEMO_DIR \
  python $NEMO_DIR/examples/nlp/language_modeling/megatron_gpt_pretraining.py \
    --config-path=conf \
    --config-name=megatron_gpt_config \
    trainer.devices=$GPUS_PER_NODE \
    trainer.num_nodes=$NNODES \
    trainer.accelerator=gpu \
    trainer.precision=bf16 \
    trainer.max_steps=50 \
    trainer.log_every_n_steps=10 \
    trainer.val_check_interval=0 \
    trainer.limit_val_batches=0 \
    exp_manager.exp_dir=$LOG_DIR \
    exp_manager.name="nemo_benchmark" \
    exp_manager.create_checkpoint_callback=False \
    model.micro_batch_size=$MICRO_BATCH_SIZE \
    model.global_batch_size=$GLOBAL_BATCH_SIZE \
    model.tensor_model_parallel_size=1 \
    model.pipeline_model_parallel_size=1 \
    model.encoder_seq_length=$SEQ_LEN \
    model.hidden_size=$HIDDEN_SIZE \
    model.ffn_hidden_size=$FFN_HIDDEN_SIZE \
    model.num_layers=$NUM_LAYERS \
    model.num_attention_heads=$NUM_HEADS \
    model.data.data_impl="mock" \
    model.data.data_prefix=[]