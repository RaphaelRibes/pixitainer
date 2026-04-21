#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:post-cmd"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing --post-command option..."
# Create a file inside the image during build using a post command
$PIXI_CMD -o "$IMAGE_TAG" \
    --base-image "ubuntu:22.04" \
    --post-command "touch /opt/conf/post_cmd_success" \
    --no-install

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying file created by post-command..."
if ! docker run --rm "$IMAGE_TAG" test -f /opt/conf/post_cmd_success; then
    echo "Error: Post-command file /opt/conf/post_cmd_success not found in container."
    exit 1
fi

echo "Success: Post-command executed correctly."

echo "Testing multiple --post-command options..."
IMAGE_TAG2="pixitainer-test:post-cmd-multi"
docker rmi -f "$IMAGE_TAG2" > /dev/null 2>&1 || true

OUTPUT_LOG="post_cmd_multi_log.txt"
set +e
$PIXI_CMD -o "$IMAGE_TAG2" \
    --post-command "echo 'first' > /opt/cmd1.txt" \
    --post-command "echo 'second' > /opt/cmd2.txt" \
    --no-install > "$OUTPUT_LOG" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
    cat "$OUTPUT_LOG"
    exit $EXIT_CODE
fi

# Verify log indicates multiple post-commands
if ! grep -q "Adding post-commands:" "$OUTPUT_LOG"; then
    echo "Error: 'Adding post-commands:' header not found in log."
    cat "$OUTPUT_LOG"
    exit 1
fi

CMD1=$(docker run --rm "$IMAGE_TAG2" cat /opt/cmd1.txt)
CMD2=$(docker run --rm "$IMAGE_TAG2" cat /opt/cmd2.txt)

if [ "$CMD1" != "first" ]; then
    echo "Error: First post-command output mismatch. Expected 'first', got '$CMD1'."
    exit 1
fi

if [ "$CMD2" != "second" ]; then
    echo "Error: Second post-command output mismatch. Expected 'second', got '$CMD2'."
    exit 1
fi

echo "Success: Multiple post-commands verified."

docker rmi -f "$IMAGE_TAG" "$IMAGE_TAG2" > /dev/null 2>&1 || true
