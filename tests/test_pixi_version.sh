#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="version_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --pixi-version option..."
# We specify a known version to check if the update command runs without failure
$PIXI_CMD -o version_test --pixi-version "0.63.0"

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying image with specific pixi version..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"