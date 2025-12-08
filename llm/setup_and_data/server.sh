#!/usr/bin/env bash
set -euo pipefail

source /data/Cluster-Validation-Runbook/llm/setup_and_data/2-data.sh
source /data/Cluster-Validation-Runbook/llm/setup_and_data/3-model.sh

echo "Waiting for all workers to be ready..."
HOSTFILE=/opt/hostfile.mpi
# Wait for hostfile to be populated (it should be by volcano/mpi plugin, but just in case)
while [ ! -f "$HOSTFILE" ]; do
  echo "Waiting for $HOSTFILE..."
  sleep 5
done

# Wait for all hosts to be resolvable
while read -r host slots; do
  # Skip empty lines
  [ -z "$host" ] && continue
  echo "Checking $host..."
  while ! getent hosts "$host" >/dev/null; do
    echo "Waiting for $host to resolve..."
    sleep 5
  done
  echo "$host resolved."
done < "$HOSTFILE"
echo "All workers ready."

bash   /data/Cluster-Validation-Runbook/llm/setup_and_data/4-copy-to-clients.sh

export MASTER_ADDR="$(hostname -i)"
export MASTER_PORT=12345

echo "Using Hostfile:####################################"
cat /opt/hostfile

HOSTFILE=/opt/hostfile.mpi
echo "Using Hostfile for mpirun:#########################"
cat "$HOSTFILE"

NP=$(wc -l < "$HOSTFILE")
export NNODES="$NP"
export WORLD_SIZE=$(( NNODES * 8 ))

echo "MASTER_ADDR: $MASTER_ADDR"
echo "MASTER_PORT: $MASTER_PORT"
echo "NNODES: $NNODES"
echo "WORLD_SIZE: $WORLD_SIZE"

mpirun \
  --allow-run-as-root \
  --hostfile "$HOSTFILE" \
  -np "$NP" \
  --bind-to none \
  -x NNODES \
  -x MASTER_ADDR \
  -x MASTER_PORT \
  -x WANDB_API_KEY \
  -x WANDB_PROJECT \
  -x WANDB_ENTITY \
  bash -lc '
    export NODE_RANK=$OMPI_COMM_WORLD_RANK

    export MODEL_PATH=/opt/llm/models/Llama-3.3-70B-Instruct
    export DATASET_PATH=/opt/llm/datasets/xlam-function-calling-60k
    export OUTPUT_DIR=/data/llm/output/llama-3-70b-function-calling-fsdp-no4

    export WANDB_API_KEY=${WANDB_API_KEY:-}
    export WANDB_PROJECT=${WANDB_PROJECT:-func_calls_llm}
    export WANDB_ENTITY=${WANDB_ENTITY:-iamnirmata-microsoft}
    export WANDB_MODE=disabled
    export PYTHONUNBUFFERED=1

    echo "Node $(hostname): Starting FSDP No.4 (Rank $NODE_RANK)..."
    echo " torchrun command: torchrun \
      --nproc_per_node=8 \
      --nnodes=$NNODES \
      --node_rank=$NODE_RANK \
      --master_addr=$MASTER_ADDR \
      --master_port=$MASTER_PORT \
      /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp_no4.py"

    torchrun \
      --nproc_per_node=8 \
      --nnodes=$NNODES \
      --node_rank=$NODE_RANK \
      --master_addr=$MASTER_ADDR \
      --master_port=$MASTER_PORT \
      /data/Cluster-Validation-Runbook/llm/setup_and_data/fsdp7
  '








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