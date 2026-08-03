#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="seamless_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing --seamless option (deprecated alias)..."
OUTPUT_LOG="seamless_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_NAME" --seamless > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# In v0.8.0, --seamless is deprecated and prints a warning
if ! grep -q "seamless.*deprecated" "$OUTPUT_LOG"; then
    echo "Error: 'seamless is deprecated' warning not found in output."
    cat "$OUTPUT_LOG"
    exit 1
fi

# Verify the runscript uses --locked (consistent with Docker seamless entrypoint)
echo "Verifying --locked is present in seamless runscript..."
DEF_OUTPUT=$($PIXI_CMD -o "$IMAGE_NAME" --seamless --dry-run 2>/dev/null)
if [[ ! "$DEF_OUTPUT" =~ "pixi run --locked --as-is" ]]; then
    echo "Error: '--locked' not found in seamless runscript. Got: $DEF_OUTPUT"
    exit 1
fi
echo "Success: '--locked' correctly present in seamless runscript."

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

echo "Verifying seamless image..."
CONTAINER_PYTHON=$($CONTAINER_CMD run "$IMAGE_NAME" python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi
