#!/usr/bin/env bash
set -euo pipefail

# Ensure sudo exists before using it for the remaining installs
if ! command -v sudo >/dev/null 2>&1; then
	apt-get update
	apt-get install -y sudo
fi


# Install dependencies
sudo apt-get update
sudo apt-get install -y iputils-ping





# paths 
export log_dir="/data/logs"

# export variables
export logstatus=1
