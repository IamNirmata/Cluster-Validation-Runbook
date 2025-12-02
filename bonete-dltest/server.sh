#!/usr/bin/env bash

set -eo pipefail
echo "Starting DL UNIT TEST in all servers"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up environment
export DEBIAN_FRONTEND=noninteractive

# for i in {1..5}; do apt-get update -y && break || sleep 15; done
# apt-get install -y --no-install-recommends \
#   openssh-server \
#   openssh-client \
#   ca-certificates \
#   ibverbs-utils \
#   rdmacm-utils \
#   perftest \
#   infiniband-diags


# Clone Cluster Validation Runbook repository if it is not already present
if [[ ! -d /opt/Cluster-Validation-Runbook/.git ]]; then
  git clone https://github.com/IamNirmata/Cluster-Validation-Runbook.git /opt/Cluster-Validation-Runbook
else
  echo "Cluster-Validation-Runbook already present at /opt; skipping clone."
fi


# Use persistent storage for logs if available, to support checkpointing/resuming
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# LOGDIR LOGIC:
# 1. If LOGDIR is already set (e.g. from YAML env var), use it (Resume scenario).
# 2. If not set, create a new timestamped directory.
if [[ -z "${LOGDIR:-}" ]]; then
    if [[ -d "/data" ]]; then
        export LOGDIR="/data/dltest/${TIMESTAMP}"
    else
        export LOGDIR="/opt/dltest-logs/${TIMESTAMP}"
    fi
    echo "LOGDIR was not set. Created new log directory: $LOGDIR"
else
    echo "LOGDIR is explicitly set. Resuming/Using directory: $LOGDIR"
fi

mkdir -p "$LOGDIR"






