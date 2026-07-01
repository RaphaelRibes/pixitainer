#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore
IMAGE_TAG="pixitainer-test:backend-override"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing TOML backend subtable override (Docker)..."
cp pixi.toml pixi.toml.bak

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:shared-output"
label = ["AUTHOR:shared"]

[tool.pixitainer.docker]
output = "pixitainer-test:backend-override"
label = ["AUTHOR:docker", "ENV:staging"]
EOF

export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD

mv pixi.toml.bak pixi.toml

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Backend-specific output tag $IMAGE_TAG was not created."
    exit 1
fi

# The shared tag must NOT exist
if docker image inspect "pixitainer-test:shared-output" > /dev/null 2>&1; then
    echo "Error: Shared output tag should not exist — backend subtable should have won."
    docker rmi -f "pixitainer-test:shared-output" > /dev/null 2>&1 || true
    exit 1
fi

# Backend-specific labels must be present; shared labels must NOT be
LABELS=$(docker inspect --format '{{json .Config.Labels}}' "$IMAGE_TAG")
if echo "$LABELS" | grep -q "AUTHOR:shared"; then
    echo "Error: Shared label 'AUTHOR:shared' leaked into backend-specific image."
    exit 1
fi
if ! echo "$LABELS" | grep -q "AUTHOR:docker"; then
    echo "Error: Backend-specific label 'AUTHOR:docker' not found."
    exit 1
fi
if ! echo "$LABELS" | grep -q "ENV:staging"; then
    echo "Error: Backend-specific label 'ENV:staging' not found."
    exit 1
fi

docker run --rm "$IMAGE_TAG" pixi run --as-is python --version | grep "Python 3."

echo "Success: TOML backend subtable override verified (Docker)."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
