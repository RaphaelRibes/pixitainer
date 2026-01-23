#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="verbose_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --verbose option..."
# We run it and rely on the script exit code
$PIXI_CMD -o verbose_test --verbose

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying verbose build image..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"