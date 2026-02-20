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

echo "Verifying latest image pixi version..."
LATEST_CONTAINER_VERSION=$(pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run pixitainer_latest.sif pixi -V | tail -n 1 | awk '{print $NF}')
LATEST_KNOWN_VERSION=$(curl -s https://api.github.com/repos/prefix-dev/pixi/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')

if [ "$LATEST_CONTAINER_VERSION" != "$LATEST_KNOWN_VERSION" ]; then
    echo "Error: Container pixi version ($LATEST_CONTAINER_VERSION) does not match latest version ($LATEST_KNOWN_VERSION)."
    exit 1
else
    echo "Success: Container pixi version matches latest version ($LATEST_KNOWN_VERSION)."
fi
