#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_TAG="pixitainer-test:keep-def"
# The script sanitises the tag to derive the filename:
# "pixitainer-test:keep-def" -> "Dockerfile.pixitainer-test_keep-def"
EXPECTED_DOCKERFILE="Dockerfile.pixitainer-test_keep-def"

docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
rm -f "$EXPECTED_DOCKERFILE"

echo "Testing --keep-def option..."
$PIXI_CMD -o "$IMAGE_TAG" --keep-def

if ! docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    echo "Error: Image $IMAGE_TAG was not created."
    exit 1
fi

if [ ! -f "$EXPECTED_DOCKERFILE" ]; then
    echo "Error: Dockerfile was NOT preserved at $EXPECTED_DOCKERFILE"
    ls -la Dockerfile.* 2>/dev/null || true
    exit 1
fi

echo "Success: Dockerfile preserved at $EXPECTED_DOCKERFILE"

# Verify the Dockerfile contains expected Docker instructions
if ! grep -q "^FROM " "$EXPECTED_DOCKERFILE"; then
    echo "Error: Dockerfile missing FROM instruction."
    exit 1
fi

if ! grep -q "^RUN" "$EXPECTED_DOCKERFILE"; then
    echo "Error: Dockerfile missing RUN instruction."
    exit 1
fi

if ! grep -q "^ENTRYPOINT" "$EXPECTED_DOCKERFILE"; then
    echo "Error: Dockerfile missing ENTRYPOINT instruction."
    exit 1
fi

echo "Verifying Python inside container..."
CONTAINER_PYTHON=$(docker run --rm "$IMAGE_TAG" pixi run --as-is python --version)
if [[ ! "$CONTAINER_PYTHON" =~ "Python 3." ]]; then
    echo "Error: Container does not have expected Python version. Got: $CONTAINER_PYTHON"
    exit 1
fi

echo "Success: --keep-def verified (Dockerfile saved and image works)."

# Cleanup
rm -f "$EXPECTED_DOCKERFILE"
docker rmi -f "$IMAGE_TAG" > /dev/null 2>&1 || true
