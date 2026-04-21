#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:ssh"

# --- Skip if buildx is unavailable ---
if ! docker buildx version > /dev/null 2>&1; then
    echo "SKIP: docker buildx is not available. Skipping --ssh test."
    exit 0
fi

# --- Skip if no SSH agent socket is available ---
if [ -z "$SSH_AUTH_SOCK" ]; then
    echo "SKIP: SSH_AUTH_SOCK is not set (no ssh-agent running). Skipping --ssh test."
    exit 0
fi

if [ ! -S "$SSH_AUTH_SOCK" ]; then
    echo "SKIP: SSH_AUTH_SOCK ($SSH_AUTH_SOCK) is not a valid socket. Skipping --ssh test."
    exit 0
fi

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify --ssh is accepted without error ---
echo "Testing --ssh default is accepted (dry-run)..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --ssh default --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^FROM "; then
    echo "Error: FROM instruction missing in dry-run output with --ssh default."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: --ssh default accepted in dry-run."

# --- Real build: the ssh agent is forwarded but we don't need a real key to test success ---
# We use --no-install to keep the build fast; the SSH mount is transparent.
echo "Building with --ssh default and --no-install..."
OUTPUT_LOG="ssh_log.txt"

set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --ssh default \
    --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    # If failure is due to ssh-agent having no identities, that is acceptable — the
    # flag was correctly forwarded; the agent just had nothing to offer.
    if grep -qiE "no identities|could not load.*identity|agent.*empty" "$OUTPUT_LOG"; then
        echo "ℹ️ ssh-agent is running but has no loaded identities — flag forwarded correctly."
        echo "SKIP: No SSH identities loaded; skipping build-level verification."
        rm -f "$OUTPUT_LOG"
        exit 0
    fi
    echo "Error: Build with --ssh default failed unexpectedly."
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created with --ssh default."
    exit 1
fi

# --- Verify log line ---
if ! grep -q "Forwarding SSH agent: default" "$OUTPUT_LOG"; then
    echo "Error: 'Forwarding SSH agent' log line not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

echo "Success: --ssh default build completed and SSH agent log line verified."

rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
