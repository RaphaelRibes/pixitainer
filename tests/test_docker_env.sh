#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:env"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --env option (explicit 'default' environment)..."
$PIXI_CMD -o "$IMAGE_TAG" -e default

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying Python inside container..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: --env default image verified ($CONTAINER_PYTHON)."

echo "Testing invalid --env (should fail gracefully)..."
if $PIXI_CMD -o "pixitainer-test:should-fail-env" -e "non_existent_env_12345" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed with an invalid environment name."
    docker rmi -f "pixitainer-test:should-fail-env" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: Invalid environment correctly caused a failure."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
