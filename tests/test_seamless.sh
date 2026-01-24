#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="seamless_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --seamless option..."
$PIXI_CMD -o "$IMAGE_NAME" --seamless

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
# Since seamless wraps the command, this effectively runs `pixi run ... pixi -V`
echo "Verifying seamless image..."
pixi run -m ../../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"