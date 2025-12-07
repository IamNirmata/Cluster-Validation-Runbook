# NeMo Megatron Benchmark on B200 Cluster

This directory contains the scripts and configuration to run a large-scale **NeMo Megatron** benchmark on a **B200 HGX Cluster**. 

The current configuration is tuned for a **Llama 375B** model running on **3832 GPUs (479 Nodes)** using `torchrun` for orchestration.

## Overview

- **Model**: Llama ~375B Parameters
- **Parallelism**: 
  - Tensor Parallel (TP): 8
  - Pipeline Parallel (PP): 8
  - Sequence Parallel (SP): Enabled
- **Optimization**: 
  - Flash Attention
  - Transformer Engine (FP8)
  - Distributed Optimizer
- **Orchestration**: Volcano (Kubernetes) + Torchrun (PyTorch Distributed)

## File Structure

| File | Description |
|------|-------------|
| `yml-nemo.yml` | Volcano Job definition. Defines 1 Server pod and 478 Client pods. |
| `nemo-benchmark.sh` | **Main Entrypoint**. Configures the model, calculates parallelism, and launches training via `torchrun`. |
| `env-nemo.sh` | Common setup script. Installs dependencies, starts SSH, and generates the hostfile. |
| `server-nemo.sh` | Server-specific logic. Sets up signal handling to cleanly terminate clients when the job finishes. |
| `client-nemo.sh` | Client-specific logic. Starts SSH and waits for the termination signal from the server. |
| `wait-for-ssh-nemo.sh` | Helper script to ensure all nodes are reachable via SSH before starting `torchrun`. |

## Prerequisites

1.  **Kubernetes Cluster** with Volcano Scheduler installed.
2.  **Persistent Volume Claim (PVC)** named `pvc-vast-gcr-admin-test1` mounted at `/data`.
3.  **Docker Image**: `nvcr.io/nvidia/nemo:24.09` (or compatible).
4.  **Git Repository**: The job clones this repository (`IamNirmata/Cluster-Validation-Runbook`) at runtime. **You must push your local changes to GitHub for them to take effect.**

## Step-by-Step Guide

### 1. Configure the Benchmark
Edit `nemo-benchmark.sh` to adjust model parameters or parallelism settings.
```bash
# Example in nemo-benchmark.sh
SEQ_LEN=8192
HIDDEN_SIZE=16384
NUM_LAYERS=120
TP_SIZE=8
PP_SIZE=8
```

### 2. Push Changes to GitHub
The pods clone the code from the `main` branch of the repository. Ensure your latest scripts are pushed.
```bash
# From the root of the repo
git add .
git commit -m "Update benchmark config"
git push origin main
```
*(Note: If you have the `git_push_all.sh` loop running, this happens automatically).*

### 3. Submit the Job
Deploy the Volcano Job to the cluster.
```bash
kubectl create -f yml-nemo.yml
```

### 4. Monitor Progress
Check the status of the job and pods.
```bash
# Check Job Status
kubectl get vcjob -n gcr-admin-test1

# Watch Pods (Wait for them to become Running)
kubectl get pods -n gcr-admin-test1 -l job-name=<job-name> -w
```

### 5. View Logs
The main training logs are streamed from the **Server** pod (task index 0).
```bash
# Get the server pod name
SERVER_POD=$(kubectl get pods -n gcr-admin-test1 -l role=server --no-headers | awk '{print $1}' | head -n 1)

# Stream logs
kubectl logs -f -n gcr-admin-test1 $SERVER_POD
```

### 6. Clean Up
To stop the benchmark early or clean up after completion:
```bash
kubectl delete vcjob -n gcr-admin-test1 <job-name>
```

## Troubleshooting

- **Pod Stuck in Pending**: Check `kubectl describe pod <pod-name>`. Usually due to insufficient resources or scheduling constraints.
- **SSH Connection Refused**: The `wait-for-ssh-nemo.sh` script handles this, but if it hangs, check if the client pods are actually running and if the network policy allows communication on port 22.
- **"Address already in use"**: Ensure `MASTER_PORT` (default 29500) is not used by another process.
- **Git Clone Failed**: Check internet connectivity from the pods or verify the repository URL.
