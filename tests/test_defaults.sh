#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup previous runs
rm -f pixitainer.sif

echo "Testing default execution..."
$PIXI_CMD

if [ ! -f "pixitainer.sif" ]; then
    echo "Error: Default output pixitainer.sif not found."
    exit 1
fi

# Verification
echo "Verifying image..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run pixitainer.sif pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"