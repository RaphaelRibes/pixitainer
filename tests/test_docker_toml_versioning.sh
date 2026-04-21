#!/bin/bash
set -e

cd "$REPO_DIR"

IMAGE_TAG="pixitainer-test:toml-versioning"
EXPECTED_DOCKERFILE="Dockerfile.pixitainer-test_toml-versioning"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -rf .gitignore "$EXPECTED_DOCKERFILE"
cp pixi.toml pixi.toml.bak

echo "Using base project for versioning TOML testing..."

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:toml-versioning"
keep-def = "True"
pixi-version = "0.64.0"
EOF

export PIXI_CMD="$TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

if [ ! -f "$EXPECTED_DOCKERFILE" ]; then
    echo "Error: $EXPECTED_DOCKERFILE not found."
    exit 1
fi

# The version must be baked into the Dockerfile as an ENV var
if ! grep -q "PIXI_VERSION=0.64.0" "$EXPECTED_DOCKERFILE"; then
    echo "Error: PIXI_VERSION=0.64.0 not found in Dockerfile."
    cat "$EXPECTED_DOCKERFILE"
    exit 1
fi

echo "Success: pixi-version=0.64.0 present in Dockerfile."

echo "Testing 'latest' TOML option..."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -f "$EXPECTED_DOCKERFILE"
# Restore backup and append new test config
mv pixi.toml.bak pixi.toml

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:toml-versioning"
keep-def = "True"
latest = "True"
EOF

$PIXI_CMD

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created with latest=true."
    exit 1
fi

if ! [ -f "$EXPECTED_DOCKERFILE" ]; then
    echo "Error: $EXPECTED_DOCKERFILE not found for latest test."
    exit 1
fi

# With latest=true, no PIXI_VERSION env var should be set
if grep -q "^ENV PIXI_VERSION=" "$EXPECTED_DOCKERFILE"; then
    echo "Error: PIXI_VERSION env should NOT be present when latest=true."
    cat "$EXPECTED_DOCKERFILE"
    exit 1
fi

echo "Success: latest=true correctly omits PIXI_VERSION pin."

rm -f "$EXPECTED_DOCKERFILE"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
