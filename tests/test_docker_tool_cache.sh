#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="pixitainer-test:tool-cache"

PIXI_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

if ! docker buildx version > /dev/null 2>&1; then
    echo "Skipping: BuildKit cache mount for Docker requires docker buildx (BuildKit)."
    exit 0
fi

echo "Testing tool mode Docker automatic BuildKit cache mount..."

# Dry-run must emit the BuildKit cache mount on the install RUN, with NO flag
$PIXI_TOOL tool -o "$IMAGE_NAME" jq -d \
    | grep -- "--mount=type=cache,target=/root/.cache"

# --cache-dir is ignored (warned) but must not fail the build
$PIXI_TOOL tool --cache-dir /tmp/ignored_cache_dir -o "$IMAGE_NAME" jq \
    | grep "ignored by the Docker backend"

$PIXI_TOOL tool --cache-dir /tmp/ignored_cache_dir -o "$IMAGE_NAME" jq

if [ -z "$(docker images -q "$IMAGE_NAME")" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi
docker run --rm "$IMAGE_NAME" jq --version | grep "jq-"

echo "Success: Docker automatic BuildKit cache verified."
docker rmi -f "$IMAGE_NAME" > /dev/null 2>&1 || true
