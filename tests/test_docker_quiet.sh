#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:quiet"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing -q/--quiet mode (Docker)..."
OUTPUT_LOG="dquiet_stdout.log"
STDERR_LOG="dquiet_stderr.log"

set +e
$PIXI_CMD -o "$IMAGE_TAG" -q > "$OUTPUT_LOG" 2> "$STDERR_LOG"
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

# Image must exist and work
if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" pixi run --as-is python --version | grep "Python 3."

echo "Success: Quiet mode verified (Docker)."
rm -f "$OUTPUT_LOG" "$STDERR_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
