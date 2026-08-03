#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_manual_test.sif"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME"

echo "Testing tool mode with -m/--manual..."
$PIXI_TOOL tool -m -o "$IMAGE_NAME" jq

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# In manual mode, the entrypoint is a shell, not jq directly.
$CONTAINER_CMD exec "$IMAGE_NAME" jq --version | grep "jq-"

echo "Success: Tool mode manual verified."
rm -f "$IMAGE_NAME"
