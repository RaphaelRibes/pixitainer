#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:label"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true

echo "Testing -l/--label option..."
$PIXI_CMD -o "$IMAGE_TAG" -l MY_LABEL:HelloWorld -l SECOND_LABEL:123

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

echo "Verifying labels in the image..."
LABELS_OUTPUT=$(docker inspect --format '{{json .Config.Labels}}' "$IMAGE_TAG")

if ! echo "$LABELS_OUTPUT" | grep -q "HelloWorld"; then
    echo "Error: MY_LABEL:HelloWorld not found in image labels."
    echo "Labels output: $LABELS_OUTPUT"
    exit 1
fi

if ! echo "$LABELS_OUTPUT" | grep -q "123"; then
    echo "Error: SECOND_LABEL:123 not found in image labels."
    echo "Labels output: $LABELS_OUTPUT"
    exit 1
fi

# Also verify the built-in pixitainer labels are present
if ! echo "$LABELS_OUTPUT" | grep -q "Pixitainer"; then
    echo "Error: Built-in Pixitainer label not found."
    echo "Labels output: $LABELS_OUTPUT"
    exit 1
fi

echo "Success: All labels correctly found in image."

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
