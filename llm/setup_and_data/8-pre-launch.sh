cd /data/Cluster-Validation-Runbook/llm/setup_and_data
# git pull origin main
echo "Starting pre-launch setup and data scripts..."
# echo "make sure the secrets are set by running: source ../../../secrets.sh"
bash 0-setup.sh


# Create 1-slot hostfile for mpirun
sed 's/slots=[0-9]*/slots=1/g' /opt/hostfile > /opt/hostfile_setup


echo "Pre-launch setup and data scripts completed."

ls -lart /data/llm/
ls -lart /data/llm/models/
ls -lart /data/llm/datasets/

# local copies of data and model are now in /opt/llm/



