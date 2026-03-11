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
echo "Verifying default image pixi version..."
CONTAINER_PYTHON=$(pixi run -m ../../../pixi.toml apptainer run pixitainer.sif pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi