#!/bin/bash
set -xeo pipefail
export DEBIAN_FRONTEND=noninteractive

export TIMESTAMP=$(TZ='America/Los_Angeles' date '+%Y-%m-%d_%H-%M-%S')
# User requested specific path:
export LOG_DIR="/data/nemo/$TIMESTAMP"
mkdir -p $LOG_DIR
echo "LOG_DIR set to $LOG_DIR as per scalability runbook"