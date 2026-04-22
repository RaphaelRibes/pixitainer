#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:base-image"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --base-image option with ubuntu:22.04..."
$PIXI_CMD -o "$IMAGE_TAG" --base-image "ubuntu:22.04"

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# Verify the base OS version inside the container
echo "Verifying base OS is Ubuntu 22.04..."
OS_RELEASE=$(docker run --rm "$IMAGE_TAG" cat /etc/os-release)

if ! echo "$OS_RELEASE" | grep -q "22.04"; then
    echo "Error: Base image is not Ubuntu 22.04. /etc/os-release content:"
    echo "$OS_RELEASE"
    exit 1
fi

echo "Verifying Python is still available..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)
if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: Custom base image ubuntu:22.04 verified."

echo "Testing invalid --base-image (should fail)..."
if $PIXI_CMD -o "pixitainer-test:should-fail-base" --base-image "this_image_does_not_exist:really" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed with an invalid base image."
    docker rmi -f "pixitainer-test:should-fail-base" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: Invalid base image correctly caused a failure."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
