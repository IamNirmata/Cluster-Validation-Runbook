cd /data/Cluster-Validation-Runbook/llm/setup_and_data
# git pull origin main
echo "Starting pre-launch setup and data scripts..."
# echo "make sure the secrets are set by running: source ../../../secrets.sh"
bash 0-setup.sh
# bash 1-data.sh
# bash 2-model.sh

# Create 1-slot hostfile for mpirun
sed 's/slots=[0-9]*/slots=1/g' /opt/hostfile > /opt/hostfile_setup


echo "Pre-launch setup and data scripts completed."

ls -lart /data/llm/
ls -lart /data/llm/models/
ls -lart /data/llm/datasets/

# local copies of data and model are now in /opt/llm/



"""
# Set environment variables for this node

# This gets exported into the shell environment
export MASTER_ADDR=$(hostname -i)
export MASTER_PORT=12345
NNODES=($(wc -l < /opt/hostfile))
export WORLD_SIZE=$((${NNODES[0]} * 8))
export NODE_RANK=0
torchrun --nproc_per_node=8 \
         --nnodes=${NNODES[0]} \
         --node_rank=0 \
         --master_addr=$MASTER_ADDR \
         --master_port=$MASTER_PORT \
         fsdp.py

# Set environment variables for this node
export MASTER_ADDR=10.45.158.220
export MASTER_PORT=12345
export WORLD_SIZE=3824
export NODE_RANK=

torchrun --nproc_per_node=8 \
         --nnodes=478 \
         --node_rank=1 \
         --master_addr=$MASTER_ADDR \
         --master_port=$MASTER_PORT \
         fsdp.py


# 1. Ensure you are using the 1-slot hostfile (Critical!)
# If you use the 8-slot file, you will launch 8 torchruns per node and crash everything.

mpirun \
    --allow-run-as-root \
    --hostfile /opt/hostfile_setup \
    --bind-to none \
    bash -c '
    # -------------------------------------------------------
    # DYNAMIC VARIABLES PROVIDED BY MPI
    # -------------------------------------------------------
    export NODE_RANK=$OMPI_COMM_WORLD_RANK
    
    # -------------------------------------------------------
    # YOUR STATIC SETTINGS
    # -------------------------------------------------------
    export MASTER_ADDR=10.45.158.220
    export MASTER_PORT=12345
    export WORLD_SIZE=3824  # (478 nodes * 8 GPUs)
    
    echo "Node $(hostname): Starting torchrun (Node Rank: $NODE_RANK)..."

    # -------------------------------------------------------
    # EXECUTE TORCHRUN
    # -------------------------------------------------------
    torchrun \
        --nproc_per_node=8 \
        --nnodes=478 \
        --node_rank=$NODE_RANK \
        --master_addr=$MASTER_ADDR \
        --master_port=$MASTER_PORT \
        /opt/Cluster-Validation-Runbook/llm/fsdp.py
    '


"""