#!/bin/bash
set -eo pipefail

HOSTFILE="/opt/hostfile"

if [ ! -f "$HOSTFILE" ]; then
  echo "Hostfile $HOSTFILE not found. Exiting."
  exit 1
fi

echo "Waiting for all SSH daemons to be ready..."
# Loop through each hostname in the hostfile (field 1)
for host in $(awk '{print $1}' $HOSTFILE); do
  echo "  > Checking SSH on host: $host"
  
  # CHANGE: Use 'ssh' instead of 'ssh-keyscan'. 
  # This confirms we can actually log in (auth works).
  # -o ConnectTimeout=5: Fail fast if network is down
  # -o BatchMode=yes: Fail instead of prompting for password
  # -o StrictHostKeyChecking=no: Don't block on new fingerprints
  until ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$host" true >/dev/null 2>&1; do
    echo "    ... SSH to $host failed. Retrying in 2s..."
    sleep 2
  done
  
  echo "  > Host $host is ready."
done
echo "All SSH daemons are up and authenticated."