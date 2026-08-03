#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="manual_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing -m/--manual mode (shell entrypoint)..."
OUTPUT_LOG="manual_log.txt"

# --- Dry-run: assert runscript does NOT contain pixi run ---
echo "Verifying dry-run runscript uses exec, not pixi run..."
DEF_OUTPUT=$($PIXI_CMD -o "$IMAGE_NAME" -m --dry-run 2>/dev/null)

if echo "$DEF_OUTPUT" | grep -q "pixi run --locked --as-is"; then
    echo "Error: 'pixi run --locked --as-is' found in manual mode runscript."
    echo "$DEF_OUTPUT"
    exit 1
fi

if ! echo "$DEF_OUTPUT" | grep -q 'exec "$@"'; then
    echo "Error: 'exec "$@"' not found in manual mode runscript."
    echo "$DEF_OUTPUT"
    exit 1
fi

echo "Success: Manual mode runscript is correct."

# --- Real build ---
set +e
$PIXI_CMD -o "$IMAGE_NAME" -m > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verify we can run raw shell commands inside the container
echo "Verifying shell entrypoint works..."
$CONTAINER_CMD exec "$IMAGE_NAME" echo "manual_works" | grep "manual_works"

echo "Success: Manual mode verified."
rm -f "$OUTPUT_LOG"
