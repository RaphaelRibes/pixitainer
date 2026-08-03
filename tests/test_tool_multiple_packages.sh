#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_multi_pkg_test.sif"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME"

echo "Testing tool mode with multiple packages..."
$PIXI_TOOL tool -o "$IMAGE_NAME" jq bat

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

$CONTAINER_CMD exec "$IMAGE_NAME" jq --version | grep "jq-"
$CONTAINER_CMD exec "$IMAGE_NAME" bat --version | grep "bat"

echo "Success: Tool multiple packages verified."
rm -f "$IMAGE_NAME"
