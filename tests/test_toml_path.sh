#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore toml_path.sif subdir

echo "Setting up an inner project in subdir by copying base environment..."
mkdir subdir
cp pixi.toml subdir/
cp pixi.lock subdir/ 2>/dev/null || true
cp -r .pixi subdir/ 2>/dev/null || true
cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "toml_path.sif"
path = "subdir"
seamless = "True"
EOF

# We do NOT use PIXI_CMD since it passes -p which overrides the TOML path.
TOOL_RUN="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT"

$TOOL_RUN

if [ ! -f "toml_path.sif" ]; then
    echo "Error: toml_path.sif not created."
    exit 1
fi

echo "Verifying Python inside toml_path.sif..."
$CONTAINER_CMD run toml_path.sif python --version | grep "Python 3."

echo "Path TOML configuration verified successfully."
