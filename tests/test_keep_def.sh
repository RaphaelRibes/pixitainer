#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="keep_def_test.sif"
DEF_FILE=".tmp_pixitainer/pixitainer.def"

# Cleanup potential leftovers
rm -rf .tmp_pixitainer
rm -f "$IMAGE_NAME"

echo "Testing --keep-def option..."
$PIXI_CMD -o keep_def_test --keep-def

if [ ! -f "$DEF_FILE" ]; then
    echo "Error: Definition file was NOT preserved at $DEF_FILE"
    exit 1
fi

echo "Success: Definition file found at $DEF_FILE"

# Verification
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"