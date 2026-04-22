#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:seamless"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --seamless option..."
OUTPUT_LOG="seamless_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" --seamless > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! grep -q "Seamless mode enabled" "$OUTPUT_LOG"; then
    echo "Error: 'Seamless mode enabled' not found in output."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# In seamless mode the ENTRYPOINT wraps pixi run, so python is directly accessible
echo "Verifying seamless image: python should be callable without pixi run..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Seamless python --version failed. Got: $CONTAINER_PYTHON"
    exit 1
fi

# Verify the ENTRYPOINT in image metadata references pixi and includes --locked
ENTRYPOINT=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE_TAG")
if ! echo "$ENTRYPOINT" | grep -q "pixi"; then
    echo "Error: ENTRYPOINT does not reference pixi. Got: $ENTRYPOINT"
    exit 1
fi

if ! echo "$ENTRYPOINT" | grep -q "\-\-locked"; then
    echo "Error: ENTRYPOINT is missing '--locked'. Got: $ENTRYPOINT"
    exit 1
fi

echo "Success: Seamless mode verified (Python=$CONTAINER_PYTHON, Entrypoint=$ENTRYPOINT)."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
