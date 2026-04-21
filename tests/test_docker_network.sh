#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:network"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify --network flag is accepted and Dockerfile is unaffected ---
echo "Testing --network does not corrupt the Dockerfile..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --network host --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^FROM "; then
    echo "Error: FROM instruction missing in dry-run output with --network host."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: Dockerfile is valid with --network host."

# --- Detect whether the daemon uses BuildKit by default ---
# BuildKit (buildx) only supports --network host and --network none.
# --network bridge is a classic builder feature and is rejected by buildx.
BUILDKIT_DEFAULT=false
if docker buildx version > /dev/null 2>&1; then
    # If DOCKER_BUILDKIT=0 is not set and buildx is available, BuildKit is the default
    if [ "${DOCKER_BUILDKIT:-1}" != "0" ]; then
        BUILDKIT_DEFAULT=true
    fi
fi

# --- Build with --network host (supported by both classic and BuildKit) ---
echo "Testing --network host build..."
BUILD_LOG="network_host.log"
set +e
$PIXI_CMD -o "$IMAGE_TAG" --network host --no-install --verbose > "$BUILD_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: --network host build failed."
    cat "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created with --network host."
    cat "$BUILD_LOG"
    rm -f "$BUILD_LOG"
    exit 1
fi

echo "Success: --network host build succeeded."
rm -f "$BUILD_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Build with --network bridge ---
# Only valid with the classic builder. With BuildKit (the default since Docker 23+),
# bridge mode is not supported and the script will correctly surface that error.
# We test the behaviour that matches the active daemon.
if [ "$BUILDKIT_DEFAULT" = true ]; then
    echo "ℹ️ BuildKit is the default builder — --network bridge is not supported."
    echo "Testing that --network bridge fails with a clear error (expected)..."
    BUILD_LOG="network_bridge.log"
    set +e
    $PIXI_CMD -o "$IMAGE_TAG" --network bridge --no-install > "$BUILD_LOG" 2>&1
    BRIDGE_EXIT=$?
    set -e

    if [ $BRIDGE_EXIT -eq 0 ]; then
        echo "Error: --network bridge should have failed with BuildKit but it succeeded."
        docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
        rm -f "$BUILD_LOG"
        exit 1
    fi

    if ! grep -qi "bridge.*not supported\|not supported.*bridge\|network.*bridge" "$BUILD_LOG"; then
        echo "Error: Expected a 'bridge not supported' error message, got something else."
        cat "$BUILD_LOG"
        rm -f "$BUILD_LOG"
        exit 1
    fi

    echo "Success: --network bridge correctly rejected by BuildKit with a clear error."
    rm -f "$BUILD_LOG"
else
    echo "Testing --network bridge build (classic builder)..."
    BUILD_LOG="network_bridge.log"
    set +e
    $PIXI_CMD -o "$IMAGE_TAG" --network bridge --no-install --verbose > "$BUILD_LOG" 2>&1
    EXIT_CODE=$?
    set -e

    if [ $EXIT_CODE -ne 0 ]; then
        echo "Error: --network bridge build failed."
        cat "$BUILD_LOG"
        rm -f "$BUILD_LOG"
        exit $EXIT_CODE
    fi

    if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
        echo "Error: Image $IMAGE_TAG was not created with --network bridge."
        cat "$BUILD_LOG"
        rm -f "$BUILD_LOG"
        exit 1
    fi

    echo "Success: --network bridge build succeeded."
    rm -f "$BUILD_LOG"
    docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
fi

# --- Verify log output mentions the network mode ---
echo "Testing --network log output..."
OUTPUT_LOG="network_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" --network host --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: --network host --no-install build failed."
    cat "$OUTPUT_LOG"
    rm -f "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! grep -q "Build-time network mode: host" "$OUTPUT_LOG"; then
    echo "Error: Network mode log line not found."
    cat "$OUTPUT_LOG"
    rm -f "$OUTPUT_LOG"
    exit 1
fi

echo "Success: --network log line verified."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Build with --network none should fail (apt-get needs network) ---
echo "Testing --network none fails as expected (apt-get requires network)..."

NONE_LOG="network_none.log"
set +e
$PIXI_CMD -o "$IMAGE_TAG" --network none > "$NONE_LOG" 2>&1
NONE_EXIT=$?
set -e

if [ $NONE_EXIT -eq 0 ]; then
    echo "Error: Build with --network none should have failed (no network for apt-get)."
    docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
    rm -f "$NONE_LOG"
    exit 1
fi

echo "Success: --network none correctly causes build failure."

rm -f "$OUTPUT_LOG" "$NONE_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true