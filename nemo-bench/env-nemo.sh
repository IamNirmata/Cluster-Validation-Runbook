#!/bin/bash
set -xeo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends openssh-server openssh-client ca-certificates git pdsh

# 2. Start SSH Daemon
echo "Starting SSH daemon..."
mkdir -p /run/sshd 
ssh-keygen -A
/usr/sbin/sshd -D -e &

# 3. Wait for Volcano Host Variables
echo "Waiting for VC_SERVER_HOSTS..."
while [ -z "$VC_SERVER_HOSTS" ]; do
  echo "  ... VC_SERVER_HOSTS is not set, retrying in 2s..."
  sleep 2
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
done
echo "VC_SERVER_HOSTS is ready: $VC_SERVER_HOSTS"

# 4. Generate Hostfile
echo "Creating /opt/hostfile..."
: > /opt/hostfile # Clear file
for host in ${VC_SERVER_HOSTS//,/ }; do echo "$host slots=8" >> /opt/hostfile; done
for host in ${VC_CLIENT_HOSTS//,/ }; do echo "$host slots=8" >> /opt/hostfile; done

echo "--- Hostfile (/opt/hostfile) ---"
cat /opt/hostfile
echo "--------------------------------"

# 5. Set Master Address
export MASTER_ADDR=$(hostname -i)
export MASTER_PORT=12345
echo "Setup complete. MASTER_ADDR=$MASTER_ADDR"