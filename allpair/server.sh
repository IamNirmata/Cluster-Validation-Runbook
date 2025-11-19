#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_FIFO="/tmp/allpair_control"
SSHD_PID=""
signal_sent=0


#SSH - wait for clients to be reachable via ssh
wait_for_clients() {
  if [[ -z "${VC_CLIENT_HOSTS:-}" ]]; then
    return 0
  fi

  IFS=',' read -ra raw_clients <<< "${VC_CLIENT_HOSTS}"
  for raw_host in "${raw_clients[@]}"; do
    local host
    host="$(echo "$raw_host" | xargs)"
    if [[ -z "$host" ]]; then
      continue
    fi

    echo "Waiting for SSH on $host ..."
    local ready=0
    for attempt in {1..60}; do
      if ssh -o BatchMode=yes \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o ConnectTimeout=5 \
            "$host" true >/dev/null 2>&1; then
        ready=1
        break
      fi
      sleep 2
    done

    if (( ready == 0 )); then
      echo "ERROR: Unable to reach $host via SSH after waiting" >&2
      return 1
    fi
  done
}


# Print summary of all per-pair logs
print_log_summary() {
  if [[ ! -d "$LOGDIR" ]]; then
    echo "No log directory $LOGDIR found."
    return
  fi

  mapfile -t log_files < <(find "$LOGDIR" -maxdepth 1 -type f -name 'round*_job*.log' | sort)
  if (( ${#log_files[@]} == 0 )); then
    echo "No per-pair logs were generated in $LOGDIR."
    return
  fi

  echo "=== AllReduce log summary ($LOGDIR) ==="
  for log_file in "${log_files[@]}"; do
    echo "--- ${log_file} ---"
    if [[ -s "$log_file" ]]; then
      tail -n 20 "$log_file" || true
    else
      echo "(empty log)"
    fi
  done
  echo "=== End of log summary ==="
}


# Generate CSV report from logs
generate_csv_report() {
  local csv_file="${LOGDIR}/results.csv"
  echo "pair 1, pair 2, latency, busbw" > "$csv_file"

  if [[ ! -d "$LOGDIR" ]]; then
    echo "No log directory $LOGDIR found."
    return
  fi

  mapfile -t log_files < <(find "$LOGDIR" -maxdepth 1 -type f -name 'round*_job*.log' | sort)
  
  for log_file in "${log_files[@]}"; do
    local filename=$(basename "$log_file")
    # Remove prefix roundX_jobY_
    local temp="${filename#round*_job*_}"
    # Remove suffix .log
    temp="${temp%.log}"
    
    # Split by --
    local node1="${temp%--*}"
    local node2="${temp##*--}"
    
    # Calculate average latency
    local avg_latency=$(grep "latency:" "$log_file" | awk -F'latency: ' '{print $2}' | awk '{print $1}' | awk '{sum+=$1; n++} END {if (n>0) printf "%.8f", sum/n; else print "0"}')
    
    # Calculate average busbw
    local avg_busbw=$(grep "busbw:" "$log_file" | awk -F'busbw: ' '{print $2}' | awk '{print $1}' | awk '{sum+=$1; n++} END {if (n>0) printf "%.8f", sum/n; else print "0"}')
    
    echo "$node1, $node2, $avg_latency, $avg_busbw" >> "$csv_file"
  done
  
  echo "CSV report generated at $csv_file"
  cat "$csv_file"
}


# Send completion signal to all clients
send_completion() {
  local code=${1:-0}
  if (( signal_sent == 1 )); then
    return
  fi

  if [[ -z "${VC_CLIENT_HOSTS:-}" ]]; then
    signal_sent=1
    return
  fi

  IFS=',' read -ra raw_clients <<< "${VC_CLIENT_HOSTS}"
  local clients=()
  for host in "${raw_clients[@]}"; do
    host="${host//[[:space:]]/}"
    if [[ -n "$host" ]]; then
      clients+=("$host")
    fi
  done

  local count=${#clients[@]}
  if (( count == 0 )); then
    signal_sent=1
    return
  fi

  local hostlist
  hostlist=$(IFS=','; echo "${clients[*]}")

  local message="done"
  if (( code != 0 )); then
    message="failed"
  fi

  export COMPLETION_MESSAGE="$message"
  export ALLPAIR_CONTROL_FIFO="$CONTROL_FIFO"

  set +e
  mpirun \
    --allow-run-as-root \
    --tag-output \
    --map-by ppr:1:node \
    -np "$count" \
    --host "$hostlist" \
    -x COMPLETION_MESSAGE \
    -x ALLPAIR_CONTROL_FIFO \
    bash -lc 'printf "%s\n" "${COMPLETION_MESSAGE:-done}" > "${ALLPAIR_CONTROL_FIFO:-/tmp/allpair_control}"'
  if [[ $? -ne 0 ]]; then
    echo "WARN: Unable to broadcast completion marker via mpirun" >&2
  fi
  set -e

  signal_sent=1
}


# Cleanup function to handle script termination
cleanup() {
  local code=${1:-0}

  if (( signal_sent == 0 )); then
    send_completion "$code"
  fi

  set +e
  if [[ -n "${SSHD_PID:-}" ]]; then
    kill "$SSHD_PID" 2>/dev/null || true
    wait "$SSHD_PID" 2>/dev/null || true
  fi
  rm -f "$CONTROL_FIFO"
  set -e
}

trap 'code=$?; trap - EXIT; cleanup "$code"; exit "$code"' EXIT



# Set up environment
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  openssh-server \
  openssh-client \
  ca-certificates \
  ibverbs-utils \
  rdmacm-utils \
  perftest \
  infiniband-diags

mkdir -p /run/sshd
ssh-keygen -A
/usr/sbin/sshd -D -e &
SSHD_PID=$!

rm -f "$CONTROL_FIFO"
mkfifo "$CONTROL_FIFO"



# Generate Hostfile
for host in ${VC_SERVER_HOSTS//,/ }; do
  echo "$host slots=8"
done > /opt/hostfile
for host in ${VC_CLIENT_HOSTS//,/ }; do
  echo "$host slots=8"
done >> /opt/hostfile


# Clone Cluster Validation Runbook repository if it is not already present
if [[ ! -d /opt/Cluster-Validation-Runbook/.git ]]; then
  git clone https://github.com/IamNirmata/Cluster-Validation-Runbook.git /opt/Cluster-Validation-Runbook
else
  echo "Cluster-Validation-Runbook already present at /opt; skipping clone."
fi

echo "#########################Hostfile#########################"
cat /opt/hostfile
echo "##########################################################"

export HOSTFILE=/opt/hostfile
export LOGDIR=${LOGDIR:-/opt/allpair-logs}
mkdir -p "$LOGDIR"

wait_for_clients

echo "Starting automatic allpair run via $SCRIPT_DIR/allpair.sh"
if bash "$SCRIPT_DIR/allpair.sh"; then
  print_log_summary
  generate_csv_report
else
  status=$?
  echo "allpair.sh exited with status $status" >&2
  print_log_summary
  generate_csv_report
  exit "$status"
fi
