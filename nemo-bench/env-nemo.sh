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

# 3. Wait for Volcano Host Variables to be populated
# Volcano injects these. We wait until they are not empty.
echo "Waiting for VC_SERVER_HOSTS and VC_CLIENT_HOSTS..."
while [ -z "$VC_SERVER_HOSTS" ]; do
  echo "  ... VC_SERVER_HOSTS not ready. Sleeping 2s..."
  sleep 2
  # Reload env file if Volcano writes it late
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
done

# Optional: You can also wait for clients if you want to be strict, 
# though usually they populate at the same time.
echo "Volcano Hosts Found:"
echo "Server: $VC_SERVER_HOSTS"
# We don't print all 477 clients to logs to avoid spam, just a count check
CLIENT_COUNT=$(echo $VC_CLIENT_HOSTS | tr ',' '\n' | wc -l)
echo "Client Count: $CLIENT_COUNT"

# 4. Generate Hostfile for MPI
echo "Creating /opt/hostfile..."
: > /opt/hostfile # Clear file

# Add Server (Master)
for host in ${VC_SERVER_HOSTS//,/ }; do 
    echo "$host slots=8" >> /opt/hostfile
done

# Add Clients (Workers)
# If VC_CLIENT_HOSTS is empty, this loop just won't run (safe).
if [ ! -z "$VC_CLIENT_HOSTS" ]; then
    for host in ${VC_CLIENT_HOSTS//,/ }; do 
        echo "$host slots=8" >> /opt/hostfile
    done
fi

echo "--- Hostfile created with $(wc -l < /opt/hostfile) lines ---"

# 5. Set Master Address
export MASTER_ADDR=$(hostname -i)
export MASTER_PORT=12345
echo "Setup complete. MASTER_ADDR=$MASTER_ADDR"