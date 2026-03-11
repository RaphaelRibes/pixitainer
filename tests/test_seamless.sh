#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="seamless_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --seamless option..."
OUTPUT_LOG="seamless_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_NAME" --seamless > "$OUTPUT_LOG" 2>&1
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

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

echo "Verifying seamless image..."
CONTAINER_PYTHON=$(pixi run -m ../../../pixi.toml apptainer run "$IMAGE_NAME" python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi