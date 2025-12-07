#!/bin/bash
set -eo pipefail

HOSTFILE="/opt/hostfile"

if [ ! -f "$HOSTFILE" ]; then
  echo "Hostfile $HOSTFILE not found. Exiting."
  exit 1
fi

echo "Waiting for all SSH daemons to be ready..."
for host in $(awk '{print $1}' $HOSTFILE); do
  echo "  > Checking SSH on host: $host"
  until ssh-keyscan -p 22 $host
  do
    echo "    ... SSHd on $host not responding, retrying in 2s..."
    sleep 2
  done
  echo "  > Host $host is ready."
done
echo "All SSH daemons are up."