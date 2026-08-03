#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing invalid --base-image (SIF)..."
if $PIXI_CMD -o "should_fail_invalid_base.sif" --base-image "this_image_does_not_exist:really" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed with an invalid base image."
    rm -f "should_fail_invalid_base.sif"
    exit 1
fi

# Assert no image was created
if [ -f "should_fail_invalid_base.sif" ]; then
    echo "Error: Image was created despite invalid base image."
    rm -f "should_fail_invalid_base.sif"
    exit 1
fi

echo "Success: Invalid base image correctly caused a failure."
