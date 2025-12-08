#!/usr/bin/env bash

##-------------------------- SETUP ENVIRONMENT --------------------------
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
echo ">>> Installing dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends sudo openssh-server openssh-client ca-certificates \
ibverbs-utils rdmacm-utils perftest infiniband-diags iputils-ping

# 2. Ensure Volcano Variables are Loaded
if [ -z "$VC_SERVER_HOSTS" ]; then
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
fi

# 3. SSH Configuration (Shared Keys Strategy)
# We assume /data is the shared PVC mount point
SHARED_SSH_DIR="/data/ssh"
mkdir -p /root/.ssh

# Determine role: The first host in VC_SERVER_HOSTS is the "Master" responsible for key gen
MASTER_HOST=$(echo $VC_SERVER_HOSTS | cut -d',' -f1)

# Check if we are the master (Match hostname prefix to handle FQDN differences)
if [[ "$MASTER_HOST" == "$HOSTNAME"* ]]; then
    echo ">>> [Role: MASTER] Checking shared SSH keys..."
    
    if [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; then
        echo "    Generating new SSH key pair in $SHARED_SSH_DIR..."
        mkdir -p "$SHARED_SSH_DIR"
        ssh-keygen -t rsa -b 4096 -f "$SHARED_SSH_DIR/id_rsa" -N ""
        chmod 600 "$SHARED_SSH_DIR/id_rsa"
    else
        echo "    SSH keys already exist in shared storage."
    fi
else
    echo ">>> [Role: WORKER] Waiting for SSH keys..."
    # Loop until the master creates the key
    while [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; do
        echo "    Waiting for master to generate keys in $SHARED_SSH_DIR..."
        sleep 5
    done
    echo "    Keys found!"
fi

# 4. Install Keys Locally (On ALL Nodes)
echo ">>> Installing SSH keys to /root/.ssh..."
cp "$SHARED_SSH_DIR/id_rsa" /root/.ssh/id_rsa
cp "$SHARED_SSH_DIR/id_rsa.pub" /root/.ssh/id_rsa.pub
cp "$SHARED_SSH_DIR/id_rsa.pub" /root/.ssh/authorized_keys

# 5. Configure SSH Client (Disable StrictHostKeyChecking)
echo "Host *" > /root/.ssh/config
echo "    StrictHostKeyChecking no" >> /root/.ssh/config
chmod 600 /root/.ssh/config
chmod 600 /root/.ssh/id_rsa
chmod 600 /root/.ssh/authorized_keys

# 6. Start SSH Daemon
echo ">>> Starting SSH Daemon..."
mkdir -p /run/sshd
ssh-keygen -A # Generate host keys
/usr/sbin/sshd -D -e &

# 7. Generate Hostfiles
echo ">>> Generating hostfiles..."
# Clear files first to avoid appending if script reruns
: > /opt/hostfile 

for host in ${VC_SERVER_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile
if [ -n "$VC_CLIENT_HOSTS" ]; then
    for host in ${VC_CLIENT_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile
fi

echo "--- Hostfile (/opt/hostfile) ---"
cat /opt/hostfile
echo "--------------------------------"

# Create a new hostfile without the slots directive (for standard MPI usage)
sed -E 's/[[:space:]]*slots=[0-9]+//' /opt/hostfile > /opt/hostfile.mpi
echo "--- MPI Hostfile (/opt/hostfile.mpi) ---"
cat /opt/hostfile.mpi
echo "--------------------------------"

# Export Globals
export NNODES=$(wc -l < /opt/hostfile)
export WORLD_SIZE=$((NNODES * 8))

echo ">>> Environment Setup Complete. World Size: $WORLD_SIZE"