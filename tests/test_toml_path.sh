#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore .pixi toml_path.sif pixi.toml subdir
mkdir subdir
cd subdir
pixi init .
pixi add python
cd ..

echo "Initializing project in subdir..."

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
APPTAINER_CMD="pixi run -m ../../../pixi.toml apptainer"

$APPTAINER_CMD run toml_path.sif python --version | grep "Python 3."

echo "Path TOML configuration verified successfully."
