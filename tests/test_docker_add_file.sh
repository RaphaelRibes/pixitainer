#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:add-file"
EXTRA_FILE1="extra1.txt"
EXTRA_FILE2="extra2.txt"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Hello World 1" > "$EXTRA_FILE1"
echo "Hello World 2" > "$EXTRA_FILE2"

echo "Testing --add-file option with multiple files..."
OUTPUT_LOG="add_file_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --add-file "$EXTRA_FILE1:/opt/extra1.txt" \
    --add-file "$EXTRA_FILE2:/opt/extra2.txt" > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# Verify the bulleted log output
if ! grep -q "ℹ️ Staging extra files:" "$OUTPUT_LOG"; then
    echo "Error: 'Staging extra files:' header not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! grep -q "      - $EXTRA_FILE1 -> /opt/extra1.txt" "$OUTPUT_LOG"; then
    echo "Error: Bullet for $EXTRA_FILE1 not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! grep -q "      - $EXTRA_FILE2 -> /opt/extra2.txt" "$OUTPUT_LOG"; then
    echo "Error: Bullet for $EXTRA_FILE2 not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying file contents inside container..."
CONTENT1=$(docker run --rm "$IMAGE_TAG" cat /opt/extra1.txt)
CONTENT2=$(docker run --rm "$IMAGE_TAG" cat /opt/extra2.txt)

if [ "$CONTENT1" != "Hello World 1" ]; then
    echo "Error: File 1 content mismatch. Expected 'Hello World 1', got '$CONTENT1'."
    exit 1
fi

if [ "$CONTENT2" != "Hello World 2" ]; then
    echo "Error: File 2 content mismatch. Expected 'Hello World 2', got '$CONTENT2'."
    exit 1
fi

echo "Testing --add-file with a missing source (should fail)..."
if $PIXI_CMD -o "pixitainer-test:should-fail-add" \
    --add-file "this_file_does_not_exist.txt:/opt/nope.txt" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed for a missing source file."
    docker rmi -f "pixitainer-test:should-fail-add" > /dev/null 2>&1 || true
    exit 1
fi

echo "Success: Multiple files added and verified with correct logging."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
