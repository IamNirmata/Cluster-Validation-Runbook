
## Cluster Validation Runbook

Central guide for running application-level validation on Bonete B200 GPU clusters. Hardware, firmware, and Kubernetes baseline checks are handled elsewhere; this repository focuses on three workload suites that prove out distributed training readiness.

### Table of Contents
- [Overview](#overview)
- [Quick Start](#quick-start)
- [Repository Layout](#repository-layout)
- [Validation Workflow](#validation-workflow)
- [Deep Learning Unit Test](#deep-learning-unit-test)
- [Scalability Tests](#scalability-tests)
- [All Pair AllReduce Validation](#all-pair-allreduce-validation)
- [Result Handover Expectations](#result-handover-expectations)

## Overview

- Scope: application-level validation only; hardware and platform qualification remain with the Lab GPU team.
- Target cluster: Bonete B200 (adjust manifests if reusing on another environment).
- Outputs: per-test logs, summary tables, and environment evidence for handover (see [Result Handover Expectations](docs/result_handover_expectations.md)).
- Job config yamls with the launch scripts are available in  `launch/` and expect Volcano scheduling plus shared PVCs for log archival.

## Quick Start

1. **Clone and inspect** this repository locally.
2. **Configure credentials and namespaces** inside the manifests under `launch/`.
3. **Run the setup phases** (see [Validation Workflow](#validation-workflow)) to prepare hostfiles, PVC mount points, and logging directories.
4. **Execute each workload suite**:
	- Deep Learning Unit Test (`launch/dltest.yml`)
	- Scalability Tests (`launch/scalability.yml`)
	- All Pair AllReduce Validation (`launch/allpair/` scripts)
5. **Collect and archive logs** per the [handover checklist](docs/result_handover_expectations.md).

## Repository Layout

- `docs/` – final handover checklist, Deep Learning Unit Test instructions etc.
  - `docs/Deep_Learning_Unit_Test.md`
  - `docs/result_handover_expectations.md`
- `phases/` – Ordered scripts (`00-env.sh`, `01-pvc.sh`) sourced by the manifest init containers to prepare the environment.
- `scalability/` – AllReduce latency/bandwidth/scale scripts and logs.
- `allpair/` – NCCL pairwise validation harness including schedule generation.
- `launch/` – Volcano job manifests for the workloads (`dltest.yml`, `scalability.yml`, `npair.yml`).

## Validation Workflow

1. **Phase 00 – Environment setup** (`phases/00-env.sh`)
	- Installs SSH and Infiniband utilities, generates host keys, and builds `/opt/hostfile` from Volcano-provided environment variables.
2. **Phase 01 – PVC staging** (`phases/01-pvc.sh`)
	- Creates per-suite directories under `/data/cluster_validation` and updates `latest` symlinks for easy log discovery.
3. **Phase 02 – Running the tests** 
    - Executes the actual workload scripts for each validation suite.


## Deep Learning Unit Test

- Detailed instructions live in [docs/Deep_Learning_Unit_Test.md](docs/Deep_Learning_Unit_Test.md).
- Workload: proprietary suite distributed separately; manifests reference `/opt/deeplearning_unit_test/run_b200.sh`.
- Launch command: `kubectl apply -f launch/dltest.yml` once image, PVC, and GPU counts are verified.
- Outputs saved under `/data/cluster_validation/dltest/<date>` with a `latest` symlink for convenience.

## Scalability Tests

- Quick guide: [scalability/README.md](scalability/README.md).
- Workload scripts (`latency.sh`, `bw.sh`, `scale.sh`) run sequentially from the server pod spawned by `launch/scalability.yml`.
- Summary tables and raw logs land in `/opt/Cluster-Validation-Runbook/scalability/allreduce_logs` inside the pod; copy them to `/data/cluster_validation/scalability/<date>` during teardown.
- Capture STDOUT/STDERR alongside the generated Markdown tables for ingestion into the final report.

## All Pair AllReduce Validation

- Full harness documentation: [allpair/README.md](allpair/README.md).
- Entry point script `allpair/allpair.sh` orchestrates MPI jobs per round using the generated hostfile.
- Use `allpair/run_tests.sh` for a templated launch; override environment variables (e.g., `HOSTFILE`, `NPERNODE`, `LOGDIR`) as described in the README.
- Persist outputs under `/data/cluster_validation/npairs/<date>` and include NCCL debug logs in the final handoff package.

## Result Handover Expectations

- Refer to [docs/result_handover_expectations.md](docs/result_handover_expectations.md) for the exact deliverables required when transferring results to downstream teams.
- Ensure every suite provides:
  - Cluster and software inventory
  - Complete STDOUT/STDERR and NCCL logs
  - Summary tables (latency, bandwidth, scaling efficiency) ready for reporting
- Include supplementary telemetry such as `dmesg` and `nvidia-smi` captures in `/data/cluster_validation/dmesg/<date>` and `/data/cluster_validation/network/<date>` directories.




