#!/bin/bash
set -eo pipefail

cd /opt/Cluster-Validation-Runbook/scalability
bash ./latency.sh | tee latency.log
bash ./bw.sh | tee bw.log
bash ./scale.sh 10 | tee scale.log


echo "timestamp is $TIMESTAMP"
# Ship logs to shared volume

LOG_DIR=${LOG_DIR:-"/data/scalability-logs/$TIMESTAMP"} # Inherit LOG_DIR from environment or default
mkdir -p $LOG_DIR
cp latency.log bw.log scale.log $LOG_DIR/
echo "Logs copied to $LOG_DIR"
ls -lh $LOG_DIR