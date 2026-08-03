#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="pixi_version_inside_test.sif"

rm -f "$IMAGE_NAME"

# Use host pixi version to avoid lockfile format mismatch
HOST_PIXI_VERSION=$(pixi -V | awk '{print $NF}')
echo "Testing --pixi-version $HOST_PIXI_VERSION (verifying version inside SIF)..."

$PIXI_CMD -o "$IMAGE_NAME" --pixi-version "$HOST_PIXI_VERSION"

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

echo "Verifying pixi version inside the container..."
CONTAINER_PIXI_VERSION=$($CONTAINER_CMD run "$IMAGE_NAME" pixi --version 2>&1)

if ! echo "$CONTAINER_PIXI_VERSION" | grep -q "$HOST_PIXI_VERSION"; then
    echo "Error: Expected pixi $HOST_PIXI_VERSION inside container."
    echo "Got: $CONTAINER_PIXI_VERSION"
    exit 1
fi

# Python should still work
$CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version | grep "Python 3."

echo "Success: Pixi version $HOST_PIXI_VERSION verified inside container."
rm -f "$IMAGE_NAME"
