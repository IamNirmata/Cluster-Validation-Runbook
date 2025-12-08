#!/usr/bin/env bash
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies
echo ">>> Installing dependencies..."
apt-get update -y
apt-get install -y --no-install-recommends sudo openssh-server openssh-client ca-certificates \
ibverbs-utils rdmacm-utils perftest infiniband-diags iputils-ping

# 2. Load Volcano Environment
if [ -z "$VC_SERVER_HOSTS" ]; then
  if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
fi

# 3. Setup SSH Paths (Bypassing Read-Only /root)
SHARED_SSH_DIR="/data/ssh"
mkdir -p "$SHARED_SSH_DIR"

# 4. Generate or Wait for Keys (Master/Worker Logic)
MASTER_HOST=$(echo $VC_SERVER_HOSTS | cut -d',' -f1)

if [[ "$MASTER_HOST" == "$HOSTNAME"* ]]; then
    echo ">>> [Role: MASTER] Managing SSH keys..."
    if [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; then
        echo "    Generating new SSH key pair..."
        # Generate to shared storage directly
        ssh-keygen -t rsa -b 4096 -f "$SHARED_SSH_DIR/id_rsa" -N ""
        
        # Create authorized_keys in shared storage
        cp "$SHARED_SSH_DIR/id_rsa.pub" "$SHARED_SSH_DIR/authorized_keys"
        
        # Fix permissions (crucial for SSH)
        chmod 600 "$SHARED_SSH_DIR/id_rsa"
        chmod 600 "$SHARED_SSH_DIR/authorized_keys"
        chmod 700 "$SHARED_SSH_DIR"
    fi
else
    echo ">>> [Role: WORKER] Waiting for SSH keys..."
    while [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; do
        echo "    Waiting for master to generate keys..."
        sleep 5
    done
fi

# 5. Configure SSH Server (sshd) to read keys from /data
# We modify the global config since we can't touch /root/.ssh
echo ">>> Configuring SSH Server..."
sed -i 's|^#*AuthorizedKeysFile.*|AuthorizedKeysFile /data/ssh/authorized_keys|g' /etc/ssh/sshd_config
# Disable strict mode checks because /data permissions might be too open on PVCs
echo "StrictModes no" >> /etc/ssh/sshd_config

# 6. Configure SSH Client (ssh) to use keys from /data
# We modify the global client config to avoid needing /root/.ssh/config
echo ">>> Configuring SSH Client..."
cat >> /etc/ssh/ssh_config <<EOF
Host *
    IdentityFile /data/ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF

# 7. Start SSH Daemon
echo ">>> Starting SSH Daemon..."
mkdir -p /run/sshd
ssh-keygen -A
/usr/sbin/sshd -D -e &

# 8. Generate Hostfiles
echo ">>> Generating hostfiles..."
: > /opt/hostfile 
for host in ${VC_SERVER_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile
if [ -n "$VC_CLIENT_HOSTS" ]; then
    for host in ${VC_CLIENT_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile
fi

sed -E 's/[[:space:]]*slots=[0-9]+//' /opt/hostfile > /opt/hostfile.mpi

export NNODES=$(wc -l < /opt/hostfile)
export WORLD_SIZE=$((NNODES * 8))

echo ">>> Environment Setup Complete. Ready."