#!/usr/bin/env bash

##-------------------------- SETUP ENVIRONMENT --------------------------
set -eo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends sudo openssh-server openssh-client ca-certificates \
ibverbs-utils rdmacm-utils perftest infiniband-diags iputils-ping



# # 3. Wait for Volcano Host Variables
# echo "Waiting for VC_SERVER_HOSTS..."
# while [ -z "$VC_SERVER_HOSTS" ]; do
#   echo "  ... VC_SERVER_HOSTS is not set, retrying in 2s..."
#   sleep 2
#   # Source the env file again, as it might be populated late
#   if [ -f /etc/volcano/env ]; then . /etc/volcano/env; fi
# done
# echo "VC_SERVER_HOSTS is ready: $VC_SERVER_HOSTS"



## setup hostfile
mkdir -p /run/sshd && ssh-keygen -A
/usr/sbin/sshd -D -e &
for host in ${VC_SERVER_HOSTS//,/ }; do echo "$host slots=8"; done > /opt/hostfile
for host in ${VC_CLIENT_HOSTS//,/ }; do echo "$host slots=8"; done >> /opt/hostfile


echo "--- Hostfile (/opt/hostfile) ---"
cat /opt/hostfile
echo "--------------------------------"