h#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="dry_run_test.sif"

# Cleanup potential leftovers
rm -rf .tmp_pixitainer
rm -f "$IMAGE_NAME"

echo "Testing --dry-run option..."
DEF_OUTPUT=$($PIXI_CMD -o "$IMAGE_NAME" --dry-run)

# The image should NOT have been built
if [ -f "$IMAGE_NAME" ]; then
    echo "Error: Image was built despite --dry-run flag"
    exit 1
fi

echo "Success: Image was NOT built (as expected)"

# The .def content should be present in stdout
if [[ ! "$DEF_OUTPUT" =~ "Bootstrap: docker" ]]; then
    echo "Error: Definition file content not found in stdout"
    exit 1
fi

if [[ ! "$DEF_OUTPUT" =~ "%post" ]]; then
    echo "Error: %post section not found in stdout"
    exit 1
fi

if [[ ! "$DEF_OUTPUT" =~ "%runscript" ]]; then
    echo "Error: %runscript section not found in stdout"
    exit 1
fi

echo "Success: Definition file content correctly output to stdout"

# The tmp directory should have been cleaned up
if [ -d ".tmp_pixitainer" ]; then
    echo "Error: Temporary directory was not cleaned up"
    exit 1
fi

echo "Success: Temporary directory was cleaned up"
