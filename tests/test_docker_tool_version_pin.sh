#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool-version-pin"

PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool mode version pinning (Docker)..."
$PIXI_DOCKER_TOOL tool -o "$IMAGE_TAG" 'jq=1.7.*'

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

VERSION_OUTPUT=$(docker run --rm "$IMAGE_TAG" jq --version 2>&1)
if ! echo "$VERSION_OUTPUT" | grep -q "jq-1\.7"; then
    echo "Error: Expected jq 1.7.*. Got: $VERSION_OUTPUT"
    exit 1
fi

echo "Success: Docker tool version pinning verified ($VERSION_OUTPUT)."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
