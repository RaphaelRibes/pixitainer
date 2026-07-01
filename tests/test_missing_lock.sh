#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="missing_lock_test.sif"
LOCK_BACKUP="pixi.lock.bak"

rm -f "$IMAGE_NAME"

echo "Testing build without pixi.lock..."
if [ -f "pixi.lock" ]; then
    mv pixi.lock "$LOCK_BACKUP"
fi

# Build without a pixi.lock file — should still work (just won't have frozen deps)
$PIXI_CMD -o "$IMAGE_NAME" --no-install

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Container should exist even without env installed
$CONTAINER_CMD inspect "$IMAGE_NAME" | grep -q "Pixitainer"

# Restore lock if it was moved
if [ -f "$LOCK_BACKUP" ]; then
    mv "$LOCK_BACKUP" pixi.lock
fi

echo "Success: Missing pixi.lock handled gracefully."
rm -f "$IMAGE_NAME"
