#!/usr/bin/env bash

# Use "$@" to capture the command AND its arguments (e.g., "bash" AND "/opt/run.sh")
# mpirun \
#     --allow-run-as-root \
#     --hostfile /opt/hostfile \
#     --bind-to none \
#     -mca plm_rsh_args "-p 22" \
#     -np $(wc -l < /opt/hostfile) \
#     "$@"

mpirun \
    --allow-run-as-root \
    --hostfile /opt/hostfile_setup \
    --bind-to none \
    --map-by ppr:1:node \
    bash -c "$@""