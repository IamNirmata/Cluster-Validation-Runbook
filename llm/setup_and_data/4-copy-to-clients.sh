#!/bin/bash
# set -euo pipefail

echo "Copying data and model to client nodes..."
cd ${codedir}/setup_and_data


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
      cp -r /data/llm/models/Meta-Llama-3-8B-Instruct /opt/llm/models/
      echo "[MODEL] Finished copying on $(hostname)"
    else
      echo "[MODEL] Model already exists on $(hostname), skipping."
    fi
  '
