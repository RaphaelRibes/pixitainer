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
CONTAINER_PYTHON=$($CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi
echo "Testing invalid base-image option (should fail)..."
if $PIXI_CMD -o "should_fail.sif" --base-image "this_image_does_not_exist:really" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed with invalid base image."
    exit 1
else
    echo "Success: Command failed as expected for invalid base image."
fi