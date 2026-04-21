#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:squash"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify --squash is accepted and Dockerfile is valid ---
# --squash only modifies the docker build command, not the Dockerfile itself,
# so dry-run is the reliable way to confirm it is parsed without error.
echo "Testing --squash is accepted without error (dry-run)..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --squash --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^FROM "; then
    echo "Error: FROM instruction missing in dry-run output with --squash."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: --squash accepted and Dockerfile is valid."

# --- Check for the experimental warning when squash is requested ---
# If the Docker daemon does not have experimental mode enabled, the script
# should print a warning but NOT abort (it still attempts the build).
echo "Checking experimental warning behavior..."
OUTPUT_LOG="squash_warn_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" --squash --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

DAEMON_EXPERIMENTAL=$(docker info --format '{{.ExperimentalBuild}}' 2>/dev/null || echo "false")

if [ "$DAEMON_EXPERIMENTAL" = "true" ]; then
    # Experimental on: build should succeed and no warning needed
    if [ $EXIT_CODE -ne 0 ]; then
        echo "Error: --squash build failed on a daemon with experimental enabled."
        cat "$OUTPUT_LOG"
        exit 1
    fi
    if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
        echo "Error: Image $IMAGE_TAG was not created with --squash."
        exit 1
    fi
    # A squashed image should have fewer layers than a normal one
    LAYER_COUNT=$(docker history --no-trunc "$IMAGE_TAG" | grep -c "<missing>" || true)
    echo "Squashed image layer count: $LAYER_COUNT"
    echo "Success: --squash build completed with experimental mode enabled."
else
    # Experimental off: the warning must appear in the log
    if ! grep -q "Warning.*squash.*experimental" "$OUTPUT_LOG"; then
        echo "Error: Expected experimental warning for --squash but none found."
        cat "$OUTPUT_LOG"
        exit 1
    fi
    echo "Success: Experimental warning correctly emitted when daemon lacks experimental support."
fi

rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
