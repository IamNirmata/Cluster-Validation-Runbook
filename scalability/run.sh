#!/bin/bash

# --- Configuration ---
# 1. Set log directory.
#    Uses the $testdir environment variable if it's set.
#    Otherwise, it defaults to "./allreduce_logs".
LOG_DIR=${testdir:-"./allreduce_logs"}

# 2. Create a unique timestamp for this test run
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 3. Create the log directory if it doesn't exist
mkdir -p "$LOG_DIR"

echo "--- Starting AllReduce Test Suite ---"
echo "Saving all logs to: $LOG_DIR"
echo "Timestamp for this run: $TIMESTAMP"
echo ""


# Usage: run_test <script_name.sh> <log_file_name>
run_test() {
    local script_name=$1
    local log_file_base=$2
    # Define the full path for the log file
    local log_file_path="$LOG_DIR/${log_file_base}_${TIMESTAMP}.log"
    
    echo "Running $script_name..."
    echo "  > Log file: $log_file_path"
    
    # Execute the script.
    # >  redirects STDOUT to the log file
    # 2>&1 redirects STDERR (2) to the same place as STDOUT (1)
    ./"$script_name" > "$log_file_path" 2>&1
    
    echo "  > Finished $script_name."
    echo ""
}

# --- Execute All Tests ---

run_test "latency-sharp-disabled.sh"   "latency_sharp_disabled"
run_test "latency-sharp-enabled.sh"    "latency_sharp_enabled"
run_test "bandwidth-sharp-disabled.sh" "bandwidth_sharp_disabled"
run_test "bandwidth-sharp-enabled.sh"  "bandwidth_sharp_enabled"

echo "--- All tests complete. ---"