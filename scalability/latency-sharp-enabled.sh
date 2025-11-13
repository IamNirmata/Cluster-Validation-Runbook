#!/bin/bash

# --- Config ---
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)

echo "Running LATENCY test (2 Bytes) with SHARP ENABLED on $NUM_NODES nodes..."

# --- Environment Variables ---
export NUM_ELEMENTS=1
export NCCL_SHARP_DISABLE=0 # Enable SHARP
export NCCL_COLLNET_ENABLE=1  # Enable Mellanox collnet

export NCCL_DEBUG=INFO
export NCCL_ALGO=Ring

# --- MPI Command ---
mpirun --hostfile $HOSTFILE \
       -bind-to none \
       -mca pml ob1 -mca btl ^openib \
       -x PATH \
       -x NUM_ELEMENTS \
       -x NCCL_SHARP_DISABLE \
       -x NCCL_COLLNET_ENABLE \
       -x NCCL_DEBUG \
       -x NCCL_ALGO \
       python allreduce_benchmark.py