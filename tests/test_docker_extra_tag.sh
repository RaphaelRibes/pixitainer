#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:extra-tag-primary"
EXTRA_TAG1="pixitainer-test:extra-tag-v1"
EXTRA_TAG2="pixitainer-test:extra-tag-stable"

docker rmi -f "$IMAGE_TAG" "$EXTRA_TAG1" "$EXTRA_TAG2" > /dev/null 2>&1 || true

echo "Testing -t/--tag option with multiple extra tags..."
OUTPUT_LOG="extra_tag_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    -t "$EXTRA_TAG1" \
    --tag "$EXTRA_TAG2" \
    --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# --- Verify all three tags exist and point to the same image ---
echo "Verifying primary tag..."
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Primary image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying first extra tag..."
if ! docker image inspect "$EXTRA_TAG1" > /dev/null 2>&1; then
    echo "Error: Extra tag $EXTRA_TAG1 was not created."
    exit 1
fi

echo "Verifying second extra tag..."
if ! docker image inspect "$EXTRA_TAG2" > /dev/null 2>&1; then
    echo "Error: Extra tag $EXTRA_TAG2 was not created."
    exit 1
fi

# All three tags must resolve to the same image ID
ID_PRIMARY=$(docker inspect --format '{{.Id}}' "$IMAGE_TAG")
ID_EXTRA1=$(docker inspect --format '{{.Id}}' "$EXTRA_TAG1")
ID_EXTRA2=$(docker inspect --format '{{.Id}}' "$EXTRA_TAG2")

if [ "$ID_PRIMARY" != "$ID_EXTRA1" ]; then
    echo "Error: $EXTRA_TAG1 points to a different image than $IMAGE_TAG."
    echo "  Primary: $ID_PRIMARY"
    echo "  Extra 1: $ID_EXTRA1"
    exit 1
fi

if [ "$ID_PRIMARY" != "$ID_EXTRA2" ]; then
    echo "Error: $EXTRA_TAG2 points to a different image than $IMAGE_TAG."
    echo "  Primary: $ID_PRIMARY"
    echo "  Extra 2: $ID_EXTRA2"
    exit 1
fi

echo "Success: All three tags reference the same image ($ID_PRIMARY)."

# --- Verify log mentions each extra tag ---
if ! grep -q "Adding extra tag: $EXTRA_TAG1" "$OUTPUT_LOG"; then
    echo "Error: Log does not mention extra tag $EXTRA_TAG1."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! grep -q "Adding extra tag: $EXTRA_TAG2" "$OUTPUT_LOG"; then
    echo "Error: Log does not mention extra tag $EXTRA_TAG2."
    cat "$OUTPUT_LOG"
    exit 1
fi

echo "Success: Extra tag log lines verified."

rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" "$EXTRA_TAG1" "$EXTRA_TAG2" > /dev/null 2>&1 || true
