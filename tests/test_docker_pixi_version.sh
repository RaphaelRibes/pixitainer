#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:pixi-version"

# Use host pixi version — the lockfile must be readable by the container's pixi
TARGET_VERSION=$(pixi -V | awk '{print $NF}')

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --pixi-version $TARGET_VERSION option..."
$PIXI_CMD -o "$IMAGE_TAG" --pixi-version "$TARGET_VERSION"

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying pixi version inside container..."
CONTAINER_PIXI_VERSION=$(docker run --rm "$IMAGE_TAG" pixi --version)

if ! echo "$CONTAINER_PIXI_VERSION" | grep -q "$TARGET_VERSION"; then
    echo "Error: Expected pixi $TARGET_VERSION inside container. Got: $CONTAINER_PIXI_VERSION"
    exit 1
fi

echo "Verifying Python is still available..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)
if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: Pixi version $TARGET_VERSION verified inside container."

echo "Testing --pixi-version and --latest conflict (should fail)..."
if $PIXI_CMD -o "pixitainer-test:should-fail-ver" --pixi-version "$TARGET_VERSION" --latest 2>/dev/null; then
    echo "Error: Command succeeded but --pixi-version and --latest should conflict."
    docker rmi -f "pixitainer-test:should-fail-ver" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: --pixi-version + --latest conflict correctly detected."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
