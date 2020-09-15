#!/bin/bash
set -euo pipefail

CACHE_DIR=/nvidia-device-plugin

# Figure out which scripts should run
scripts=()
scripts+=("$CACHE_DIR/01-nvidia-driver.sh")
scripts+=("$CACHE_DIR/02-nvidia-docker.sh")

# Run the scripts
for script in "${scripts[@]}"; do
    echo "########## Starting $script ##########"
    $script 2>&1 | tee -a $CACHE_DIR/install.log
    echo "########## Finished $script ##########"
done
