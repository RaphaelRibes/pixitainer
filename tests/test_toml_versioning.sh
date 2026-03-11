#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore .pixi toml_pversion.sif pixi.toml toml_pversion.def

echo "Initializing simple pixi project for versioning TOML testing..."
pixi init .
pixi add python

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "toml_pversion.sif"
keep-def = "True"
pixi-version = "0.64.0"
EOF

# Override PIXI_CMD
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml -- $TOOL_SCRIPT -p $REPO_DIR"

$PIXI_CMD

if [ ! -f "toml_pversion.sif" ]; then
    echo "Error: toml_pversion.sif not found."
    exit 1
fi

if [ ! -f "toml_pversion.def" ]; then
    echo "Error: toml_pversion.def not found."
    exit 1
fi

if ! grep -q "pixi self-update --version 0.64.0" toml_pversion.def; then
    echo "Error: pixi-version not configured correctly in def."
    exit 1
fi

echo "Testing 'latest' option..."
rm -rf toml_pversion.sif toml_pversion.def
cat << 'EOF' > pixi.toml
[project]
name = "test"
channels = ["conda-forge"]
platforms = ["linux-64"]

[dependencies]
python = "*"

[tool.pixitainer]
output = "toml_pversion.sif"
keep-def = "True"
latest = "True"
EOF

$PIXI_CMD

if grep -q "pixi self-update" toml_pversion.def; then
    echo "Error: latest=true should not specify self-update in def file."
    exit 1
fi

echo "Pixi versioning TOML config verified."
