import os
import time
from typing import List

import torch
import torch.distributed as dist

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
g = 1024 * 1024 * 1024
DTYPE = torch.bfloat16
ELEMENT_SIZE_BYTES = 2

# Default to 8 Giga-elements (16 GB)
DEFAULT_ELEMENTS = 8 * g
MAX_ELEMENTS_ENV = int(os.environ.get("MAX_ELEMENTS", os.environ.get("NUM_ELEMENTS", DEFAULT_ELEMENTS)))


def parse_packet_sizes() -> List[int]:
    """Return a sorted list of packet sizes (in bytes) to benchmark."""
    env_list = os.environ.get("PACKET_SIZES_BYTES")
    if env_list:
        sizes = []
        for chunk in env_list.split(","):
            chunk = chunk.strip()
            if chunk:
                value = int(chunk)
                if value <= 0:
                    raise ValueError("Packet sizes must be positive")
                sizes.append(value)
        if not sizes:
            raise ValueError("PACKET_SIZES_BYTES env var did not contain valid values")
        return sorted(set(sizes))

    min_bytes = int(os.environ.get("MIN_PACKET_BYTES", 4))
    max_bytes = int(os.environ.get("MAX_PACKET_BYTES", 16 * g))
    if min_bytes <= 0 or max_bytes <= 0 or min_bytes > max_bytes:
        raise ValueError("Invalid MIN_PACKET_BYTES / MAX_PACKET_BYTES configuration")

    sizes = []
    size = min_bytes
    while size <= max_bytes:
        sizes.append(size)
        size *= 2

    return sizes


def format_bytes(num_bytes: int) -> str:
    units = ["B", "KB", "MB", "GB"]
    value = float(num_bytes)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.2f} {unit}"
        value /= 1024
    return f"{num_bytes} B"


packet_sizes_bytes = parse_packet_sizes()
required_elements = max((size + ELEMENT_SIZE_BYTES - 1) // ELEMENT_SIZE_BYTES for size in packet_sizes_bytes)
MAX_ELEMENTS = max(MAX_ELEMENTS_ENV, required_elements)


# --- NCCL Initialization ---
dist.init_process_group("nccl", init_method="env://", rank=world_rank, world_size=world_size)

# Set device
torch.cuda.set_device(local_rank)

# [CHANGE 2] Explicitly specify device during creation to prevent CPU->GPU copy lag
data_tensor = torch.zeros(MAX_ELEMENTS, dtype=DTYPE, device=f"cuda:{local_rank}")


def benchmark_tensor(tensor: torch.Tensor):
    for _ in range(WARMUP):
        dist.all_reduce(tensor)
    torch.cuda.synchronize()

    dist.barrier()

    pre = time.perf_counter()
    for _ in range(ITERATIONS):
        dist.all_reduce(tensor)
    torch.cuda.synchronize()
    total_duration = time.perf_counter() - pre

    avg_duration = total_duration / ITERATIONS
    total_size_bytes = tensor.numel() * ELEMENT_SIZE_BYTES
    total_size_gb = total_size_bytes / g
    alg_bw_gbs = total_size_gb / avg_duration if avg_duration > 0 else 0.0
    busbw_gbs = alg_bw_gbs * (2 * (world_size - 1) / world_size)

    return avg_duration, alg_bw_gbs, busbw_gbs, total_size_bytes


results = []
for packet_bytes in packet_sizes_bytes:
    num_elements = max(1, (packet_bytes + ELEMENT_SIZE_BYTES - 1) // ELEMENT_SIZE_BYTES)
    if num_elements > MAX_ELEMENTS:
        raise ValueError(
            f"Packet size {packet_bytes} bytes exceeds allocated capacity ({MAX_ELEMENTS * ELEMENT_SIZE_BYTES} bytes)"
        )

    working_tensor = data_tensor[:num_elements]
    avg_duration, alg_bw_gbs, busbw_gbs, actual_size_bytes = benchmark_tensor(working_tensor)

    if world_rank == 0:
        results.append(
            {
                "requested_bytes": packet_bytes,
                "actual_bytes": actual_size_bytes,
                "elements": num_elements,
                "latency_us": avg_duration * 1_000_000,
                "alg_bw": alg_bw_gbs,
                "bus_bw": busbw_gbs,
            }
        )

dist.destroy_process_group()

if world_rank == 0:
    print("--- AllReduce Packet Size Sweep ---")
    print(f"World Size:       {world_size} ranks")
    print(f"Iterations:       {ITERATIONS}")
    print("---")

    header = (
        "| Packet Size | Elements | Avg Latency (us) | Alg BW (GB/s) | Bus BW (GB/s) |"
    )
    separator = (
        "|-------------|----------|------------------|---------------|---------------|"
    )
    print(header)
    print(separator)

    for row in results:
        readable_size = format_bytes(row["actual_bytes"])
        print(
            f"| {readable_size:>11} | {row['elements']:>8} | {row['latency_us']:>16.2f} | "
            f"{row['alg_bw']:>13.2f} | {row['bus_bw']:>13.2f} |"
        )

        # Preserve legacy log format for downstream parsers
        print(f"Packet Size:      {readable_size} ({row['actual_bytes']} bytes)")
        print(f"Avg Latency:      {row['latency_us']:.2f} us")
        print(f"Alg Bandwidth:    {row['alg_bw']:.2f} GB/s")
        print(f"Bus Bandwidth:    {row['bus_bw']:.2f} GB/s")
        print("---------------------------")

        print(
            f"METRIC|{row['actual_bytes']}|{readable_size}|{row['latency_us']:.2f}|{row['alg_bw']:.2f}|{row['bus_bw']:.2f}"
        )