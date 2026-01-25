#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="env_test.sif"

rm -f "$IMAGE_NAME"

# RaMiLass has a 'default' environment. We test explicitly selecting it.
echo "Testing --env option..."
$PIXI_CMD -o "$IMAGE_NAME" -e default

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

# Verification
echo "Verifying env image..."
pixi run -m ../../../pixi.toml apptainer run "$IMAGE_NAME" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"

echo "Testing invalid environment option (should fail)..."
if $PIXI_CMD -o "should_fail.sif" -e "non_existent_env_12345" 2>/dev/null; then
    echo "Error: Command succeeded but should have failed with invalid environment."
    exit 1
else
    echo "Success: Command failed as expected for invalid environment."
fi