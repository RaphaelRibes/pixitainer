#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool-slim"

PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool mode image slimming (Docker)..."
$PIXI_DOCKER_TOOL tool -o "$IMAGE_TAG" python

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" python --version | grep "Python"

# pixi binary must NOT exist in the image
if docker run --rm "$IMAGE_TAG" test -f /opt/pixi/bin/pixi 2>/dev/null; then
    echo "Error: /opt/pixi/bin/pixi should have been removed during slimming."
    exit 1
fi

echo "Success: Docker tool slim verified (pixi binary removed, tool binary works)."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
