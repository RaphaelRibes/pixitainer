#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing --pixi-version + --latest conflict (Docker)..."
HOST_VER=$(pixi -V | awk '{print $NF}')
if $PIXI_CMD -o "pixitainer-test:should-fail-conflict" --pixi-version "$HOST_VER" --latest 2>/dev/null; then
    echo "Error: --pixi-version and --latest together should have failed."
    docker rmi -f "pixitainer-test:should-fail-conflict" > /dev/null 2>&1 || true
    exit 1
fi

# Assert no image was created
if docker image inspect "pixitainer-test:should-fail-conflict" > /dev/null 2>&1; then
    echo "Error: Image was created despite conflicting flags."
    docker rmi -f "pixitainer-test:should-fail-conflict" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: --pixi-version + --latest conflict correctly detected (Docker)."
