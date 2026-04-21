#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:cache"

# --- Skip if buildx is unavailable (cache-from/to require BuildKit) ---
if ! docker buildx version > /dev/null 2>&1; then
    echo "SKIP: docker buildx is not available. Skipping --cache-from/--cache-to test."
    exit 0
fi

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- First build: export inline cache into the image ---
echo "Building with --cache-to type=inline (bakes cache metadata into image)..."
OUTPUT_LOG_FIRST="cache_first_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --cache-to "type=inline" \
    --no-install > "$OUTPUT_LOG_FIRST" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG_FIRST"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created with --cache-to."
    exit 1
fi

echo "Success: First build with --cache-to type=inline completed."

# Verify log line
if ! grep -q "Exporting cache-to: type=inline" "$OUTPUT_LOG_FIRST"; then
    echo "Error: 'Exporting cache-to' log line not found in first build output."
    cat "$OUTPUT_LOG_FIRST"
    exit 1
fi

echo "Success: cache-to log line verified."

# --- Second build: restore from inline cache ---
# We use --cache-from pointing at the already-built image.
# With inline cache, subsequent builds should reuse layers and be faster.
echo "Building second time with --cache-from pointing to first image..."
IMAGE_TAG2="pixitainer-test:cache-second"
docker rmi -f "$IMAGE_TAG2" > /dev/null 2>&1 || true

OUTPUT_LOG_SECOND="cache_second_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG2" \
    --cache-from "$IMAGE_TAG" \
    --no-install > "$OUTPUT_LOG_SECOND" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG_SECOND"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG2" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG2 was not created with --cache-from."
    exit 1
fi

echo "Success: Second build with --cache-from completed."

# Verify log line
if ! grep -q "Using cache-from: $IMAGE_TAG" "$OUTPUT_LOG_SECOND"; then
    echo "Error: 'Using cache-from' log line not found in second build output."
    cat "$OUTPUT_LOG_SECOND"
    exit 1
fi

echo "Success: cache-from log line verified."

# --- Combine --cache-from and --cache-to in a single build ---
echo "Testing --cache-from and --cache-to combined..."
IMAGE_TAG3="pixitainer-test:cache-combined"
docker rmi -f "$IMAGE_TAG3" > /dev/null 2>&1 || true

OUTPUT_LOG_COMBINED="cache_combined_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_TAG3" \
    --cache-from "$IMAGE_TAG" \
    --cache-to "type=inline" \
    --no-install > "$OUTPUT_LOG_COMBINED" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG_COMBINED"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG3" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG3 not created during combined cache test."
    exit 1
fi

echo "Success: --cache-from and --cache-to combined build verified."

rm -f "$OUTPUT_LOG_FIRST" "$OUTPUT_LOG_SECOND" "$OUTPUT_LOG_COMBINED"
docker rmi -f "$IMAGE_TAG" "$IMAGE_TAG2" "$IMAGE_TAG3" > /dev/null 2>&1 || true
