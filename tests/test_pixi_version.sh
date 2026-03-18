#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="version_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --pixi-version option..."
# We specify a known version to check if the update command runs without failure
$PIXI_CMD -o "$IMAGE_NAME" --pixi-version "0.63.0"

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying image with specific pixi version..."
CONTAINER_PYTHON=$($CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi