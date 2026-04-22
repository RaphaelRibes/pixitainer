#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:no-cache"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --no-cache option..."

# First build to populate the cache
$PIXI_CMD -o "$IMAGE_TAG" --quiet

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# Second build with --no-cache: capture output and look for Docker's cache-bypass indicator
OUTPUT_LOG="no_cache_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_TAG" --no-cache --verbose > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created with --no-cache."
    exit 1
fi

# Docker prints "Step N/M" lines even with --no-cache; but it should NOT say
# "Using cache" for any layer when --no-cache is active.
if grep -q "Using cache" "$OUTPUT_LOG"; then
    echo "Error: Docker used cached layers despite --no-cache flag."
    cat "$OUTPUT_LOG"
    exit 1
fi

echo "Verifying Python inside container..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)
if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: --no-cache build verified (no cached layers used)."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
