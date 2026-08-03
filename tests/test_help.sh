#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing -h/--help..."
HELP_OUTPUT=$($PIXI_CMD -h 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: --help exited with $EXIT_CODE."
    exit 1
fi

if ! echo "$HELP_OUTPUT" | grep -q "pixi containerize"; then
    echo "Error: 'pixi containerize' not found in help output."
    echo "$HELP_OUTPUT"
    exit 1
fi

if ! echo "$HELP_OUTPUT" | grep -q "Usage:"; then
    echo "Error: 'Usage:' not found in help output."
    echo "$HELP_OUTPUT"
    exit 1
fi

echo "Success: Help output verified."
