#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:defaults"

# Cleanup any previous run
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing default execution..."
$PIXI_CMD -o "$IMAGE_TAG"

# Verify the image exists
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# Verify Python is available in the environment
echo "Verifying Python inside container..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: Default image built and Python verified ($CONTAINER_PYTHON)."

# Cleanup
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
