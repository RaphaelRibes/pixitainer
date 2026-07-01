#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool"

# Tool-mode tests must pass 'tool' as the first positional argument.
PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool mode with jq package..."
$PIXI_DOCKER_TOOL tool -o "$IMAGE_TAG" jq

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Running jq --version inside container..."
docker run --rm "$IMAGE_TAG" jq --version | grep "jq-"

echo "Success: Docker tool mode with jq verified."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
