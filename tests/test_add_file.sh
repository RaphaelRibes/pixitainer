#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="add_file_test.sif"
EXTRA_FILE="extra.txt"
echo "Hello World" > "$EXTRA_FILE"

echo "Testing --add-file option..."
OUTPUT_LOG="add_file_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_NAME" --add-file "$EXTRA_FILE:/opt/extra.txt" > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# Check for log output
if ! grep -q "Adding file: $EXTRA_FILE -> /opt/extra.txt" "$OUTPUT_LOG"; then
    echo "Error: 'Adding file' log not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification inside container
echo "Verifying file inside container..."
CONTENT=$(pixi run -m ../../../pixi.toml apptainer exec "$IMAGE_NAME" cat /opt/extra.txt)

if [ "$CONTENT" != "Hello World" ]; then
    echo "Error: File content mismatch. Expected 'Hello World', got '$CONTENT'"
    exit 1
fi

echo "Success: File added and verified."
