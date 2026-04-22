#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:workdir"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# --- Dry-run: verify overridden WORKDIR appears in Dockerfile ---
echo "Testing --workdir appears in Dockerfile (dry-run)..."
DOCKERFILE_OUTPUT=$($PIXI_CMD -o "$IMAGE_TAG" --workdir /workspace --dry-run)

if ! echo "$DOCKERFILE_OUTPUT" | grep -q "^WORKDIR /workspace"; then
    echo "Error: WORKDIR /workspace not found in dry-run Dockerfile output."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

# Also verify the default /opt/conf is NOT used anywhere else for the install step
WORKDIR_COUNT=$(echo "$DOCKERFILE_OUTPUT" | grep -c "^WORKDIR /opt/conf" || true)
if [ "$WORKDIR_COUNT" -gt 0 ]; then
    echo "Error: Default WORKDIR /opt/conf still appears despite --workdir override."
    echo "$DOCKERFILE_OUTPUT"
    exit 1
fi

echo "Success: WORKDIR /workspace present, default /opt/conf absent."

# --- Real build: verify pwd inside container matches the overridden workdir ---
echo "Building image with --workdir /workspace..."
$PIXI_CMD -o "$IMAGE_TAG" \
    --workdir /workspace \
    --no-install \
    --quiet

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying container working directory is /workspace..."
CONTAINER_PWD=$(docker run --rm "$IMAGE_TAG" pwd)

if [ "$CONTAINER_PWD" != "/workspace" ]; then
    echo "Error: Expected working directory '/workspace', got: '$CONTAINER_PWD'."
    exit 1
fi

echo "Success: Container pwd is '$CONTAINER_PWD'."

# --- Verify via image metadata ---
WORKDIR_META=$(docker inspect --format '{{.Config.WorkingDir}}' "$IMAGE_TAG")
if [ "$WORKDIR_META" != "/workspace" ]; then
    echo "Error: Docker metadata WorkingDir is '$WORKDIR_META', expected '/workspace'."
    exit 1
fi

echo "Success: Image metadata confirms WorkingDir=$WORKDIR_META."

# --- Verify default workdir is /opt/conf when --workdir is not passed ---
echo "Testing default WORKDIR (/opt/conf) without --workdir flag..."
IMAGE_TAG2="pixitainer-test:workdir-default"
docker rmi -f "$IMAGE_TAG2" > /dev/null 2>&1 || true

DOCKERFILE_DEFAULT=$($PIXI_CMD -o "$IMAGE_TAG2" --dry-run)

if ! echo "$DOCKERFILE_DEFAULT" | grep -q "^WORKDIR /opt/conf"; then
    echo "Error: Default WORKDIR /opt/conf not found when --workdir is omitted."
    echo "$DOCKERFILE_DEFAULT"
    exit 1
fi

echo "Success: Default WORKDIR /opt/conf confirmed."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
