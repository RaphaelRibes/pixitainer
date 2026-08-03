#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool-manual"

PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool mode with -m/--manual (Docker)..."
$PIXI_DOCKER_TOOL tool -m -o "$IMAGE_TAG" jq

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" jq --version | grep "jq-"

echo "Success: Docker tool manual mode verified."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
