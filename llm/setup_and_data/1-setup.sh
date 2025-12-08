set -eo pipefail
export DEBIAN_FRONTEND=noninteractive



# directory setup
export nfsdir="/data/llm"
export localdir="/opt/llm"
export codedir="/data/Cluster-Validation-Runbook/llm"

# create directories
mkdir -p $nfsdir
mkdir -p $localdir


#install dependencies

python -m pip install --upgrade pip --break-system-packages
pip install --break-system-packages \
    -r $codedir/setup_and_data/requirements.txt \
    -U datasets wandb transformers peft bitsandbytes accelerate huggingface_hub trl hf_transfer



EXPORTS="
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,ENV,NET
export NCCL_ASYNC_ERROR_HANDLING=1
export TORCH_NCCL_ASYNC_ERROR_HANDLING=1
export NCCL_NVLS_ENABLE=0
export NCCL_SHARP_DISABLE=1
export NCCL_P2P_DISABLE=0
export NCCL_NET_GDR_LEVEL=PHB
export NCCL_SOCKET_IFNAME=eth0
export MASTER_PORT=23456
export OMP_NUM_THREADS=1
"

# Apply them now
echo "$EXPORTS" > /etc/profile.d/nccl_env.sh
source /etc/profile.d/nccl_env.sh
sed 's/slots=[0-9]*/slots=1/g' /opt/hostfile > /opt/hostfile_setup
# Ensure they load on next login/ssh
echo "Environment variables saved to /etc/profile.d/nccl_env.sh"


cd $codedir
echo "Starting setup and data scripts..."

chmod +x setup_and_data/*.sh
