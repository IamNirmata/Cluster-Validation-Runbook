#!/bin/bash
set -eo pipefail
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)
LOG_DIR=${testdir:-"./allreduce_logs"} # Inherit LOG_DIR from run.sh or default
TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Use a timestamp for the txt file

echo "=========================================================="
echo "STARTING BANDWIDTH TEST MATRIX (16 GB, $NUM_NODES nodes)"
echo "=========================================================="

# --- MPI Base Command ---
MPI_CMD="mpirun --allow-run-as-root --hostfile $HOSTFILE \
       -bind-to none -mca pml ob1 -mca btl ^openib \
       -x PATH -x LD_LIBRARY_PATH \
       -x MASTER_ADDR -x MASTER_PORT \
       -x NUM_ELEMENTS \
       -x NCCL_SHARP_DISABLE -x NCCL_COLLNET_ENABLE \
       -x NCCL_DEBUG -x NCCL_ALGO \
       python allreduce_benchmark.py"

# Set message size for all bandwidth tests
unset NUM_ELEMENTS # Unset to use the 16GB default in the python script
export NCCL_DEBUG=INFO # Set to WARN to reduce log spam, INFO for details

# --- Function to run test and extract bandwidth ---
run_and_parse() {
  local test_name=$1
  # --- Print all status messages to stderr (>&2) ---
  echo "" >&2
  echo "--- RUNNING: $test_name ---" >&2
  
  # Run command, tee output to stderr.
  # Grep for Bus Bandwidth, awk to get the value (col 3) and unit (col 4)
  local result=$($MPI_CMD 2>&1 | tee /dev/stderr | grep "Bus Bandwidth" | awk '{print $3 " " $4}')
  
  if [ -z "$result" ]; then
    echo "ERROR: Test '$test_name' failed to produce bandwidth output." >&2
    result="Failed"
  fi
  
  echo "Result: $result" >&2
  echo "$result" # This is the *only* line that goes to stdout and is captured
}

# --- TEST 1: SHARP Enabled + Tree Algorithm ---
export NCCL_SHARP_DISABLE=0
export NCCL_COLLNET_ENABLE=1
export NCCL_ALGO=Tree # Force Tree
BW_T1=$(run_and_parse "SHARP Enabled (Tree/CollNet)")

# --- TEST 2: SHARP Disabled + Tree Algorithm ---
export NCCL_SHARP_DISABLE=1
export NCCL_COLLNET_ENABLE=0
export NCCL_ALGO=Tree # Force Tree
BW_T2=$(run_and_parse "SHARP Disabled (Tree)")

# --- TEST 3: SHARP Enabled + Ring Algorithm ---
export NCCL_SHARP_DISABLE=0 # Flag is set, but ALGO=Ring overrides it
export NCCL_COLLNET_ENABLE=1
export NCCL_ALGO=Ring # Force Ring
BW_T3=$(run_and_parse "SHARP Enabled (Ring)")

# --- TEST 4: SHARP Disabled + Ring Algorithm ---
export NCCL_SHARP_DISABLE=1
export NCCL_COLLNET_ENABLE=0
export NCCL_ALGO=Ring # Force Ring
BW_T4=$(run_and_parse "SHARP Disabled (Ring)")


echo "=========================================================="
echo "BANDWIDTH TEST MATRIX COMPLETE"
echo "=========================================================="

# --- Generate Table ---
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/bandwidth_${TIMESTAMP}.txt"
echo ""
echo "Creating bandwidth summary table at $LOG_FILE..."

# Create header
printf "| %-16s | %-15s | %-15s |\n" "SHARP Status" "Ring" "Tree" > $LOG_FILE
# Create separator
printf "| %-16s | %-15s | %-15s |\n" "----------------" "---------------" "---------------" >> $LOG_FILE
# Add data (T3/T4 are Ring, T1/T2 are Tree)
printf "| %-16s | %-15s | %-15s |\n" "SHARP Enabled" "$BW_T3" "$BW_T1" >> $LOG_FILE
printf "| %-16s | %-15s | %-15s |\n" "SHARP Disabled" "$BW_T4" "$BW_T2" >> $LOG_FILE

echo ""
echo "--- Bandwidth Summary Table ---"
cat $LOG_FILE
echo "---------------------------"