#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:no-install-labels"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --no-install with TOML labels..."
cp pixi.toml pixi.toml.bak

cat << 'EOF' >> pixi.toml

[tool.pixitainer.docker]
output = "pixitainer-test:no-install-labels"
label = ["NO_INSTALL_LABEL:present"]
EOF

export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD --no-install

mv pixi.toml.bak pixi.toml

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

# Labels must be present even though no env was installed
LABELS=$(docker inspect --format '{{json .Config.Labels}}' "$IMAGE_TAG")
if ! echo "$LABELS" | grep -q "NO_INSTALL_LABEL"; then
    echo "Error: Label NO_INSTALL_LABEL not found in image built with --no-install."
    echo "Labels: $LABELS"
    exit 1
fi

echo "Success: Labels persisted with --no-install."
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
