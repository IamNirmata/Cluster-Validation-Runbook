#!/bin/bash
set -xeo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install dependencies
echo "Installing dependencies..."
for i in {1..5}; do
    apt-get update -y && break || { echo "apt-get update failed, retrying..."; sleep 5; }
done
apt-get install -y --no-install-recommends openssh-server openssh-client ca-certificates git pdsh

# 2. Start SSH Daemon
echo "Starting SSH daemon..."
mkdir -p /run/sshd 
ssh-keygen -A
/usr/sbin/sshd -D -e &

# 3. Wait for Volcano Host Variables
echo "Waiting for VC_SERVER_HOSTS..."
while [ -z "$VC_SERVER_HOSTS" ]; do
  echo "  ... VC_SERVER_HOSTS not ready. Sleeping 2s..."
  sleep 2
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
done

# 4. Generate Hostfile
echo "Creating /opt/hostfile..."
: > /opt/hostfile

for host in ${VC_SERVER_HOSTS//,/ }; do 
    echo "$host slots=8" >> /opt/hostfile
done

if [ ! -z "$VC_CLIENT_HOSTS" ]; then
    for host in ${VC_CLIENT_HOSTS//,/ }; do 
        echo "$host slots=8" >> /opt/hostfile
    done
fi

export MASTER_ADDR=$(hostname -i)
export MASTER_PORT=12345
echo "Setup complete. MASTER_ADDR=$MASTER_ADDR"