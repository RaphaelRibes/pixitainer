#!/bin/bash
set -e

# If PIXI_CMD is not set, we assume standalone execution
if [ -z "$PIXI_CMD" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    PIXI_CMD="$PROJECT_ROOT/pixi-containerize"
    REPO_DIR="$PROJECT_ROOT"
fi

cd "$REPO_DIR"

# 1. Test --post-command
IMAGE_NAME="test_post_cmd.sif"
rm -f "$IMAGE_NAME"

echo "Testing --post-command option..."
# We add a command to create a file in /opt/conf
$PIXI_CMD -o "$IMAGE_NAME" --base-image "ubuntu:22.04" --post-command "touch /opt/conf/post_cmd_success" --no-install

if [ ! -f "$IMAGE_NAME" ]; then
    echo "Error: $IMAGE_NAME not found."
    exit 1
fi

echo "Verifying file creation from post command..."
if apptainer exec "$IMAGE_NAME" ls /opt/conf/post_cmd_success > /dev/null 2>&1; then
    echo "Success: Post command executed correctly."
else
    echo "Error: Post command failed (file not found)."
    exit 1
fi