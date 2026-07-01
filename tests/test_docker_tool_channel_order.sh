#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:tool-channel-order"

PIXI_DOCKER_TOOL="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing tool channel order (conda-forge auto-appended, Docker)..."
OUTPUT_LOG="channel_order_log.txt"

set +e
$PIXI_DOCKER_TOOL tool -o "$IMAGE_TAG" -c bioconda jq > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! grep -q "Auto-added" "$OUTPUT_LOG"; then
    echo "Error: 'Auto-added' message not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

docker run --rm "$IMAGE_TAG" jq --version | grep "jq-"

echo "Success: Tool channel order with conda-forge auto-append verified (Docker)."
rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
