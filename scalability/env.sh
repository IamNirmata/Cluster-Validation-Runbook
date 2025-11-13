#!/bin/bash
set -xeo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends openssh-server openssh-client ca-certificates

# 2. Start SSH Daemon
echo "Starting SSH daemon..."
mkdir -p /run/sshd && ssh-keygen -A
/usr/sbin/sshd -D -e &

# 3. Wait for Volcano Host Variables
echo "Waiting for VC_SERVER_HOSTS..."
while [ -z "$VC_SERVER_HOSTS" ]; do
  echo "  ... VC_SERVER_HOSTS is not set, retrying in 2s..."
  sleep 2
  # Source the env file again, as it might be populated late
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
done
echo "VC_SERVER_HOSTS is ready: $VC_SERVER_HOSTS"

# 4. Generate Hostfile
echo "Creating /opt/hostfile..."
for host in ${VC_SERVER_HOSTS//,/ }; do echo "$host slots=8"; done > /opt/hostfile
for host in ${VC_CLIENT_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile

echo "--- Hostfile (/opt/hostfile) ---"
cat /opt/hostfile
echo "--------------------------------"

# 5. Set Master Address (Using IP to avoid DNS flakes)
# This gets exported into the shell environment
export MASTER_ADDR=$(hostname -i)
export MASTER_PORT=12345
echo "Setup complete. MASTER_ADDR=$MASTER_ADDR"