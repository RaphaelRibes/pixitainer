#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:missing-lock"
LOCK_BACKUP="pixi.lock.bak"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing Docker build without pixi.lock..."
if [ -f "pixi.lock" ]; then
    mv pixi.lock "$LOCK_BACKUP"
fi

$PIXI_CMD -o "$IMAGE_TAG" --no-install

if [ -f "$LOCK_BACKUP" ]; then
    mv "$LOCK_BACKUP" pixi.lock
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" pixi run --as-is python --version | grep "Python 3."

echo "Success: Missing pixi.lock handled gracefully (Docker)."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
