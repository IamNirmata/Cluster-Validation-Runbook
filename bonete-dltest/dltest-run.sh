#!/usr/bin/env bash

set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# paths and configuration

# Create dltest log directory for $gcrnode
export LATEST_LOG_DIR=$(find /data/dltest-logs -maxdepth 1 -type d -name "20*" | sort -r | head -n 1)
echo "LATEST_LOG_DIR set to $LATEST_LOG_DIR"
mkdir -p "$LATEST_LOG_DIR/$gcrnode"
export DLTEST_LOG_DIR="$LATEST_LOG_DIR/$gcrnode"
echo "DLTEST_LOG_DIR set to $DLTEST_LOG_DIR"

#script directory
SCRIPT_DIR=/opt/dl_unittest_bonete

#start dltest server script
nvidia-smi # Display GPU status
echo "################-------Starting DL UNIT TEST in $gcrnode ------------------###################"


#move the script to /opt for persistence
# Copy dltest logs directory to /opt for persistence
if [[ -d "/data/dltest-logs/dl_unittest_bonete" ]]; then
  cp -r /data/dltest-logs/dl_unittest_bonete $SCRIPT_DIR
  echo "Copied /data/dltest-logs/dl_unittest_bonete to $SCRIPT_DIR"
  ls -la $SCRIPT_DIR
else
  echo "Warning: /data/dltest-logs/dl_unittest_bonete does not exist, skipping copy"
fi

cd $SCRIPT_DIR || { echo "Failed to change directory to $SCRIPT_DIR"; exit 1; }
echo "Changed directory to $SCRIPT_DIR"
MASTER_ADDR=localhost MASTER_PORT=9500 PYTHONPATH=src torchrun --nproc_per_node=8 -m dl_unittest --test_plan 80gb-placeholder --iterations 30 2>&1 | tee $gcrnode.txt

#copy $gcrnode.txt to DLTEST_LOG_DIR
cp $gcrnode.txt $DLTEST_LOG_DIR/
echo "DL UNIT TEST completed on $gcrnode. Logs copied to $DLTEST_LOG_DIR/$gcrnode.txt"

#copy /opt/dl_unittest_bonete/test_plans/80gb-placeholder/runs/* to DLTEST_LOG_DIR
cp -r $SCRIPT_DIR/test_plans/80gb-placeholder/runs/* $DLTEST_LOG_DIR/
echo "Copied test run logs to $DLTEST_LOG_DIR/"

