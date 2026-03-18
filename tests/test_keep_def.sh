#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="keep_def_test.sif"
DEF_FILE="keep_def_test.def"

# Cleanup potential leftovers
rm -rf .tmp_pixitainer
rm -f "$IMAGE_NAME"

echo "Testing --keep-def option..."
$PIXI_CMD -o "$IMAGE_NAME" --keep-def

if [ ! -f "$DEF_FILE" ]; then
    echo "Error: Definition file was NOT preserved at $DEF_FILE"
    exit 1
fi

echo "Success: Definition file found at $DEF_FILE"

# Verification
CONTAINER_PYTHON=$($CONTAINER_CMD run "$IMAGE_NAME" pixi run --as-is python --version)

if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
else
    echo "Success: Container python version matches ($CONTAINER_PYTHON)."
fi