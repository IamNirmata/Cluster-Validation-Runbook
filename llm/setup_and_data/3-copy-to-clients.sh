#!/bin/bash

cd /workspace/distrbuted_training_tools/llm_finetune/setup_and_data
echo "Starting pre-launch setup and data scripts..."
echo "make sure the secrets are set by running: source ../../../secrets.sh"

cat /opt/hostfile.mpi

# Run this to copy data from NFS (/data) to Local SSD (/opt) on all nodes
mpirun \
    --allow-run-as-root \
    --hostfile /opt/hostfile.mpi \
    --bind-to none \
    bash -c "mkdir -p /opt/llm/datasets && \
             echo 'Copying data on \$(hostname)...' && \
             cp -r /data/llm/datasets/xlam-function-calling-60k /opt/llm/datasets/"


mpirun \
    --allow-run-as-root \
    --hostfile /opt/hostfile.mpi \
    --bind-to none \
    bash -c "mkdir -p /opt/llm/models && \
             echo 'Copying model on \$(hostname)...' && \
             cp -r /data/llm/models/Meta-Llama-3-8B-Instruct /opt/llm/models/"