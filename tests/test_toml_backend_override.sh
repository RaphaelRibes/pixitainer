#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore toml_backend_override.sif

echo "Testing TOML backend subtable override..."
cp pixi.toml pixi.toml.bak

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "toml_backend_override_shared.sif"
label = ["AUTHOR:shared"]

[tool.pixitainer.apptainer]
output = "toml_backend_override.sif"
label = ["AUTHOR:apptainer", "ENV:production"]
EOF

# Build without CLI -o or -l; the backend subtable must win
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml -- $TOOL_SCRIPT -p $REPO_DIR"
$PIXI_CMD

if [ ! -f "toml_backend_override.sif" ]; then
    echo "Error: Output 'toml_backend_override.sif' not found — backend subtable output was ignored."
    mv pixi.toml.bak pixi.toml
    exit 1
fi

# Verify the shared output path was NOT used
if [ -f "toml_backend_override_shared.sif" ]; then
    echo "Error: Shared table output path was used instead of backend-specific one."
    mv pixi.toml.bak pixi.toml
    exit 1
fi

# Verify backend-specific labels are present (array replacement, not merge)
LABELS_OUTPUT=$($CONTAINER_CMD inspect toml_backend_override.sif)
if echo "$LABELS_OUTPUT" | grep -q "AUTHOR:shared"; then
    echo "Error: Shared label 'AUTHOR:shared' should have been replaced by backend subtable."
    mv pixi.toml.bak pixi.toml
    exit 1
fi
if ! echo "$LABELS_OUTPUT" | grep -q "AUTHOR:apptainer"; then
    echo "Error: Backend-specific label 'AUTHOR:apptainer' not found."
    mv pixi.toml.bak pixi.toml
    exit 1
fi
if ! echo "$LABELS_OUTPUT" | grep -q "ENV:production"; then
    echo "Error: Backend-specific label 'ENV:production' not found."
    mv pixi.toml.bak pixi.toml
    exit 1
fi

mv pixi.toml.bak pixi.toml

# Verify container works
$CONTAINER_CMD run toml_backend_override.sif pixi run --as-is python --version | grep "Python 3."

echo "Success: TOML backend subtable override verified."
