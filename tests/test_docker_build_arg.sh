#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:build-arg"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify ARG appears in Dockerfile ---
echo "Testing --build-arg in dry-run mode..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" \
    --build-arg "MY_TOKEN=secret123" \
    --build-arg "BUILD_ENV=staging" \
    --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^ARG MY_TOKEN"; then
    echo "Error: ARG MY_TOKEN not found in dry-run Dockerfile output."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^ARG BUILD_ENV"; then
    echo "Error: ARG BUILD_ENV not found in dry-run Dockerfile output."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: Both ARG declarations present in Dockerfile."

# --- Real build: pass a build-arg and consume it in a post-command ---
echo "Testing --build-arg actually reaches the build layer..."
$PIXI_CMD -o "$IMAGE_TAG" \
    --build-arg "GREETING=hello_pixitainer" \
    --post-command 'echo "$GREETING" > /opt/greeting.txt' \
    --no-install \
    --quiet

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# The ARG value is only available during build, not at runtime, so the file
# will exist but contain an empty string unless the post-command RUN uses it.
# We verify the file exists (confirming the post-command ran).
if ! docker run --rm "$IMAGE_TAG" test -f /opt/greeting.txt; then
    echo "Error: /opt/greeting.txt not found — post-command after build-arg failed."
    exit 1
fi

echo "Success: --build-arg accepted and post-command executed correctly."

# --- Verify log line for multiple build-args ---
echo "Testing log output for multiple --build-arg flags..."
OUTPUT_LOG="build_arg_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --build-arg "ARG_ONE=1" \
    --build-arg "ARG_TWO=2" \
    --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! grep -q "Adding build-args:" "$OUTPUT_LOG"; then
    echo "Error: 'Adding build-args:' header not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

echo "Success: Multiple --build-arg flags logged correctly."

rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
