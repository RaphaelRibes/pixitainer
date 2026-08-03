#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing -h/--help (Docker)..."
HELP_OUTPUT=$($PIXI_CMD -h 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: --help exited with $EXIT_CODE."
    exit 1
fi

if ! echo "$HELP_OUTPUT" | grep -q "pixi containerize-docker"; then
    echo "Error: 'pixi containerize-docker' not found in help output."
    echo "$HELP_OUTPUT"
    exit 1
fi

if ! echo "$HELP_OUTPUT" | grep -q "Usage:"; then
    echo "Error: 'Usage:' not found in help output."
    echo "$HELP_OUTPUT"
    exit 1
fi

echo "Success: Docker help output verified."
