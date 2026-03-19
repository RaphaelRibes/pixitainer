#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup
rm -rf .gitignore .pixi toml_advanced.sif pixi.toml toml_advanced.def output.log

echo "Initializing simple pixi project for advanced TOML testing..."
pixi init .
pixi add python

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "toml_advanced.sif"
seamless = "True"
keep-def = "True"
no-install = "True"
verbose = "True"
quiet = "False"
EOF

# Override PIXI_CMD to use this new isolated project directory instead of RaMiLass
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml -- $TOOL_SCRIPT -p $REPO_DIR"

echo "Building container..."
# Capture output to test verbose
set +e
$PIXI_CMD > output.log 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat output.log
    exit $EXIT_CODE
fi

if [ ! -f "toml_advanced.sif" ]; then
    echo "Error: toml_advanced.sif not found."
    exit 1
fi

if [ ! -f "toml_advanced.def" ]; then
    echo "Error: toml_advanced.def not found. keep-def failed."
    exit 1
fi

echo "Verifying verbose output..."
# Verify verbose output
if ! grep -qE "Starting (Apptainer|Singularity) build\.\.\." output.log; then
    echo "Error: verbose output missing."
    cat output.log
    exit 1
fi

echo "Verifying seamless mode in def file..."
# Verify seamless in def file
if ! grep -q "pixi run --locked --as-is" toml_advanced.def; then
    echo "Error: seamless mode not requested in def file."
    exit 1
fi

echo "Verifying no-install mode in def file..."
# Verify no-install in def file
if ! grep -q "Skipping environment installation" toml_advanced.def; then
    echo "Error: no-install not found in def file."
    exit 1
fi

echo "Advanced TOML configuration bounds verified successfully."
