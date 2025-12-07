# # Download the XLAM-60k dataset
# echo "Downloading and saving XLAM-60k dataset to ${localdir}/datasets/xlam-function-calling-60k ..."
# python -c "from datasets import load_dataset; \
# dataset = load_dataset('Salesforce/xlam-function-calling-60k', split='train'); \
# dataset.save_to_disk('${localdir}/datasets/xlam-function-calling-60k')"


# # In 0-setup.sh
# echo "Downloading and saving XLAM-60k dataset..."
# python -c "from datasets import load_dataset; \
# import os; \
# dataset = load_dataset('Salesforce/xlam-function-calling-60k', split='train', token=os.environ.get('HF_TOKEN')); \
# dataset.save_to_disk('${localdir}/datasets/xlam-function-calling-60k')"


# 1. Export Keys locally

export localdir="/data/llm"  # <--- NOTE: Saving to /data (NFS) first!

# 2. Ensure directory exists
mkdir -p ${localdir}/datasets

# 3. Run the download script locally
echo "Downloading to Shared Storage ($localdir)..."
python3 -c "from datasets import load_dataset; \
import os; \
dataset = load_dataset('Salesforce/xlam-function-calling-60k', split='train', token=os.environ.get('HF_TOKEN')); \
dataset.save_to_disk('${localdir}/datasets/xlam-function-calling-60k')"