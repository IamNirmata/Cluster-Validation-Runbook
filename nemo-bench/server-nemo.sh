#!/bin/bash
set -xeo pipefail
export DEBIAN_FRONTEND=noninteractive

# --- CONFIGURATION ---
export TIMESTAMP=$(TZ='America/Los_Angeles' date '+%Y-%m-%d_%H-%M-%S')
export LOG_DIR="/data/nemo/$TIMESTAMP"
export SIGNAL_DIR="/data/nemo-signals"

mkdir -p $LOG_DIR
mkdir -p $SIGNAL_DIR
echo "LOG_DIR set to $LOG_DIR"

# --- SIGNAL HANDLING ---
# This function runs when the script exits (success or failure)
function cleanup_and_signal {
  echo ">>> Job finished (or failed). Signaling clients to terminate..."
  # Create a file named after this host (the master)
  touch "${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"
  echo "Signal written to: ${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"
}

# Register the trap to run on EXIT (covers exit 0, error 1, or signals)
trap cleanup_and_signal EXIT

# Remove any old signal file from a previous run (just in case of hostname reuse)
rm -f "${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"

echo "Server setup complete."