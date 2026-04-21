#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:pyproject"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

# Remove any existing pixi.toml so we rely solely on pyproject.toml
rm -f pixi.toml pixi.lock

cat <<EOF > pyproject.toml
[workspace]
name = "test_pyproject"
version = "0.1.0"
description = "Test pyproject.toml support"
authors = [{name = "Test", email = "test@example.com"}]
requires-python = ">= 3.11"
dependencies = []

[tool.pixi.project]
channels = ["conda-forge"]
platforms = ["linux-64"]

[tool.pixi.tasks]
hello = "echo Hello from pyproject"
EOF

pixi lock

echo "Testing pyproject.toml project support..."
export PIXI_CMD="$TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD -o "$IMAGE_TAG"

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying task from pyproject.toml runs inside container..."
RESULT=$(docker run --rm "$IMAGE_TAG" pixi run --as-is -m /opt/conf/pyproject.toml hello)

if ! echo "$RESULT" | grep -q "Hello from pyproject"; then
    echo "Error: Expected 'Hello from pyproject' in output. Got: $RESULT"
    exit 1
fi

echo "Success: pyproject.toml project containerized and task verified."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
