#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore pixitainer-test.tar toml_test
IMAGE_TAG="pixitainer-test:toml-options"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Using base project for TOML option testing..."

# Create a file to inject via add-file
echo "Validating add-file works." > test_file.txt

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:toml-options"
base-image = "ubuntu:24.04"
add-file = ["test_file.txt:/opt/test_file.txt"]
post-command = ["echo 'Hello from post-command' > /opt/post_cmd.txt"]
label = ["APP_VERSION:1.2.3"]
env = ["default"]
quiet = "True"
EOF

echo "Building container from TOML configuration (no CLI overrides)..."
export PIXI_CMD="$TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG not found. TOML options were not applied."
    exit 1
fi

echo " -> Verifying Python is installed..."
docker run --rm "$IMAGE_TAG" pixi run --as-is python --version | grep "Python 3."

echo " -> Verifying add-file..."
docker run --rm "$IMAGE_TAG" cat /opt/test_file.txt | grep "Validating add-file works"

echo " -> Verifying post-command..."
docker run --rm "$IMAGE_TAG" cat /opt/post_cmd.txt | grep "Hello from post-command"

echo " -> Verifying custom label..."
LABELS=$(docker inspect --format '{{json .Config.Labels}}' "$IMAGE_TAG")
if ! echo "$LABELS" | grep -q "APP_VERSION"; then
    echo "Error: APP_VERSION label not found."
    echo "Labels: $LABELS"
    exit 1
fi
if ! echo "$LABELS" | grep -q "1.2.3"; then
    echo "Error: Label value 1.2.3 not found."
    echo "Labels: $LABELS"
    exit 1
fi

echo "All TOML option bounds verified successfully."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
