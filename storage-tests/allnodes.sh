#!/bin/bash

# Configuration
TEMPLATE_FILE="/home/hari/b200/validation/Cluster-Validation-Runbook/storage-tests/specific-node.yml"
BASE_NODE_NAME="slc01-cl02-hgx"
START=1
END=479

echo "Starting job submission for nodes ${START} to ${END}..."

for (( i=$START; i<=$END; i++ ))
do
    # Pad the number with leading zeros (001, 002...)
    NODE_ID=$(printf "%03d" $i)
    FULL_NODE_NAME="${BASE_NODE_NAME}-${NODE_ID}"
    
    # Create a suffix for the Job name (e.g., hgx-001)
    # We use a shorter version for the metadata name to avoid K8s name length limits
    JOB_NAME_SUFFIX="hgx-${NODE_ID}-"

    echo "Submitting job for node: ${FULL_NODE_NAME}"

    # 1. Replace the generateName with the node-specific suffix
    # 2. Replace the nodeSelector hostname
    sed -e "s/generateName: .*/generateName: bonete-test-${JOB_NAME_SUFFIX}/" \
        -e "s/kubernetes.io\/hostname: \".*\"/kubernetes.io\/hostname: \"${FULL_NODE_NAME}\"/" \
        "$TEMPLATE_FILE" | kubectl create -f -

done

echo "All jobs submitted."