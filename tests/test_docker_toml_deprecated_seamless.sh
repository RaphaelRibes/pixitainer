#!/bin/bash
set -e

cd "$REPO_DIR"

IMAGE_TAG="pixitainer-test:dep-seamless"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing deprecated 'seamless' TOML key (Docker)..."
cp pixi.toml pixi.toml.bak

cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "pixitainer-test:dep-seamless"
seamless = "True"
keep-def = "True"
EOF

export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p $REPO_DIR"
OUTPUT_LOG="ddep_seamless_log.txt"

set +e
$PIXI_CMD > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

mv pixi.toml.bak pixi.toml

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG not created."
    exit 1
fi

# Deprecation warning must appear
if ! grep -q "seamless.*deprecated" "$OUTPUT_LOG"; then
    echo "Error: Deprecation warning for 'seamless' key not found."
    cat "$OUTPUT_LOG"
    exit 1
fi

# Entrypoint must contain pixi run --locked --as-is
ENTRYPOINT=$(docker inspect --format '{{json .Config.Entrypoint}}' "$IMAGE_TAG")
if ! echo "$ENTRYPOINT" | grep -q "pixi"; then
    echo "Error: ENTRYPOINT does not reference pixi."
    exit 1
fi
if ! echo "$ENTRYPOINT" | grep -q "\-\-locked"; then
    echo "Error: ENTRYPOINT missing --locked."
    exit 1
fi

docker run --rm "$IMAGE_TAG" pixi run --as-is python --version | grep "Python 3."

echo "Success: Deprecated seamless TOML key verified (Docker)."
rm -f "$OUTPUT_LOG"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
