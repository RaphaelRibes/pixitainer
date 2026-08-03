#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="tool_cache_jq.sif"
IMAGE_NAME2="tool_cache_python.sif"
CACHE_DIR="$REPO_DIR/.tool_cache"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

rm -f "$IMAGE_NAME" "$IMAGE_NAME2"
rm -rf "$CACHE_DIR"

echo "Testing tool mode shared package cache..."

$PIXI_TOOL tool --cache-dir "$CACHE_DIR" -o "$IMAGE_NAME" jq
if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Host cache must have been populated
if [ ! -d "$CACHE_DIR/rattler" ] && [ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]; then
    echo "Error: package cache dir $CACHE_DIR was not populated."
    exit 1
fi

# Second build, same cache: must succeed
$PIXI_TOOL tool --cache-dir "$CACHE_DIR" -o "$IMAGE_NAME2" python
if [ ! -f "$IMAGE_NAME2" ]; then
    echo "Error: $IMAGE_NAME2 not found."
    exit 1
fi

# Both images still run their tools
$CONTAINER_CMD run "$IMAGE_NAME" jq --version | grep "jq-"
$CONTAINER_CMD run "$IMAGE_NAME2" python --version | grep "Python"

# Slim still applies: pixi binary must NOT exist in the image
if $CONTAINER_CMD exec "$IMAGE_NAME" test -f /opt/pixi/bin/pixi 2>/dev/null; then
    echo "Error: /opt/pixi/bin/pixi should have been removed during slimming."
    exit 1
fi

echo "Success: shared tool cache verified."
rm -f "$IMAGE_NAME" "$IMAGE_NAME2"
