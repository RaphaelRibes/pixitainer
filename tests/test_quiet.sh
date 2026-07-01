#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="quiet_test.sif"

rm -f "$IMAGE_NAME"

echo "Testing -q/--quiet mode..."
OUTPUT_LOG="quiet_log.txt"
STDERR_LOG="quiet_err.log"

set +e
$PIXI_CMD -o "$IMAGE_NAME" -q > "$OUTPUT_LOG" 2> "$STDERR_LOG"
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: Quiet build exited with $EXIT_CODE."
    cat "$OUTPUT_LOG"
    cat "$STDERR_LOG"
    exit $EXIT_CODE
fi

# stdout must be empty
if [ -s "$OUTPUT_LOG" ]; then
    echo "Error: Quiet mode produced stdout output."
    cat "$OUTPUT_LOG"
    exit 1
fi

# Image must still exist and be runnable
if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

$CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version | grep "Python 3."

echo "Success: Quiet mode verified (no stdout, image built, python works)."
rm -f "$OUTPUT_LOG" "$STDERR_LOG"
