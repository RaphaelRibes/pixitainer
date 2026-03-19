#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup previous runs
rm -f pixitainer_latest.sif

echo "Testing --latest execution..."
$PIXI_CMD -o pixitainer_latest.sif --latest

if [ ! -f "pixitainer_latest.sif" ]; then
    echo "Error: Default output pixitainer_latest.sif not found."
    exit 1
fi

LATEST_CONTAINER_PYTHON=$($CONTAINER_CMD run pixitainer_latest.sif pixi run --as-is python --version)

if [[ ! "$LATEST_CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $LATEST_CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($LATEST_CONTAINER_PYTHON)."
fi
