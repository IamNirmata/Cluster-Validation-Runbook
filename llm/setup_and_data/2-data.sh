
echo "nfs directory : ${nfsdir}"

# 2. Ensure directory exists
mkdir -p ${nfsdir}/datasets

# 3. Run the download script locally
echo "Downloading to Shared Storage at ${nfsdir}/datasets/xlam-function-calling-60k ..."
python3 -c "from datasets import load_dataset; \
import os; \
dataset = load_dataset('Salesforce/xlam-function-calling-60k', split='train', token=os.environ.get('HF_TOKEN')); \
dataset.save_to_disk('${nfsdir}/datasets/xlam-function-calling-60k')"

echo "Dataset downloaded to ${nfsdir}/datasets/xlam-function-calling-60k"
ls -lh ${nfsdir}/datasets/xlam-function-calling-60k