#!/bin/bash
set -eo pipefail
HOSTFILE="/opt/hostfile"
NUM_NODES=$(wc -l < $HOSTFILE)
testdir=/opt/Cluster-Validation-Runbook/scalability
# Create testdir if it doesn't exist
if [ ! -d "$testdir" ]; then
    echo "Creating directory: $testdir"
    mkdir -p "$testdir"
fi

LOG_DIR=${testdir:-"./allreduce_logs"} # Inherit LOG_DIR from run.sh or default
TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Use a timestamp for the txt file

echo "=========================================================="
echo "STARTING LATENCY TEST MATRIX (2 Bytes, $NUM_NODES nodes)"
echo "=========================================================="

# --- MPI Base Command ---
# We export variables from this script, so mpirun -x just needs to list them
MPI_CMD="mpirun --allow-run-as-root --hostfile $HOSTFILE \
       -bind-to none -mca pml ob1 -mca btl ^openib \
       -x PATH -x LD_LIBRARY_PATH \
       -x MASTER_ADDR -x MASTER_PORT \
       -x NUM_ELEMENTS \
       -x NCCL_SHARP_DISABLE -x NCCL_COLLNET_ENABLE \
       -x NCCL_DEBUG -x NCCL_ALGO \
       python allreduce_benchmark.py"

# Set message size for all latency tests
export NUM_ELEMENTS=1
export NCCL_DEBUG=INFO # Set to WARN to reduce log spam, INFO for details

# --- Function to run test and extract latency ---
run_and_parse() {
  local test_name=$1
  echo ""
  echo "--- RUNNING: $test_name ---"
  
  # Run command, tee output to stdout and a temp file
  # Grep for Avg Latency, awk to get the value (col 3) and unit (col 4)
  local result=$($MPI_CMD 2>&1 | tee /dev/stderr | grep "Avg Latency" | awk '{print $3 " " $4}')
  
  if [ -z "$result" ]; then
    echo "ERROR: Test '$test_name' failed to produce latency output."
    result="Failed"
  fi
  
  echo "Result: $result"
  echo "$result" # Return the result
}

# --- TEST 1: SHARP Enabled + Tree Algorithm ---
export NCCL_SHARP_DISABLE=0
export NCCL_COLLNET_ENABLE=1
export NCCL_ALGO=Tree # Force Tree
LATENCY_T1=$(run_and_parse "SHARP Enabled (Tree/CollNet)")

# --- TEST 2: SHARP Disabled + Tree Algorithm ---
export NCCL_SHARP_DISABLE=1
export NCCL_COLLNET_ENABLE=0
export NCCL_ALGO=Tree # Force Tree
LATENCY_T2=$(run_and_parse "SHARP Disabled (Tree)")

# --- TEST 3: SHARP Enabled + Ring Algorithm ---
export NCCL_SHARP_DISABLE=0 # Flag is set, but ALGO=Ring overrides it
export NCCL_COLLNET_ENABLE=1
export NCCL_ALGO=Ring # Force Ring
LATENCY_T3=$(run_and_parse "SHARP Enabled (Ring)")

# --- TEST 4: SHARP Disabled + Ring Algorithm ---
export NCCL_SHARP_DISABLE=1
export NCCL_COLLNET_ENABLE=0
export NCCL_ALGO=Ring # Force Ring
LATENCY_T4=$(run_and_parse "SHARP Disabled (Ring)")


echo "=========================================================="
echo "LATENCY TEST MATRIX COMPLETE"
echo "=========================================================="

# --- Generate Table ---
LOG_FILE="$LOG_DIR/latency_${TIMESTAMP}.txt"
# Create the log file
touch "$LOG_FILE"
echo ""
echo "Creating latency summary table at $LOG_FILE..."

# Create header
printf "| %-30s | %-15s |\n" "Test Configuration" "Avg Latency" > $LOG_FILE
# Create separator
printf "| %-30s | %-15s |\n" "------------------------------" "---------------" >> $LOG_FILE
# Add data
printf "| %-30s | %-15s |\n" "SHARP Enabled (Tree)" "$LATENCY_T1" >> $LOG_FILE
printf "| %-30s | %-15s |\n" "SHARP Disabled (Tree)" "$LATENCY_T2" >> $LOG_FILE
printf "| %-30s | %-15s |\n" "SHARP Enabled (Ring)" "$LATENCY_T3" >> $LOG_FILE
printf "| %-30s | %-15s |\n" "SHARP Disabled (Ring)" "$LATENCY_T4" >> $LOG_FILE

echo ""
echo "--- Latency Summary Table ---"
cat $LOG_FILE
echo "---------------------------"