#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTROL_FIFO="/tmp/allpair_control"
SSHD_PID=""
signal_sent=0


#ssh wait for clients to be reachable via ssh
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

for host in ${VC_SERVER_HOSTS//,/ }; do
  echo "$host slots=8"
done > /opt/hostfile
for host in ${VC_CLIENT_HOSTS//,/ }; do
  echo "$host slots=8"
done >> /opt/hostfile

git clone https://github.com/IamNirmata/Distrbuted_training_tools.git /opt/Distrbuted_training_tools

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
else
  status=$?
  echo "allpair.sh exited with status $status" >&2
  print_log_summary
  exit "$status"
fi
