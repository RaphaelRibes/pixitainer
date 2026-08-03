#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_slim_test.sif"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME"

echo "Testing tool mode image slimming..."
$PIXI_TOOL tool -o "$IMAGE_NAME" python

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

$CONTAINER_CMD run "$IMAGE_NAME" python --version | grep "Python"

# pixi binary must NOT exist
if $CONTAINER_CMD exec "$IMAGE_NAME" test -f /opt/pixi/bin/pixi 2>/dev/null; then
    echo "Error: /opt/pixi/bin/pixi should have been removed during slimming."
    exit 1
fi

echo "Success: Tool slim verified (pixi binary removed, tool binary works)."
rm -f "$IMAGE_NAME"
