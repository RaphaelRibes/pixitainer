#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_jq.sif"

# Tool-mode tests must pass 'tool' as the first positional argument.
# The default PIXI_CMD has -p baked in (for project mode), so we drop it here.
PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME"

echo "Testing tool mode with jq package..."
$PIXI_TOOL tool -o "$IMAGE_NAME" jq

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

echo "Verifying jq inside container..."
$CONTAINER_CMD run "$IMAGE_NAME" jq --version | grep "jq-"

echo "Success: Tool mode with jq verified."
