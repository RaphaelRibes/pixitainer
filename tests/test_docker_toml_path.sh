#!/bin/bash
set -e

cd "$REPO_DIR"

IMAGE_TAG="pixitainer-test:toml-path"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -rf .gitignore subdir

echo "Setting up an inner project in a subdirectory by copying base environment..."
mkdir subdir
cp pixi.toml subdir/
cp pixi.lock subdir/ 2>/dev/null || true
cp -r .pixi subdir/ 2>/dev/null || true

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:toml-path"
path = "subdir"
seamless = "True"
EOF

# Do NOT use PIXI_CMD here — it adds -p which would override the TOML path setting.
TOOL_RUN="$TOOL_SCRIPT"
$TOOL_RUN

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying Python inside container (seamless mode)..."
docker run --rm "$IMAGE_TAG" python --version | grep "Python 3."

echo "Path TOML configuration verified successfully."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
