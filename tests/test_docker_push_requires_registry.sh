#!/bin/bash
set -e

cd "$REPO_DIR"

echo "Testing --push with an unreachable registry (should fail)..."
OUTPUT_LOG="push_fail_log.txt"

set +e
$PIXI_CMD -o "invalid.registry.example.com/nobody/test:latest" --push --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo "Error: --push to an invalid registry should have failed."
    cat "$OUTPUT_LOG"
    rm -f "$OUTPUT_LOG"
    exit 1
fi

# Should have exited non-zero; the exact error depends on Docker daemon resolver.
echo "Push rejected as expected (exit=$EXIT_CODE)."

echo "Success: --push rejected for unreachable registry."
rm -f "$OUTPUT_LOG"
