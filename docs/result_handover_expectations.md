# Result Handover Expectations

### Overview

Cluster-Validation-Runbook covers the cluster level validation tests ( application level tests only , Lab GPU team will provide hardware/k8s tests ) for GPU clusters. The three main tests included are Deep Learning Unit Test, Scalability Tests, and All-Pair Bandwidth Tests.

### General Requirements and deliverables for all Tests
- All tests executed on cluster level (all nodes involved).
- All nodes should have the same software stack and configurations.
- Complete logs for all tests executed, including STDOUT and STDERR.
- Dmesg logs and GPU utilization logs (nvidia-smi logs if needed) from all nodes during the test runs.
- Environment details:
  - Cluster configuration (number of nodes, Hardware details).
  - Software stack details (OS version, driver versions, CUDA version, NCCL version, MPI version).
  - Docker image used for the tests.
  - Any custom configurations or optimizations applied.

### 1. Deep Learning Unit Test Results
- Please provide
    - Test results summary table:

| Node ID | Test Result | Details | Affected components |
|---------|-------------|---------|---------------------|
| node-001 | Pass | All tests completed successfully | None |
| node-002 | Fail | Numerical instability detected | GPU 0, conv3d layer |
| node-003 | Pass | All tests completed successfully | None |

### 2. Scalability Test Results
- 3 Sets of tests should be included:
  1. Latency Test Results
        - Latency matrix should include SHARP vs. non-SHARP, Ring vs. Tree configurations.
        - Example latency summary table:

        | latency statistics | time taken(Ring) |  time taken(Tree) |
        |--------------|------|------|
        | SHARP Enabled | 879.82 us | 934.22 us |
        | SHARP Disabled | 867.65 us | 1078.09 us |

  2. Bandwidth Test Results
  q      - Bandwidth matrix should include SHARP vs. non-SHARP, Ring vs. Tree configurations.
        - Example bandwidth summary table:

            | bandwidth statistics | bus bandwidth (Ring) | bus bandwidth (Tree) |
            |---------------------|------|------|
            | SHARP Enabled | 350 GB/s | 350 GB/s |
            | SHARP Disabled | 350 GB/s | 350 GB/s |
  3. Scaling Test Results
        - Scaling ratio should be done in the increments of 10 nodes.
        - Example scaling ratio summary table:

            | Node Count | Bus Bandwidth | Avg Latency | Scaling Efficiency |
            |------------|---------------|-------------|-------------------|
            | 10 nodes    | 778.64 GB/s   | 292.09 us   | 100%             |
            | 20 nodes    | 667.16 GB/s   | 723.20 us   | 85.7%            |
            | 30 nodes    | 357.68 GB/s   | 977.01 us   | 46.0%            |


### 3. All-Pair Bandwidth Test Results
- Complete logs for all pairwise combinations tested ($\frac{n(n-1)}{2}$))
- Please provide the environment variables, launch commands, and any custom configurations used during the tests.
- Summary of key metrics (latency and bus bandwidth) for each pair in a tabular format:
    | Pair (Node A - Node B) | Latency (us) | Bus Bandwidth (GB/s) |
    |------------------------|--------------|----------------------|
    | node-001 - node-002    | 2.93        | 385.1                 |
    | node-001 - node-003    | 2.15        | 384.7                 |
    | node-002 - node-003    | 2.88        | 385.3                 |
 