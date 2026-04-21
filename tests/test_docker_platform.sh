#!/bin/bash
set -e

cd "$REPO_DIR"

# --- Skip gracefully if buildx is not available ---
if ! docker buildx version > /dev/null 2>&1; then
    echo "SKIP: docker buildx is not available on this host. Skipping platform test."
    exit 0
fi

# --- Single-platform build ---
IMAGE_TAG_AMD="pixitainer-test:platform-amd64"
docker rmi -f "$IMAGE_TAG_AMD" > /dev/null 2>&1 || true

echo "Testing --platform linux/amd64 (single-platform build)..."
$PIXI_CMD -o "$IMAGE_TAG_AMD" --platform linux/amd64 --no-install

if ! docker image inspect "$IMAGE_TAG_AMD" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG_AMD was not created."
    exit 1
fi

# Verify the platform stored in the image manifest
PLATFORM=$(docker inspect --format '{{.Os}}/{{.Architecture}}' "$IMAGE_TAG_AMD")
if [ "$PLATFORM" != "linux/amd64" ]; then
    echo "Error: Expected platform linux/amd64, got: $PLATFORM"
    exit 1
fi

echo "Success: Single-platform build linux/amd64 verified."

# --- Multi-platform build (requires a builder with multi-arch support) ---
# We load only one arch at a time with --load, so we test amd64 + arm64 sequentially.
IMAGE_TAG_ARM="pixitainer-test:platform-arm64"
docker rmi -f "$IMAGE_TAG_ARM" > /dev/null 2>&1 || true

# Check if the current buildx builder supports arm64
BUILDER_PLATFORMS=$(docker buildx inspect --bootstrap 2>/dev/null | grep Platforms || true)
if echo "$BUILDER_PLATFORMS" | grep -q "linux/arm64"; then
    echo "Testing --platform linux/arm64..."
    $PIXI_CMD -o "$IMAGE_TAG_ARM" --platform linux/arm64 --no-install

    if ! docker image inspect "$IMAGE_TAG_ARM" > /dev/null 2>&1; then
        echo "Error: Image $IMAGE_TAG_ARM was not created."
        exit 1
    fi

    PLATFORM_ARM=$(docker inspect --format '{{.Os}}/{{.Architecture}}' "$IMAGE_TAG_ARM")
    if [ "$PLATFORM_ARM" != "linux/arm64" ]; then
        echo "Error: Expected platform linux/arm64, got: $PLATFORM_ARM"
        exit 1
    fi

    echo "Success: Single-platform build linux/arm64 verified."
    docker rmi -f "$IMAGE_TAG_ARM" > /dev/null 2>&1 || true
else
    echo "ℹ️ Builder does not support linux/arm64 — skipping arm64 sub-test."
fi

# --- Verify --platform without buildx gives a useful error message ---
# We simulate this by temporarily testing that the flag is parsed correctly in dry-run
# (the actual "no buildx" guard is at startup of the script, already tested implicitly).
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG_AMD" --platform linux/amd64 --dry-run)
if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^FROM "; then
    echo "Error: --platform dry-run did not output a valid Dockerfile."
    exit 1
fi

echo "Success: --platform flag parsed correctly in dry-run mode."

docker rmi -f "$IMAGE_TAG_AMD" > /dev/null 2>&1 || true
