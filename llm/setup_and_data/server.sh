source /data/Cluster-Validation-Runbook/llm/setup_and_data/1-data.sh
source /data/Cluster-Validation-Runbook/llm/setup_and_data/2-model.sh
bash   /data/Cluster-Validation-Runbook/llm/setup_and_data/3-copy-to-clients.sh

export MASTER_ADDR="$(hostname -i)"
export MASTER_PORT=12345

echo "Using Hostfile:"
cat /opt/hostfile

HOSTFILE=/opt/hostfile.mpi
cat "$HOSTFILE"

# Number of nodes = number of lines in hostfile
NP=$(wc -l < "$HOSTFILE")
NNODES="$NP"
WORLD_SIZE=$(( NNODES * 8 ))

echo "MASTER_ADDR: $MASTER_ADDR"
echo "MASTER_PORT: $MASTER_PORT"
echo "NNODES: $NNODES"
echo "WORLD_SIZE: $WORLD_SIZE"

mpirun \
  --allow-run-as-root \
  --hostfile "$HOSTFILE" \
  -np "$NP" \
  --bind-to none \
  bash -lc "
    export NODE_RANK=\$OMPI_COMM_WORLD_RANK
    export MASTER_ADDR=$MASTER_ADDR
    export MASTER_PORT=$MASTER_PORT
    export NNODES=$NNODES
    export WORLD_SIZE=$WORLD_SIZE
    export MODEL_PATH=/opt/llm/models/Meta-Llama-3-8B-Instruct
    export DATASET_PATH=/opt/llm/datasets/xlam-function-calling-60k
    export OUTPUT_DIR=/data/llm/output/llama-3-8b-function-calling-fsdp-no4

    export WANDB_API_KEY=\${WANDB_API_KEY}
    export WANDB_PROJECT=\${WANDB_PROJECT:-func_calls_llm}
    export WANDB_ENTITY=\${WANDB_ENTITY:-iamnirmata-microsoft}
    export PYTHONUNBUFFERED=1

    echo \"Node \$(hostname): Starting FSDP No.4 (Rank \$NODE_RANK)...\"
    echo \" torchrun command: torchrun \
      --nproc_per_node=8 \
      --nnodes=\$NNODES \
      --node_rank=\$NODE_RANK \
      --master_addr=\$MASTER_ADDR \
      --master_port=\$MASTER_PORT \
      /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp_no4.py\"

    torchrun \
      --nproc_per_node=8 \
      --nnodes=\$NNODES \
      --node_rank=\$NODE_RANK \
      --master_addr=\$MASTER_ADDR \
      --master_port=\$MASTER_PORT \
      /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp_no4.py
  "








# source /data/Cluster-Validation-Runbook/llm/setup_and_data/1-data.sh
# source /data/Cluster-Validation-Runbook/llm/setup_and_data/2-model.sh
# bash /data/Cluster-Validation-Runbook/llm/setup_and_data/3-copy-to-clients.sh


# export MASTER_ADDR=$(hostname -i)
# export MASTER_PORT=12345

# # Calculate node count (assuming VC_ variables are set on master)
# # Default to 1 if not set to prevent crashes

# echo "Using Hostfile:"
# cat /opt/hostfile
# echo "MASTER_ADDR: $MASTER_ADDR"
# echo "MASTER_PORT: $MASTER_PORT"
# echo "NNODES: $NNODES"
# echo "WORLD_SIZE: $WORLD_SIZE"

# HOSTFILE=/opt/hostfile.mpi
# cat "$HOSTFILE"

# # Number of nodes = number of lines in hostfile
# NP=$(wc -l < "$HOSTFILE")


# mpirun \
#     --allow-run-as-root \
#     --hostfile /opt/hostfile.mpi \
#     -np " '
#     --bind-to none \
#     bash -c '
#     export NODE_RANK=$OMPI_COMM_WORLD_RANK
#     export MASTER_ADDR="'$MASTER_ADDR'"
#     export MASTER_PORT="'$MASTER_PORT'"
#     export NNODES='$NNODES'
#     export WORLD_SIZE='$WORLD_SIZE'
#     export MODEL_PATH="/opt/llm/models/Meta-Llama-3-8B-Instruct"
#     export DATASET_PATH="/opt/llm/datasets/xlam-function-calling-60k"
#     export OUTPUT_DIR="/data/llm/output/llama-3-8b-function-calling-fsdp-no4"
    
#     export WANDB_API_KEY=${WANDB_API_KEY}
#     export WANDB_PROJECT=${WANDB_PROJECT:-"func_calls_llm"}
#     export WANDB_ENTITY="${WANDB_ENTITY:-"iamnirmata-microsoft"}"
#     export PYTHONUNBUFFERED=1

#     echo "Node $(hostname): Starting FSDP No.4 (Rank $NODE_RANK)..."
#     echo " torchrun command: torchrun \
#         --nproc_per_node=8 \
#         --nnodes=$NNODES \
#         --node_rank=$NODE_RANK \
#         --master_addr=$MASTER_ADDR \
#         --master_port=$MASTER_PORT \
#         /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp_no4.py"

#     torchrun \
#         --nproc_per_node=8 \
#         --nnodes=$NNODES \
#         --node_rank=$NODE_RANK \
#         --master_addr= $MASTER_ADDR \
#         --master_port=$MASTER_PORT \
#         /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp_no4.py
#     '