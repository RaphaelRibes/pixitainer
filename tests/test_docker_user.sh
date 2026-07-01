#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:user"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify USER instruction is emitted in Dockerfile ---
echo "Testing --user appears in Dockerfile (dry-run)..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --user appuser --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^USER appuser"; then
    echo "Error: USER appuser instruction not found in dry-run Dockerfile output."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: USER appuser instruction present in Dockerfile."

# --- Verify USER instruction is placed after all RUN instructions ---
# It must come after the pixi install layer to avoid permission issues during build.
LAST_RUN_LINE=$(echo "$DOCKERFILE_OUTPUT" | grep -n "^RUN" | tail -1 | cut -d: -f1)
USER_LINE=$(echo "$DOCKERFILE_OUTPUT" | grep -n "^USER" | head -1 | cut -d: -f1)

if [ -z "$USER_LINE" ]; then
    echo "Error: No USER line found in dry-run output."
    exit 1
fi

if [ "$USER_LINE" -le "$LAST_RUN_LINE" ]; then
    echo "Error: USER instruction (line $USER_LINE) appears before the last RUN (line $LAST_RUN_LINE)."
    echo "USER must come after all RUN layers to avoid permission issues during build."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: USER instruction correctly placed after all RUN instructions."

# --- Real build: create the user via post-command, then switch to it ---
# NOTE: built in --manual mode on purpose. This test validates the USER
# instruction (placement + runtime identity), which is orthogonal to pixi
# execution. Seamless mode would route `whoami` through
# `pixi run -m /opt/conf/pixi.toml`, which requires an installed environment
# (we pass --no-install) and read access to root-owned /opt/conf as the
# non-root user. Manual mode uses `exec "$@"`, so `whoami` runs directly as
# appuser and the test stays focused on the USER instruction alone.
echo "Building image with --user appuser (created via --post-command)..."
USER_BUILD_LOG="user_build.log"
set +e
$PIXI_CMD -o "$IMAGE_TAG" \
    --base-image "ubuntu:24.04" \
    --post-command "useradd -m -s /bin/bash appuser" \
    --user appuser \
    --manual \
    --no-install > "$USER_BUILD_LOG" 2>&1
USER_EC=$?
set -e

if [ $USER_EC -ne 0 ]; then
    echo "Error: Docker build with --user failed (exit=$USER_EC)."
    cat "$USER_BUILD_LOG"
    rm -f "$USER_BUILD_LOG"
    exit $USER_EC
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# Verify the container actually runs as the specified user
echo "Verifying container runs as appuser..."
WHOAMI=$(docker run --rm "$IMAGE_TAG" whoami)

if [ "$WHOAMI" != "appuser" ]; then
    echo "Error: Expected container to run as 'appuser', got: '$WHOAMI'"
    exit 1
fi

echo "Success: Container runs as '$WHOAMI'."

# --- Verify USER line in image metadata ---
USER_META=$(docker inspect --format '{{.Config.User}}' "$IMAGE_TAG")
if [ "$USER_META" != "appuser" ]; then
    echo "Error: Docker image metadata User field is '$USER_META', expected 'appuser'."
    exit 1
fi

echo "Success: Image metadata confirms User=$USER_META."

# --- Test with numeric UID (always safe, no useradd needed) ---
echo "Testing --user with numeric UID 0 (root)..."
IMAGE_TAG2="pixitainer-test:user-root"
docker rmi -f "$IMAGE_TAG2" > /dev/null 2>&1 || true

UID_BUILD_LOG="user_uid_build.log"
set +e
$PIXI_CMD -o "$IMAGE_TAG2" --user 0 --manual --no-install > "$UID_BUILD_LOG" 2>&1
UID_EC=$?
set -e

if [ $UID_EC -ne 0 ]; then
    echo "Error: Docker build with --user 0 failed (exit=$UID_EC)."
    cat "$UID_BUILD_LOG"
    rm -f "$UID_BUILD_LOG"
    exit $UID_EC
fi

WHOAMI2=$(docker run --rm "$IMAGE_TAG2" whoami)
if [ "$WHOAMI2" != "root" ]; then
    echo "Error: Expected 'root' for UID 0, got: '$WHOAMI2'"
    exit 1
fi

echo "Success: Numeric UID 0 resolves to '$WHOAMI2'."

docker rmi -f "$IMAGE_TAG" "$IMAGE_TAG2" > /dev/null 2>&1 || true