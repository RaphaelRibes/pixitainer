#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:secret"
SECRET_FILE="$(pwd)/test_secret.txt"

# --- Skip if buildx is unavailable ---
if ! docker buildx version > /dev/null 2>&1; then
    echo "SKIP: docker buildx is not available. Skipping --secret test."
    exit 0
fi

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -f "$SECRET_FILE"

# --- Create a fake secret file ---
echo "super_secret_token_12345" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"

# --- Dry-run: secret value must not appear in the Dockerfile ---
echo "Testing --secret does not appear in Dockerfile (dry-run)..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" \
    --secret "id=my_token,src=$SECRET_FILE" \
    --dry-run)

if echo "$DOCKERFILE_OUTPUT" | grep -qi "super_secret_token"; then
    echo "Error: Secret value leaked into the Dockerfile!"
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: Secret value is absent from Dockerfile."

# --- Real build: verify the build completes successfully with --secret ---
# We do NOT attempt to read the secret inside a RUN command — BuildKit secrets
# are only accessible via RUN --mount=type=secret, which requires a custom
# Dockerfile that pixitainer does not generate. We just confirm the flag is
# accepted and the image is produced without error.
echo "Building with --secret (verifying flag is accepted by buildx)..."
BUILD_LOG="secret_build.log"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --secret "id=my_token,src=$SECRET_FILE" \
    --no-install > "$BUILD_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: Build with --secret failed."
    cat "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    cat "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit 1
fi

echo "Success: Build with --secret completed."

# --- Critical security check: secret value must NOT be baked into the image ---
echo "Verifying secret value is NOT baked into the image..."
if docker run --rm "$IMAGE_TAG" grep -r "super_secret_token_12345" / 2>/dev/null | grep -v "^Binary"; then
    echo "Error: Secret value found inside the container filesystem!"
    rm -f "$BUILD_LOG"
    exit 1
fi

echo "Success: Secret value absent from container filesystem."

# --- Verify log line ---
if ! grep -q "Mounting secret:" "$BUILD_LOG"; then
    echo "Error: 'Mounting secret:' log line not found."
    cat "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit 1
fi

echo "Success: Secret log line verified."

rm -f "$SECRET_FILE" "$BUILD_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true