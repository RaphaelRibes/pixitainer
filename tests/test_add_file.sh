#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="add_file_test.sif"
EXTRA_FILE1="extra1.txt"
EXTRA_FILE2="extra2.txt"
echo "Hello World 1" > "$EXTRA_FILE1"
echo "Hello World 2" > "$EXTRA_FILE2"

echo "Testing --add-file option with multiple files..."
OUTPUT_LOG="add_file_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_NAME" \
    --add-file "$EXTRA_FILE1:/opt/extra1.txt" \
    --add-file "$EXTRA_FILE2:/opt/extra2.txt" > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# Check for log output (bulleted format)
if ! grep -q "ℹ️  Adding files:" "$OUTPUT_LOG"; then
    echo "Error: 'Adding files:' header not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! grep -q "      - $EXTRA_FILE1 -> /opt/extra1.txt" "$OUTPUT_LOG"; then
    echo "Error: Bullet for $EXTRA_FILE1 not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! grep -q "      - $EXTRA_FILE2 -> /opt/extra2.txt" "$OUTPUT_LOG"; then
    echo "Error: Bullet for $EXTRA_FILE2 not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification inside container
echo "Verifying files inside container..."
CONTENT1=$($CONTAINER_CMD exec "$IMAGE_NAME" cat /opt/extra1.txt)
CONTENT2=$($CONTAINER_CMD exec "$IMAGE_NAME" cat /opt/extra2.txt)

if [ "$CONTENT1" != "Hello World 1" ]; then
    echo "Error: File 1 content mismatch. Expected 'Hello World 1', got '$CONTENT1'"
    exit 1
fi

if [ "$CONTENT2" != "Hello World 2" ]; then
    echo "Error: File 2 content mismatch. Expected 'Hello World 2', got '$CONTENT2'"
    exit 1
fi

echo "Success: Multiple files added and verified with correct logging."
