#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_version_pin_test.sif"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME"

echo "Testing tool mode version pinning (MatchSpec)..."
$PIXI_TOOL tool -o "$IMAGE_NAME" 'jq=1.7.*'

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

VERSION_OUTPUT=$($CONTAINER_CMD run "$IMAGE_NAME" jq --version 2>&1)
if ! echo "$VERSION_OUTPUT" | grep -q "jq-1\.7"; then
    echo "Error: Expected jq 1.7.*. Got: $VERSION_OUTPUT"
    exit 1
fi

echo "Success: Tool version pinning verified ($VERSION_OUTPUT)."
rm -f "$IMAGE_NAME"
