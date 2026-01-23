#!/bin/bash
set -e

cd "$REPO_DIR"
CUSTOM_NAME="custom_image"

# Cleanup
rm -f "$CUSTOM_NAME.sif"

echo "Testing --output option..."
$PIXI_CMD --output "$CUSTOM_NAME"

if [ ! -f "$CUSTOM_NAME.sif" ]; then
    echo "Error: Output file $CUSTOM_NAME.sif not found."
    exit 1
fi

# Verification
echo "Verifying image..."
pixi run -m "$(pwd -P)"/../../pixi.toml apptainer run "$CUSTOM_NAME.sif" pixi run --as-is -m /opt/conf/pixi.toml "echo \$(pixi -V)"