import torch.distributed as dist
import os
import time
import torch

# --- Distributed Config ---
# Retrieve environment variables for distributed training configuration
# These are set by mpirun
local_world_size = int(os.environ.get("LOCAL_WORLD", 1))
local_rank = int(os.environ.get("OMPI_COMM_WORLD_LOCAL_RANK", 0))
world_size = int(os.environ.get("OMPI_COMM_WORLD_SIZE", 1))
world_rank = int(os.environ.get("OMPI_COMM_WORLD_RANK", 0))
node_rank = world_rank // local_world_size
node_world_size = world_size // local_world_size
ITERATIONS = 7 # Number of timed iterations

# --- Data Size Config ---
g = 1024*1024*1024  # Define 1 Giga
DTYPE = torch.bfloat16
ELEMENT_SIZE_BYTES = 2 # bfloat16 is 2 bytes

# Get number of elements from environment variable
# Default to 8 Giga-elements (8 * 1024^3) if not set, which is 16 GB
DEFAULT_ELEMENTS = 8 * g
NUM_ELEMENTS = int(os.environ.get("NUM_ELEMENTS", DEFAULT_ELEMENTS))

# Total size in bytes for calculation
total_size_bytes = NUM_ELEMENTS * ELEMENT_SIZE_BYTES
total_size_gb = total_size_bytes / g

# --- NCCL Initialization ---
# Initialize the process group for distributed training
dist.init_process_group("nccl", init_method="env://", rank=world_rank, world_size=world_size)
world_group = dist.group.WORLD

# Set the current CUDA device to the local rank
torch.cuda.set_device(local_rank)

# Allocate memory for the data to be reduced
data_tensor = torch.zeros(NUM_ELEMENTS, dtype=DTYPE).to('cuda')

# --- Benchmark ---
# Warm-up iteration
dist.all_reduce(data_tensor)
torch.cuda.synchronize()

# Timed benchmark run
pre = time.perf_counter()
for _ in range(ITERATIONS):
    dist.all_reduce(data_tensor)
torch.cuda.synchronize()

# --- MODIFIED SECTION ---
total_duration = time.perf_counter() - pre
avg_duration = total_duration / ITERATIONS # This is the average latency

# --- Results ---
# Your original Bus Bandwidth calculation
# (size/g) / avg_duration * (2 * (N-1) / N)
busbw_gbs = (total_size_gb / avg_duration) * (2 * (world_size - 1) / world_size)

# Simple Algorithm Bandwidth (GB/s)
alg_bw_gbs = total_size_gb / avg_duration

if world_rank == 0:
    print("--- AllReduce Benchmark ---")
    print(f"World Size:       {world_size} ranks ({node_world_size} nodes)")
    print(f"Data Size:        {total_size_bytes} bytes ({total_size_gb:.2f} GB)")
    print(f"Iterations:       {ITERATIONS}")
    print("---")
    print(f"Total Time:       {total_duration:.4f} s")
    print(f"Avg Latency:      {avg_duration * 1_000_000:.2f} us")
    print(f"Alg Bandwidth:    {alg_bw_gbs:.2f} GB/s")
    print(f"Bus Bandwidth:    {busbw_gbs:.2f} GB/s")
    print("---------------------------")
# --- END MODIFIED SECTION ---

dist.destroy_process_group()