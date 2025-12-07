# Scalability Tests – Quick Guide

This folder contains the three production GPU AllReduce tests invoked by `ymls/scalability.yml`. The helper scripts `latency.sh`, `bw.sh`, and `scale.sh` are the only workloads expected in regular runs. The `unit-test-runs/` directory holds developer-only debug helpers and is not part of the standard flow.

## 1. Before You Launch

- Confirm the Volcano job manifest `ymls/scalability.yml` points at the correct namespace, queue, GPU count, and PVCs for your cluster.
- Ensure the container image `nvcr.io/nvidia/pytorch:25.06-py3` is accessible.
- Rotate/replace any inline Git credentials in the manifest with secrets prior to deployment.
- Validate the hostfile will be populated under `/opt/hostfile` by the Volcano SSH plugin.

## 2. Start the Job

```bash
kubectl apply -f ymls/scalability.yml
```

The manifest launches one **server** pod and two **client** pods. The server pod clones this repository, makes the scripts executable, and sequentially runs:

1. `latency.sh` – 2-byte NCCL latency matrix (SHARP vs. non-SHARP, Ring vs. Tree).
2. `bw.sh` – 16 GB NCCL bandwidth matrix across the same settings.
3. `scale.sh` – multi-node scaling sweep (default step defined in `scale.sh`).

Each script writes a timestamped summary table under `./allreduce_logs` (inside the cloned repo directory, i.e., `/opt/Cluster-Validation-Runbook/scalability/allreduce_logs`).


## 3. Collect Results

- Download the contents of `/opt/Cluster-Validation-Runbook/scalability/allreduce_logs` from the server pod.
- Scalability test results are stored in '/opt/Cluster-Validation-Runbook/scalability/logs'.
- Each test produces a Markdown-style table summarizing the key metrics (latency or bus bandwidth).
- please provide STDOUT/STDERR log also during the cluster handoff.

