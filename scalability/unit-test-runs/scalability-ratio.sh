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
echo "STARTING SCALABILITY BANDWIDTH TEST (16 GB, SHARP Enabled)"
echo "Running on $MUL, $(($MUL * 2)), ..., $TOTAL_NODES nodes (Step size: $MUL)"
echo "=========================================================="

# --- Set base NCCL Config for this test ---
unset NUM_ELEMENTS # Use 16GB default
export NCCL_SHARP_DISABLE=0  # SHARP Enabled
export NCCL_COLLNET_ENABLE=1 # SHARP Enabled
unset NCCL_ALGO              # Let NCCL auto-select (for SHARP)
export NCCL_DEBUG=WARN       # Be quieter for this test

# Arrays to store results
NODE_COUNTS=()
BANDWIDTHS=()

# --- Function to run test and extract bandwidth ---
run_and_parse() {
  local N=$1
  local test_name="Scalability Test ($N nodes)"
  # --- Print all status messages to stderr (>&2) ---
  echo "" >&2
  echo "--- RUNNING: $test_name ---" >&2
  
  # Create a temporary hostfile for this specific node count
  local TEMP_HOSTFILE="/tmp/hostfile.$N"
  head -n $N $HOSTFILE > $TEMP_HOSTFILE
  
  # Define the full MPI command
  local MPI_CMD="mpirun --allow-run-as-root --hostfile $TEMP_HOSTFILE \
         -bind-to none -mca pml ob1 -mca btl ^openib \
         -x PATH -x LD_LIBRARY_PATH \
         -x MASTER_ADDR -x MASTER_PORT \
         -x NUM_ELEMENTS \
         -x NCCL_SHARP_DISABLE -x NCCL_COLLNET_ENABLE \
         -x NCCL_DEBUG -x NCCL_ALGO \
         python allreduce_benchmark.py"

  # Run command, tee output to stderr.
  # Grep for Bus Bandwidth, awk to get the value (col 3) and unit (col 4)
  local result=$($MPI_CMD 2>&1 | tee /dev/stderr | grep "Bus Bandwidth" | awk '{print $3 " " $4}')
  
  if [ -z "$result" ]; then
    echo "ERROR: Test '$test_name' failed to produce bandwidth output." >&2
    result="Failed"
  fi
  
  echo "Result: $result" >&2
  
  # Store results
  NODE_COUNTS+=("$N")
  BANDWIDTHS+=("$result")
}

# --- Main Test Loop ---
LAST_RUN_N=0
for N in $(seq $MUL $MUL $TOTAL_NODES); do
  run_and_parse $N
  LAST_RUN_N=$N
done

# Check if the last run was the full node count.
# If not (e.g., TOTAL_NODES=32, last run was 30), run the full count.
if [ "$LAST_RUN_N" -ne "$TOTAL_NODES" ]; then
  echo "Running final test on all $TOTAL_NODES nodes..." >&2
  run_and_parse $TOTAL_NODES
fi

echo "=========================================================="
echo "SCALABILITY TEST COMPLETE"
echo "=========================================================="

# --- Generate Table ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scalability_report_${TIMESTAMP}.txt"
echo ""
echo "Creating scalability summary table at $LOG_FILE..."

# Create header
printf "| %-15s | %-17s |\n" "Node Count" "Bus Bandwidth" > $LOG_FILE
# Create separator
printf "| %-15s | %-17s |\n" "---------------" "-----------------" >> $LOG_FILE
# Add data
for i in "${!NODE_COUNTS[@]}"; do
  nodes=${NODE_COUNTS[$i]}
  bw=${BANDWIDTHS[$i]}
  printf "| %-15s | %-17s |\n" "$nodes nodes" "$bw" >> $LOG_FILE
done

echo ""
echo "--- Scalability Summary Table ---"
cat $LOG_FILE
echo "---------------------------------"