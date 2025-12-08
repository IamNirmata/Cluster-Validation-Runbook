#!/bin/bash
# set -euo pipefail

cd /data/Cluster-Validation-Runbook/llm/setup_and_data


# # Run this to copy data from NFS (/data) to Local SSD (/opt) on all nodes
# mpirun \
#     --allow-run-as-root \
#     --hostfile /opt/hostfile.mpi \
#     --bind-to none \
#     bash -c "mkdir -p /opt/llm/datasets && \
#              echo 'Copying data on \$(hostname)...' && \
#              cp -r /data/llm/datasets/xlam-function-calling-60k /opt/llm/datasets/"


# mpirun \
#     --allow-run-as-root \
#     --hostfile /opt/hostfile.mpi \
#     --bind-to none \
#     bash -c "mkdir -p /opt/llm/models && \
#              echo 'Copying model on \$(hostname)...' && \
#              cp -r /data/llm/models/Meta-Llama-3-8B-Instruct /opt/llm/models/

HOSTFILE=/opt/hostfile.mpi
cat "$HOSTFILE"

# Number of nodes = number of lines in hostfile
NP=$(wc -l < "$HOSTFILE")

#########################
# Copy dataset
#########################
mpirun \
  --allow-run-as-root \
  --hostfile "$HOSTFILE" \
  -np "$NP" \
  --map-by ppr:1:node \
  --bind-to none \
  bash -c '
    set -euo pipefail
    echo "[DATA] Copying data on $(hostname)..."
    mkdir -p /opt/llm/datasets
    if [ ! -d /opt/llm/datasets/xlam-function-calling-60k ]; then
      # -a to preserve permissions/metadata; adjust if you want
      cp -r /data/llm/datasets/xlam-function-calling-60k /opt/llm/datasets/
      echo "[DATA] Finished copying on $(hostname)"
    else
      echo "[DATA] Dataset already exists on $(hostname), skipping."
    fi
  '

#########################
# Copy model
#########################
mpirun \
  --allow-run-as-root \
  --hostfile "$HOSTFILE" \
  -np "$NP" \
  --map-by ppr:1:node \
  --bind-to none \
  bash -c '
    set -euo pipefail
    echo "[MODEL] Copying model on $(hostname)..."
    mkdir -p /opt/llm/models
    if [ ! -d /opt/llm/models/Meta-Llama-3-8B-Instruct ]; then
      cp -a /data/llm/models/Meta-Llama-3-8B-Instruct /opt/llm/models/
      
      echo "[MODEL] Finished copying on $(hostname)"
    else
      echo "[MODEL] Model already exists on $(hostname), skipping."
    fi
  '
