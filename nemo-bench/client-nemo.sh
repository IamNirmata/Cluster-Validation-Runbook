#!/bin/bash
set -eo pipefail

SIGNAL_DIR="/data/nemo-signals"
MASTER_HOST="$VC_SERVER_HOSTS"

echo ">>> Client started. Master is: $MASTER_HOST"

# 1. Start SSH (Managed by Volcano)
# mkdir -p /run/sshd 
# ssh-keygen -A
# /usr/sbin/sshd -D -e &
# SSHD_PID=$!

# 2. Wait for Signal
echo "Waiting for signal file: ${SIGNAL_DIR}/${MASTER_HOST}.done"
while [ ! -f "${SIGNAL_DIR}/${MASTER_HOST}.done" ]; do
  sleep 10
done

echo ">>> Signal received! Shutting down."
# kill $SSHD_PID || true
exit 0