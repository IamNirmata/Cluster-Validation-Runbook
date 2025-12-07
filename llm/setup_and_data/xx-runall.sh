set -eo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "Running setup"
bash ./0-setup.sh
echo "Running data"
bash ./1-data.sh
echo "Running model"
bash ./2-model.sh

echo "Setup and data scripts completed."

