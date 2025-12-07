import torch.distributed as dist
import os
import time
import torch

# --- Distributed Config ---
local_world_size = int(os.environ.get("LOCAL_WORLD", 1))
local_rank = int(os.environ.get("OMPI_COMM_WORLD_LOCAL_RANK", 0))
world_size = int(os.environ.get("OMPI_COMM_WORLD_SIZE", 1))
world_rank = int(os.environ.get("OMPI_COMM_WORLD_RANK", 0))
node_rank = world_rank // local_world_size
node_world_size = world_size // local_world_size

# [CHANGE 1] Increased iterations for stability
WARMUP = 10
ITERATIONS = 50 

# --- Data Size Config ---
g = 1024*1024*1024
DTYPE = torch.bfloat16
ELEMENT_SIZE_BYTES = 2 

# Default to 8 Giga-elements (16 GB)
DEFAULT_ELEMENTS = 8 * g
NUM_ELEMENTS = int(os.environ.get("NUM_ELEMENTS", DEFAULT_ELEMENTS))

total_size_bytes = NUM_ELEMENTS * ELEMENT_SIZE_BYTES
total_size_gb = total_size_bytes / g

# --- NCCL Initialization ---
dist.init_process_group("nccl", init_method="env://", rank=world_rank, world_size=world_size)

# Set device
torch.cuda.set_device(local_rank)

# [CHANGE 2] Explicitly specify device during creation to prevent CPU->GPU copy lag
data_tensor = torch.zeros(NUM_ELEMENTS, dtype=DTYPE, device=f"cuda:{local_rank}")

# --- Benchmark ---

# 1. Warm-up (Heat up GPU clocks and initialize NCCL buffers)
for _ in range(WARMUP):
    dist.all_reduce(data_tensor)
torch.cuda.synchronize()

# 2. Synchronization (CRITICAL FIX)
# This ensures all Ranks are ready to run at the exact same millisecond.
# Without this, Rank 0 might start timing while Rank 1 is still waking up.
dist.barrier() 

# 3. Timed benchmark run
pre = time.perf_counter()
for _ in range(ITERATIONS):
    dist.all_reduce(data_tensor)
torch.cuda.synchronize()
total_duration = time.perf_counter() - pre

# --- Results ---
avg_duration = total_duration / ITERATIONS

busbw_gbs = (total_size_gb / avg_duration) * (2 * (world_size - 1) / world_size)
alg_bw_gbs = total_size_gb / avg_duration

if world_rank == 0:
    print("--- AllReduce Benchmark (Optimized) ---")
    print(f"World Size:       {world_size} ranks")
    print(f"Data Size:        {total_size_gb:.2f} GB")
    print(f"Iterations:       {ITERATIONS}")
    print("---")
    print(f"Avg Latency:      {avg_duration * 1_000_000:.2f} us")
    print(f"Alg Bandwidth:    {alg_bw_gbs:.2f} GB/s")
    print(f"Bus Bandwidth:    {busbw_gbs:.2f} GB/s")
    print("---------------------------")

dist.destroy_process_group()