#!/bin/bash

# --- Config ---
# Use the specific hostfile path
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)

echo "Running LATENCY test (2 Bytes) with SHARP DISABLED on $NUM_NODES nodes..."

# --- Environment Variables ---
export NUM_ELEMENTS=1       # 1 element * 2 bytes/element (bfloat16) = 2 bytes
export NCCL_SHARP_DISABLE=1 # Explicitly disable SHARP
export NCCL_COLLNET_ENABLE=0  # Disable Mellanox collnet

export NCCL_DEBUG=INFO      # Set to WARN to reduce log spam
export NCCL_ALGO=Ring       # Ring is often best for small messages

# --- MPI Command ---
# Removed -np and --map-by flags. 
# mpirun will automatically launch processes based on the 'slots=8' in your hostfile.
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