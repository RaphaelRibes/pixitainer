#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:manual"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing -m/--manual mode (Docker)..."
OUTPUT_LOG="dmanual_log.txt"

# --- Dry-run: assert ENTRYPOINT does NOT contain pixi ---
echo "Verifying dry-run ENTRYPOINT uses shell, not pixi..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" -m --dry-run 2>/dev/null)

if echo "$DOCKERFILE_OUTPUT" | grep -q 'ENTRYPOINT.*pixi'; then
    echo "Error: ENTRYPOINT references pixi in manual mode."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q 'ENTRYPOINT.*bash'; then
    echo "Error: ENTRYPOINT should use bash in manual mode."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: Manual mode Dockerfile is correct."

# --- Real build ---
set +e
$PIXI_CMD -o "$IMAGE_TAG" -m > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# Verify shell entrypoint works
docker run --rm "$IMAGE_TAG" whoami | grep "root"

echo "Success: Manual mode verified (Docker)."
rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
