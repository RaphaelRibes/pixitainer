#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool-multi"

PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool mode with multiple packages (Docker)..."
$PIXI_DOCKER_TOOL tool -o "$IMAGE_TAG" jq bat

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" jq --version | grep "jq-"
docker run --rm "$IMAGE_TAG" bat --version | grep "bat"

echo "Success: Docker tool multiple packages verified."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
