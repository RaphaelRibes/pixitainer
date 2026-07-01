#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing --pixi-version + --latest conflict..."
HOST_VER=$(pixi -V | awk '{print $NF}')
if $PIXI_CMD -o "should_never_build.sif" --pixi-version "$HOST_VER" --latest 2>/dev/null; then
    echo "Error: --pixi-version and --latest together should have failed."
    rm -f "should_never_build.sif"
    exit 1
fi

# Assert no image was built despite the flags
if [ -f "should_never_build.sif" ]; then
    echo "Error: Image was created despite conflicting flags."
    rm -f "should_never_build.sif"
    exit 1
fi

echo "Success: --pixi-version + --latest conflict correctly detected."
