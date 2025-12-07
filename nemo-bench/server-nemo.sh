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
function cleanup_and_signal {
  echo ">>> Job finished (or failed). Signaling clients to terminate..."
  touch "${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"
  echo "Signal written to: ${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"
}

trap cleanup_and_signal EXIT
rm -f "${SIGNAL_DIR}/${VC_SERVER_HOSTS}.done"
echo "Server setup complete."