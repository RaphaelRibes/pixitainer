#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup previous runs
rm -f pixitainer.sif
rm -f pixi.toml pixi.lock

# Create a sample pyproject.toml based project
cat <<EOF > pyproject.toml
[project]
name = "test_pyproject"
version = "0.1.0"
description = "Test pyproject.toml"
authors = [{name = "Test", email = "test@example.com"}]
requires-python = ">= 3.11"
dependencies = []

[tool.pixi.project]
channels = ["conda-forge"]
platforms = ["linux-64"]

[tool.pixi.tasks]
hello = "echo Hello from pyproject"
EOF

# Generate lockfile
pixi lock

echo "Testing pyproject.toml execution..."
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD

if [ ! -f "pixitainer.sif" ]; then
    echo "Error: Default output pixitainer.sif not found for pyproject.toml."
    exit 1
fi

# Verification
echo "Verifying image..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run pixitainer.sif pixi run --as-is -m /opt/conf/pyproject.toml hello | grep "Hello from pyproject"
