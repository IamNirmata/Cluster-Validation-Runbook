set -eo pipefail
export DEBIAN_FRONTEND=noninteractive



# directory setup
nfsdir="/data/llm"
localdir="/opt/llm"
codedir="/data/Cluster-Validation-Runbook/llm"

mkdir -p $nfsdir
mkdir -p $localdir


#install dependencies

apt-get update -y
apt-get install -y --no-install-recommends openssh-server openssh-client ca-certificates \
ibverbs-utils rdmacm-utils perftest infiniband-diags 
pip install -r $codedir/setup_and_data/requirements.txt --break-system-packages

# export gcrnode=$(cat /opt/gcrnode.txt)
# echo "GCR Node name: $gcrnode"



pip install --upgrade trl --break-system-packages
pip install -U datasets --break-system-packages
pip install -U wandb transformers peft bitsandbytes accelerate huggingface_hub trl --break-system-packages
python -m pip install --upgrade pip --break-system-packages

chmod +x $codedir/tools/*.sh




# ... (your existing installs) ...

# Define variables
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












# REPO_DIR=/workspace/distrbuted_training_tools
# git clone https://github.com/IamNirmata/distrbuted_training_tools.git "$REPO_DIR"

cd $codedir
echo "Starting setup and data scripts..."

chmod +x setup_and_data/*.sh


# bash setup_and_data/1-data.sh
# bash setup_and_data/2-model.sh