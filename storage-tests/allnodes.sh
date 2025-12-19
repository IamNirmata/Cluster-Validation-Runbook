#!/bin/bash

# Configuration
TEMPLATE_FILE="/home/hari/b200/validation/Cluster-Validation-Runbook/storage-tests/specific-node.yml"
BASE_NODE_NAME="slc01-cl02-hgx"
START=1
END=479

echo "Starting job submission for nodes ${START} to ${END}..."

for (( i=$START; i<=$END; i++ ))
do
    # Pad the number with leading zeros to 3 digits (e.g., 1 -> 001)
    NODE_ID=$(printf "%03d" $i)
    FULL_NODE_NAME="${BASE_NODE_NAME}-${NODE_ID}"

    echo "Submitting job for node: ${FULL_NODE_NAME}"

    # Use sed to replace the specific hostname in the YAML and pipe to kubectl
    # This looks for the line after nodeSelector and replaces the hostname value
    sed "s/kubernetes.io\/hostname: \".*\"/kubernetes.io\/hostname: \"${FULL_NODE_NAME}\"/" "$TEMPLATE_FILE" | kubectl create -f -

    # Optional: Add a small sleep to avoid overwhelming the K8s API server
    # sleep 0.5
done

echo "All jobs submitted."