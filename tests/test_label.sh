#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup previous runs
rm -f pixitainer.sif

echo "Testing -l/--label execution..."
$PIXI_CMD -l MY_LABEL:HelloWorld -l SECOND_LABEL:123

if [ ! -f "pixitainer.sif" ]; then
    echo "Error: Output pixitainer.sif not found."
    exit 1
fi

echo "Verifying labels in the image..."
# Extract the labels using apptainer inspect
LABELS_OUTPUT=$(pixi run -m "$(pwd -P)"/../../pixi.toml apptainer inspect pixitainer.sif)

if ! echo "$LABELS_OUTPUT" | grep -q "HelloWorld"; then
    echo "Error: MY_LABEL:HelloWorld is not present in the image."
    echo "Labels output was:"
    echo "$LABELS_OUTPUT"
    exit 1
fi

if ! echo "$LABELS_OUTPUT" | grep -q "123"; then
    echo "Error: SECOND_LABEL:123 is not present in the image."
    echo "Labels output was:"
    echo "$LABELS_OUTPUT"
    exit 1
fi

echo "Success: Labels correctly found in image."
