#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="multiple_envs_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing multiple -e environments..."
$PIXI_CMD -o "$IMAGE_NAME" -e default -e default

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verify python still works (default env has python)
$CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version | grep "Python 3."

echo "Success: Multiple -e environments handled correctly."
rm -f "$IMAGE_NAME"
