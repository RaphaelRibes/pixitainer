#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:dry-run"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --dry-run option..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --dry-run)

# The image should NOT have been built
if docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image was built despite --dry-run flag."
    docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: Image was NOT built (as expected)."

# Verify Dockerfile instructions are present in stdout
if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^FROM "; then
    echo "Error: FROM instruction not found in dry-run output."
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^RUN "; then
    echo "Error: RUN instruction not found in dry-run output."
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^ENTRYPOINT"; then
    echo "Error: ENTRYPOINT instruction not found in dry-run output."
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^COPY "; then
    echo "Error: COPY instruction not found in dry-run output."
    exit 1
fi

# bootstrap.sh must be staged into the build context and COPYed in
if ! echo "$DOCKERFILE_OUTPUT" | grep -q "bootstrap.sh"; then
    echo "Error: bootstrap.sh not found in Dockerfile COPY section."
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "pixi"; then
    echo "Error: pixi install command not found in dry-run output."
    exit 1
fi

echo "Success: Dockerfile content correctly output to stdout."

# The temp directory should have been cleaned up
if [ -d ".tmp_pixitainer_docker" ]; then
    echo "Error: Temporary directory was not cleaned up after --dry-run."
    exit 1
fi

echo "Success: Temporary directory was cleaned up."
