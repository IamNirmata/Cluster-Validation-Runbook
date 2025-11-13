#!/bin/bash
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)
echo "Running LATENCY test (2 Bytes) with SHARP ENABLED on $NUM_NODES nodes..."

# --- Config ---
export NUM_ELEMENTS=1
export NCCL_SHARP_DISABLE=0
export NCCL_COLLNET_ENABLE=1
export NCCL_DEBUG=INFO
# NCCL_ALGO is NOT set, to allow NCCL to pick CollNet/Tree

# --- MPI Command ---
mpirun --allow-run-as-root --hostfile $HOSTFILE \
       -bind-to none -mca pml ob1 -mca btl ^openib \
       -x PATH -x LD_LIBRARY_PATH \
       -x MASTER_ADDR -x MASTER_PORT \
       -x NUM_ELEMENTS \
       -x NCCL_SHARP_DISABLE -x NCCL_COLLNET_ENABLE \
       -x NCCL_DEBUG \
       python allreduce_benchmark.py