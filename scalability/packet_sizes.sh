#!/bin/bash
set -eo pipefail
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < "$HOSTFILE")
LOG_DIR=${LOG_DIR:-"/data/scalability-logs/$TIMESTAMP"} # Inherit LOG_DIR from environment or default
echo "Using LOG_DIR: $LOG_DIR"

echo "timestamp is $TIMESTAMP"
mkdir -p "$LOG_DIR"
RUN_LOG_FILE="$LOG_DIR/packet_sizes_${TIMESTAMP}.log"
: > "$RUN_LOG_FILE"

SUMMARY_FILE="$LOG_DIR/packet_sizes_${TIMESTAMP}_summary.txt"
echo "Creating packet size summary table at $SUMMARY_FILE..."
printf "| %-10s | %-18s | %-8s | %-15s | %-15s | %-15s |\n" \
  "Nodes" "Packet Size" "Mode" "Avg Latency" "Alg BW" "Bus BW" > "$SUMMARY_FILE"
printf "| %-10s | %-18s | %-8s | %-15s | %-15s | %-15s |\n" \
  "----------" "------------------" "--------" "---------------" "---------------" "---------------" >> "$SUMMARY_FILE"

# --- Node Sweep Config ---
if [ "$NUM_NODES" -lt 2 ]; then
  echo "Need at least 2 hosts in $HOSTFILE; found $NUM_NODES" >&2
  exit 1
fi
declare -a NODE_COUNTS=()
node_count=2
while [ $node_count -lt $NUM_NODES ]; do
  NODE_COUNTS+=("$node_count")
  node_count=$((node_count * 2))
done
NODE_COUNTS+=("$NUM_NODES")
echo "Target node counts: ${NODE_COUNTS[*]}"

TEMP_HOSTFILES=()
cleanup_hosts() {
  for file in "${TEMP_HOSTFILES[@]}"; do
    [ -n "$file" ] && [ -f "$file" ] && rm -f "$file"
  done
}
trap cleanup_hosts EXIT

# --- Packet Size Sweep Config ---
MAX_PACKET_BYTES=$((16 * 1024 * 1024 * 1024))
declare -a PACKET_SIZE_VALUES=()
size_bytes=4
while [ "$size_bytes" -le "$MAX_PACKET_BYTES" ]; do
  PACKET_SIZE_VALUES+=("$size_bytes")
  size_bytes=$((size_bytes * 2))
done

PACKET_SIZES_CSV=""
for size in "${PACKET_SIZE_VALUES[@]}"; do
  if [ -z "$PACKET_SIZES_CSV" ]; then
    PACKET_SIZES_CSV="$size"
  else
    PACKET_SIZES_CSV+=",$size"
  fi
done
export PACKET_SIZES_BYTES="$PACKET_SIZES_CSV"

echo "=========================================================="
echo "STARTING PACKET SIZE SWEEP (4 B -> 16 GB)"
echo "=========================================================="

# --- MPI Base Command ---
MPI_CMD_BASE=(
  mpirun --allow-run-as-root
  -bind-to none -mca pml ob1 -mca btl ^openib
  -x PATH -x LD_LIBRARY_PATH
  -x MASTER_ADDR -x MASTER_PORT
  -x NCCL_DEBUG
  -x PACKET_SIZES_BYTES
)

export NCCL_DEBUG=INFO # Set to WARN to reduce log spam, INFO for details

# --- Helpers ---
format_size() {
  local bytes=$1
  local units=(B KB MB GB)
  local idx=0
  local value=$bytes
  while [ "$value" -ge 1024 ] && [ $idx -lt 3 ]; do
    value=$((value / 1024))
    idx=$((idx + 1))
  done
  echo "$value ${units[$idx]}"
}

configure_mode() {
  local mode=$1
  case $mode in
    tree)
      export NCCL_ALGO=Tree
      export NCCL_SHARP_DISABLE=0
      export NCCL_COLLNET_ENABLE=1
      ;;
    ring)
      export NCCL_ALGO=Ring
      export NCCL_SHARP_DISABLE=0
      export NCCL_COLLNET_ENABLE=0
      ;;
    auto)
      unset NCCL_ALGO
      export NCCL_SHARP_DISABLE=0
      export NCCL_COLLNET_ENABLE=1
      ;;
    *)
      echo "Unknown NCCL mode: $mode" >&2
      exit 1
      ;;
  esac
}

# --- Function to run test and extract latency ---
run_and_parse() {
  local test_name=$1
  local hostfile=$2
  echo "" >&2
  echo "--- RUNNING: $test_name ---" >&2

  local cmd=("${MPI_CMD_BASE[@]}" --hostfile "$hostfile")
  for var in NCCL_SHARP_DISABLE NCCL_COLLNET_ENABLE NCCL_ALGO; do
    if [ -n "${!var+x}" ]; then
      cmd+=(-x "$var")
    fi
  done
  cmd+=("python" "allreduce_packet_sizes.py")

  local tmp_output metrics_file
  tmp_output=$(mktemp)
  metrics_file=$(mktemp)
  "${cmd[@]}" 2>&1 | tee -a "$RUN_LOG_FILE" | tee /dev/stderr | tee "$tmp_output" >/dev/null

  grep '^METRIC|' "$tmp_output" > "$metrics_file" || true
  if [ ! -s "$metrics_file" ]; then
    echo "ERROR: Test '$test_name' failed to produce METRIC lines." >&2
  fi

  cat "$metrics_file"
  rm -f "$tmp_output" "$metrics_file"
}

MODES=(tree ring auto)

for node_count in "${NODE_COUNTS[@]}"; do
  echo ""
  echo "================ Node Count: $node_count ================"
  current_hostfile=$(mktemp)
  TEMP_HOSTFILES+=("$current_hostfile")
  head -n "$node_count" "$HOSTFILE" > "$current_hostfile"

  unset NODE_RESULTS NODE_LABELS
  declare -A NODE_RESULTS
  declare -A NODE_LABELS

  for mode in "${MODES[@]}"; do
    configure_mode "$mode"
    mode_label=${mode^}
    echo ""
    echo ">>> Running packet sweep for mode: $mode_label"
    metrics_output=$(run_and_parse "$mode_label - ${node_count} nodes" "$current_hostfile")

    while IFS= read -r metric_line; do
      [ -z "$metric_line" ] && continue
      IFS='|' read -r tag bytes label latency_val alg_val bus_val <<< "$metric_line"
      [ "$tag" != "METRIC" ] && continue

      NODE_RESULTS["$bytes|$mode"]="$label|$latency_val|$alg_val|$bus_val"
      if [ -z "${NODE_LABELS[$bytes]+x}" ]; then
        NODE_LABELS["$bytes"]="$label"
      fi
    done <<< "$metrics_output"
  done

  mapfile -t NODE_PACKET_ORDER < <(printf "%s\n" "${!NODE_LABELS[@]}" | sort -n)
  if [ ${#NODE_PACKET_ORDER[@]} -eq 0 ]; then
    echo "WARNING: No packet metrics captured for ${node_count} nodes" >&2
    continue
  fi

  echo ""
  echo "--- Summary for $node_count nodes ---"
  printf "| %-10s | %-18s | %-8s | %-15s | %-15s | %-15s |\n" \
    "Nodes" "Packet Size" "Mode" "Avg Latency" "Alg BW" "Bus BW"
  printf "| %-10s | %-18s | %-8s | %-15s | %-15s | %-15s |\n" \
    "----------" "------------------" "--------" "---------------" "---------------" "---------------"

  for packet_bytes in "${NODE_PACKET_ORDER[@]}"; do
    size_label=${NODE_LABELS[$packet_bytes]:-$(format_size "$packet_bytes")}
    for mode in "${MODES[@]}"; do
      mode_label=${mode^}
      metrics="${NODE_RESULTS["$packet_bytes|$mode"]}"
      local_label="$size_label"
      latency="N/A"; alg_bw="N/A"; bus_bw="N/A"
      if [ -n "$metrics" ]; then
        IFS='|' read -r label_text latency_val alg_val bus_val <<< "$metrics"
        local_label="$label_text"
        latency="$latency_val us"
        alg_bw="$alg_val GB/s"
        bus_bw="$bus_val GB/s"
      fi
      printf "| %-10s | %-18s | %-8s | %-15s | %-15s | %-15s |\n" \
        "$node_count" "$local_label" "$mode_label" "$latency" "$alg_bw" "$bus_bw" | tee -a "$SUMMARY_FILE"
    done
  done
done

echo "=========================================================="
echo "PACKET SIZE SWEEP COMPLETE"
echo "=========================================================="

echo ""
echo "--- Packet Size Summary Table (All Nodes) ---"
cat "$SUMMARY_FILE"
echo "---------------------------"