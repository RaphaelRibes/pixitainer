#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="env_test.sif"

rm -f "$IMAGE_NAME"

# RaMiLass has a 'default' environment. We test explicitly selecting it.
echo "Testing --env option..."
$PIXI_CMD -o env_test -e default

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying env image..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"