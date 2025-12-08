#!/bin/bash

echo "Downloading model files to ${nfsdir}/models ..."


export HF_HUB_ENABLE_HF_TRANSFER=1

MODEL_ID="meta-llama/Meta-Llama-3-8B-Instruct"
# TARGET="/models/Meta-Llama-3-8B-Instruct"
echo "Model ID: $MODEL_ID"
echo "NFS Dir: $nfsdir"
TARGET="$nfsdir/models/Meta-Llama-3-8B-Instruct"

mkdir -p "$TARGET"


python - <<PY
from huggingface_hub import snapshot_download, whoami
print("Auth:", whoami())  # should show your HF user
snapshot_download(
    repo_id="$MODEL_ID",
    local_dir="$TARGET",
    local_dir_use_symlinks=False,
    # keep it lean; pull model weights + config + tokenizer
    allow_patterns=[
        "*.safetensors","*.bin","*.json","*.model",
        "tokenizer*","vocab*","merges.txt","config*.json"
    ],
)
print("Download complete -> $TARGET")
PY

ls -lh ${nfsdir}/models/Meta-Llama-3-8B-Instruct
echo "Model download script completed."