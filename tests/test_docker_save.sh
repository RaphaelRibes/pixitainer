#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:save"
EXTRA_TAG="pixitainer-test:save-v1"
ARCHIVE="pixitainer_test_save.tar.gz"
LOADED_TAG="pixitainer-test:save-loaded"

docker rmi -f "$IMAGE_TAG" "$EXTRA_TAG" "$LOADED_TAG" > /dev/null 2>&1 || true
rm -f "$ARCHIVE"

echo "Testing --save option (export to .tar.gz archive)..."
OUTPUT_LOG="save_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    -t "$EXTRA_TAG" \
    --save "$ARCHIVE" \
    --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# --- Verify archive was created and is non-empty ---
if [ ! -f "$ARCHIVE" ]; then
    echo "Error: Archive $ARCHIVE was not created."
    exit 1
fi

ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE" 2>/dev/null || stat -f%z "$ARCHIVE")
if [ "$ARCHIVE_SIZE" -lt 1024 ]; then
    echo "Error: Archive $ARCHIVE is suspiciously small (${ARCHIVE_SIZE} bytes)."
    exit 1
fi

echo "Archive created: $ARCHIVE (${ARCHIVE_SIZE} bytes)"

# --- Verify archive is a valid gzip file ---
if ! file "$ARCHIVE" | grep -qi "gzip"; then
    echo "Error: $ARCHIVE does not appear to be a valid gzip file."
    file "$ARCHIVE"
    exit 1
fi

echo "Archive is a valid gzip file."

# --- Verify the archive contains the image manifest ---
if ! tar -tzf "$ARCHIVE" | grep -q "manifest.json"; then
    echo "Error: manifest.json not found inside archive — archive may be corrupt."
    exit 1
fi

echo "manifest.json found inside archive."

# --- Round-trip: remove the image, load from archive, verify it works ---
echo "Removing original image to test round-trip load..."
docker rmi -f "$IMAGE_TAG" "$EXTRA_TAG" > /dev/null 2>&1 || true

echo "Loading image from archive..."
docker load < "$ARCHIVE" > /dev/null 2>&1

# After load, the image should be back under its original tags
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG not found after docker load."
    docker images | grep pixitainer-test || true
    exit 1
fi

if ! docker image inspect "$EXTRA_TAG" > /dev/null 2>&1; then
    echo "Error: Extra tag $EXTRA_TAG not found after docker load (archive should include all tags)."
    exit 1
fi

echo "Success: Image and extra tag both restored from archive."

# --- Verify log line ---
if ! grep -q "Saving image to archive" "$OUTPUT_LOG"; then
    echo "Error: 'Saving image to archive' not found in log output."
    cat "$OUTPUT_LOG"
    exit 1
fi

echo "Success: --save option fully verified (create, validate, round-trip)."

rm -f "$ARCHIVE" "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" "$EXTRA_TAG" > /dev/null 2>&1 || true
