#!/bin/bash

# --- Config ---
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)

echo "Running BANDWIDTH test (16 GB) with SHARP DISABLED on $NUM_NODES nodes..."

# --- Environment Variables ---
# NUM_ELEMENTS is unset, so script defaults to 16GB
export NCCL_SHARP_DISABLE=1
export NCCL_COLLNET_ENABLE=0

export NCCL_DEBUG=INFO
export NCCL_ALGO=Ring # Or 'Tree'

# --- MPI Command ---
mpirun --hostfile $HOSTFILE \
       -bind-to none \
       -mca pml ob1 -mca btl ^openib \
       -x PATH \
       -x NCCL_SHARP_DISABLE \
       -x NCCL_COLLNET_ENABLE \
       -x NCCL_DEBUG \
       -x NCCL_ALGO \
       python allreduce_benchmark.py