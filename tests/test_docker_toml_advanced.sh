#!/bin/bash
set -e

cd "$REPO_DIR"

IMAGE_TAG="pixitainer-test:toml-advanced"
# keep-def saves "Dockerfile.<sanitized_tag>"
EXPECTED_DOCKERFILE="Dockerfile.pixitainer-test_toml-advanced"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -rf .gitignore "$EXPECTED_DOCKERFILE" output.log

echo "Using base project for advanced TOML testing..."

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:toml-advanced"
seamless = "True"
keep-def = "True"
no-install = "True"
verbose = "True"
quiet = "False"
EOF

export PIXI_CMD="$TOOL_SCRIPT -p $REPO_DIR"

echo "Building container..."
set +e
$PIXI_CMD > output.log 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat output.log
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

if [ ! -f "$EXPECTED_DOCKERFILE" ]; then
    echo "Error: $EXPECTED_DOCKERFILE not found — keep-def failed."
    ls -la Dockerfile.* 2>/dev/null || true
    exit 1
fi

echo "Verifying verbose output..."
if ! grep -qE "Starting Docker build\.\.\." output.log; then
    echo "Error: verbose 'Starting Docker build...' not found in output."
    cat output.log
    exit 1
fi

echo "Verifying seamless mode in Dockerfile..."
if ! grep -q "pixi.*run.*as-is" "$EXPECTED_DOCKERFILE"; then
    echo "Error: Seamless ENTRYPOINT not found in Dockerfile."
    cat "$EXPECTED_DOCKERFILE"
    exit 1
fi

echo "Verifying no-install mode in Dockerfile..."
if ! grep -q "Skipping environment installation" "$EXPECTED_DOCKERFILE"; then
    echo "Error: no-install skip message not found in Dockerfile."
    cat "$EXPECTED_DOCKERFILE"
    exit 1
fi

echo "Advanced TOML configuration verified successfully."

rm -f "$EXPECTED_DOCKERFILE" output.log
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
