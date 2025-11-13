#!/bin/bash
set -eo pipefail
HOSTFILE="/opt/hostfile"
TOTAL_NODES=$(wc -l < $HOSTFILE)
LOG_DIR=${testdir:-"./allreduce_logs"} # Inherit LOG_DIR from run.sh or default
TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Use a timestamp for the txt file

# Read multiplication factor from 1st arg.
# A default (10) is provided by the main run.sh
MUL=$1

echo "=========================================================="
echo "STARTING SCALABILITY BANDWIDTH & LATENCY TEST (SHARP Enabled)"
echo "Running on $MUL, $(($MUL * 2)), ..., $TOTAL_NODES nodes (Step size: $MUL)"
echo "=========================================================="

# --- Set base NCCL Config for all tests ---
export NCCL_SHARP_DISABLE=0  # SHARP Enabled
export NCCL_COLLNET_ENABLE=1 # SHARP Enabled
unset NCCL_ALGO              # Let NCCL auto-select (for SHARP)
export NCCL_DEBUG=WARN       # Be quieter for this test

# Arrays to store results
NODE_COUNTS=()
BANDWIDTHS=()
LATENCIES=() # New array for latency

# --- Function to run test and extract bandwidth ---
# Mode (string, "bandwidth" or "latency")
# N (int, node count)
run_test() {
  local MODE=$1
  local N=$2
  local TEMP_HOSTFILE="/tmp/hostfile.$N"
  
  local test_name=""
  
  if [ "$MODE" == "bandwidth" ]; then
    test_name="Bandwidth Test ($N nodes)"
    unset NUM_ELEMENTS # Use 16GB default
  elif [ "$MODE" == "latency" ]; then
    test_name="Latency Test ($N nodes)"
    export NUM_ELEMENTS=1 # Use 2 Byte
  else
    echo "Unknown test mode: $MODE" >&2
    return 1
  fi

  # --- Print all status messages to stderr (>&2) ---
  echo "" >&2
  echo "--- RUNNING: $test_name ---" >&2
  
  # Create a temporary hostfile for this specific node count
  head -n $N $HOSTFILE > $TEMP_HOSTFILE
  
  # Define the full MPI command
  # Note: NUM_ELEMENTS is passed via -x and was set/unset above
  local MPI_CMD="mpirun --allow-run-as-root --hostfile $TEMP_HOSTFILE \
         -bind-to none -mca pml ob1 -mca btl ^openib \
         -x PATH -x LD_LIBRARY_PATH \
         -x MASTER_ADDR -x MASTER_PORT \
         -x NUM_ELEMENTS \
         -x NCCL_SHARP_DISABLE -x NCCL_COLLNET_ENABLE \
         -x NCCL_DEBUG -x NCCL_ALGO \
         python allreduce_benchmark.py"

  # Run command and tee output to stderr.
  local output=$($MPI_CMD 2>&1 | tee /dev/stderr)
  local result=""

  if [ "$MODE" == "bandwidth" ]; then
    # Grep for Bus Bandwidth, awk to get the value (col 3) and unit (col 4)
    result=$(echo "$output" | grep "Bus Bandwidth" | awk '{print $3 " " $4}')
  elif [ "$MODE" == "latency" ]; then
    # Grep for Avg Latency, awk to get the value (col 3) and unit (col 4)
    result=$(echo "$output" | grep "Avg Latency" | awk '{print $3 " " $4}')
  fi
  
  if [ -z "$result" ]; then
    echo "ERROR: Test '$test_name' failed to produce output." >&2
    result="Failed"
  fi
  
  echo "Result: $result" >&2
  
  # Store results
  if [ "$MODE" == "bandwidth" ]; then
    BANDWIDTHS+=("$result")
  elif [ "$MODE" == "latency" ]; then
    LATENCIES+=("$result")
  fi
}

# --- Main Test Loop ---
LAST_RUN_N=0
for N in $(seq $MUL $MUL $TOTAL_NODES); do
  NODE_COUNTS+=("$N") # Store node count once
  run_test "bandwidth" $N
  run_test "latency" $N
  LAST_RUN_N=$N
done

# Check if the last run was the full node count.
# If not (e.g., TOTAL_NODES=32, last run was 30), run the full count.
if [ "$LAST_RUN_N" -ne "$TOTAL_NODES" ]; then
  echo "Running final test on all $TOTAL_NODES nodes..." >&2
  NODE_COUNTS+=("$TOTAL_NODES")
  run_test "bandwidth" $TOTAL_NODES
  run_test "latency" $TOTAL_NODES
fi

echo "=========================================================="
echo "SCALABILITY TEST COMPLETE"
echo "=========================================================="

# --- Generate Table ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scalability_report_${TIMESTAMP}.txt"
echo ""
echo "Creating scalability summary table at $LOG_FILE..."

# Create header (3 columns)
printf "| %-12s | %-17s | %-15s |\n" "Node Count" "Bus Bandwidth" "Avg Latency" > $LOG_FILE
# Create separator
printf "| %-12s | %-17s | %-15s |\n" "------------" "-----------------" "---------------" >> $LOG_FILE
# Add data
for i in "${!NODE_COUNTS[@]}"; do
  nodes=${NODE_COUNTS[$i]}
  bw=${BANDWIDTHS[$i]}
  lat=${LATENCIES[$i]}
  printf "| %-12s | %-17s | %-15s |\n" "$nodes nodes" "$bw" "$lat" >> $LOG_FILE
done

echo ""
echo "--- Scalability Summary Table ---"
cat $LOG_FILE
echo "---------------------------------"