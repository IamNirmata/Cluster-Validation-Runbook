set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

export TIMESTAMP=$(TZ='America/Los_Angeles' date '+%Y-%m-%d_%H-%M-%S')

mkdir -p /data/dltest-logs/$TIMESTAMP
export DLTEST_LOG_DIR="/data/dltest-logs/$TIMESTAMP"
echo "DLTEST_LOG_DIR set to $DLTEST_LOG_DIR"

