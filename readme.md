There are 3 set of tests in the Cluster Validation Runbook: Deep Learning Unit Test, Scalability Tests, and All-Pair Bandwidth Tests. Below are the quick guides for each.

### Table of Contents
- [Deep Learning Unit Test](#deep-learning-unit-test)
- [Scalability Tests](#scalability-tests)
- [All Pair AllReduce Validation](#all-pair-allreduce-validation)
- [Result Handover Expectations](#result-handover-expectations)

## Overview
Cluster-Validation-Runbook covers the cluster level validation tests ( application level tests only , Lab GPU team will provide hardware/k8s tests ) for GPU clusters. The three main tests included are

## Deep Learning Unit Test 
See [Deep Learning Unit Test – Quick Steps](docs/Deep_Learning_Unit_Test.md)
The Deep Learning Unit Test codebase is proprietary and not included in this repository. We will share the ready-to-run codebase separately as zipped file.

## Scalability Tests
See [Scalability Tests – Quick Guide](scalability/README.md)
This set of tests runs three GPU AllReduce benchmarks (latency, bandwidth, and scaling) across multiple nodes with varible settings (SHARP vs. non-SHARP, Ring vs. Tree). All tests will produce summary tables with key metrics for easy comparison.

## All Pair AllReduce Validation
See [All Pair AllReduce Validation](allpair/README.md)
This test harness runs NCCL-based AllReduce benchmarks across every pair of nodes in the cluster, generating a round-robin schedule to avoid node reuse conflicts. Each pair's performance logs are saved for later analysis.




