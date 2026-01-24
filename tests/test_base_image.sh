#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="base_test.sif"

rm -f "$IMAGE_NAME"

# Using a specific tag to ensure the argument is accepted
echo "Testing --base-image option..."
$PIXI_CMD -o "$IMAGE_NAME" --base-image "ubuntu:22.04"

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying base image build..."
pixi run -m ../../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"