#!/bin/bash
set -eo pipefail

SIGNAL_DIR="/data/nemo-signals"
MASTER_HOST="$VC_SERVER_HOSTS"

echo ">>> Client started. Master is: $MASTER_HOST"

# 1. Start SSH (Required for MPI)
echo "Starting SSH daemon..."
mkdir -p /run/sshd 
ssh-keygen -A
/usr/sbin/sshd -D -e &
SSHD_PID=$!

# 2. Wait for the Master to finish
echo "Waiting for signal file: ${SIGNAL_DIR}/${MASTER_HOST}.done"

# Loop forever until the file exists
while [ ! -f "${SIGNAL_DIR}/${MASTER_HOST}.done" ]; do
  # Sleep 10 seconds between checks to save CPU
  sleep 10
done

echo ">>> Signal received! Master has finished. Shutting down."

# 3. Kill SSH and Exit
kill $SSHD_PID || true
exit 0