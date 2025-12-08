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

# 3. Setup Paths
# SHARED: Used to transfer keys between Master and Workers (on PVC)
SHARED_SSH_DIR="/data/ssh"
# LOCAL: Used by SSHD/SSH client for actual auth (Avoids PVC permission issues)
LOCAL_SSH_DIR="/etc/ssh/cluster_keys"

mkdir -p "$SHARED_SSH_DIR"
mkdir -p "$LOCAL_SSH_DIR"

# 4. Generate or Wait for Keys (Master/Worker Logic)
MASTER_HOST=$(echo $VC_SERVER_HOSTS | cut -d',' -f1)

if [[ "$MASTER_HOST" == "$HOSTNAME"* ]]; then
    echo ">>> [Role: MASTER] Managing SSH keys..."
    if [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; then
        echo "    Generating new SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "$SHARED_SSH_DIR/id_rsa" -N ""
        cp "$SHARED_SSH_DIR/id_rsa.pub" "$SHARED_SSH_DIR/authorized_keys"
        chmod 600 "$SHARED_SSH_DIR/id_rsa"
        chmod 600 "$SHARED_SSH_DIR/authorized_keys"
    fi
else
    echo ">>> [Role: WORKER] Waiting for SSH keys..."
    while [ ! -f "$SHARED_SSH_DIR/id_rsa" ]; do
        sleep 5
    done
fi

# 5. Copy keys to LOCAL secure directory
# This fixes "Permission denied" caused by PVCs having open permissions (777)
echo ">>> Installing keys to local secure storage..."
cp "$SHARED_SSH_DIR/id_rsa" "$LOCAL_SSH_DIR/id_rsa"
cp "$SHARED_SSH_DIR/id_rsa.pub" "$LOCAL_SSH_DIR/id_rsa.pub"
cp "$SHARED_SSH_DIR/authorized_keys" "$LOCAL_SSH_DIR/authorized_keys"

# Fix permissions locally
chmod 700 "$LOCAL_SSH_DIR"
chmod 600 "$LOCAL_SSH_DIR/id_rsa"
chmod 600 "$LOCAL_SSH_DIR/authorized_keys"

# 6. Configure SSH Server (sshd)
# We forcefully replace StrictModes and AuthorizedKeysFile settings
echo ">>> Configuring SSH Server..."
sed -i 's/^#*StrictModes.*/StrictModes no/' /etc/ssh/sshd_config
sed -i 's|^#*AuthorizedKeysFile.*|AuthorizedKeysFile /etc/ssh/cluster_keys/authorized_keys|g' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Ensure /run/sshd exists
mkdir -p /run/sshd

# 7. Configure SSH Client (ssh)
# We create a global config to force using the specific key
echo ">>> Configuring SSH Client..."
cat > /etc/ssh/ssh_config.d/99-cluster.conf <<EOF
Host *
    IdentityFile /etc/ssh/cluster_keys/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF

# 8. Start SSH Daemon
echo ">>> Starting SSH Daemon..."
ssh-keygen -A
/usr/sbin/sshd -D -e &

# 9. Generate Hostfiles
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