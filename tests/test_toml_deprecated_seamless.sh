#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore test_dep_seamless.sif

echo "Testing deprecated 'seamless' TOML key..."
cp pixi.toml pixi.toml.bak

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "test_dep_seamless.sif"
seamless = "True"
keep-def = "True"
EOF

export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml -- $TOOL_SCRIPT -p $REPO_DIR"
OUTPUT_LOG="dep_seamless_log.txt"

set +e
$PIXI_CMD > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

mv pixi.toml.bak pixi.toml

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if [ ! -f "test_dep_seamless.sif" ]; then
    echo "Error: test_dep_seamless.sif not found."
    exit 1
fi

# Deprecation warning must appear in stderr/log
if ! grep -q "seamless.*deprecated" "$OUTPUT_LOG"; then
    echo "Error: Deprecation warning for 'seamless' key not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

# Runscript must contain pixi run --locked --as-is
if [ -f "test_dep_seamless.def" ]; then
    if ! grep -q "pixi run --locked --as-is" "test_dep_seamless.def"; then
        echo "Error: 'pixi run --locked --as-is' not found in .def file."
        exit 1
    fi
else
    echo "Error: .def file not found (keep-def should have preserved it)."
    exit 1
fi

$CONTAINER_CMD run test_dep_seamless.sif pixi run --as-is python --version | grep "Python 3."

echo "Success: Deprecated seamless TOML key verified."
rm -f "$OUTPUT_LOG"
