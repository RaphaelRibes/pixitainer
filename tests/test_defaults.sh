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
EXPECTED_VERSION=$(pixi -V | tail -n 1 | awk '{print $NF}')
CONTAINER_VERSION=$(pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run pixitainer.sif pixi -V | tail -n 1 | awk '{print $NF}')

if [ "$CONTAINER_VERSION" != "$EXPECTED_VERSION" ]; then
    echo "Error: Container pixi version ($CONTAINER_VERSION) does not match local version ($EXPECTED_VERSION)."
    exit 1
else
    echo "Success: Container pixi version matches local version ($EXPECTED_VERSION)."
fi