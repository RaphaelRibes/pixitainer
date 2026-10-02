#!/bin/bash
set -e

cd "$REPO_DIR"
IMAGE_NAME="push_test.sif"

# Cleanup potential leftovers
rm -rf .tmp_pixitainer_apptainer .tmp_pixitainer_singularity
rm -f "$IMAGE_NAME"

echo "Testing --push without a URI (should error)..."
if $PIXI_CMD -o "$IMAGE_NAME" --push > /dev/null 2>&1; then
    echo "Error: --push without a URI should have failed"
    exit 1
fi
echo "Success: --push without URI correctly errors"
# The error happens after the build (push is a post-build step), so a stale
# image may now exist. Remove it so the dry-run assertions below test a clean slate.
rm -f "$IMAGE_NAME"

echo "Testing --push with a URI in dry-run (should not build, not push)..."
DEF_OUTPUT=$($PIXI_CMD -o "$IMAGE_NAME" --push oras://localhost:5000/test:latest --dry-run)

# Image must NOT be built
if [ -f "$IMAGE_NAME" ]; then
    echo "Error: Image was built despite --dry-run + --push"
    exit 1
fi
echo "Success: Image was NOT built (as expected)"

# The .def content should still be present
if [[ ! "$DEF_OUTPUT" =~ "Bootstrap: docker" ]]; then
    echo "Error: Definition file content not found in stdout"
    exit 1
fi
echo "Success: Definition file content correctly output to stdout"

echo "Testing --no-fakeroot in dry-run (build command should omit --fakeroot)..."
# The dry-run only prints the .def, not the build command, so verify the flag parses
# without error and the image is not built.
if $PIXI_CMD -o "$IMAGE_NAME" --no-fakeroot --dry-run > /dev/null 2>&1; then
    echo "Success: --no-fakeroot parses correctly"
else
    echo "Error: --no-fakeroot failed to parse"
    exit 1
fi

if [ -f "$IMAGE_NAME" ]; then
    echo "Error: Image was built despite --dry-run + --no-fakeroot"
    exit 1
fi
echo "Success: Image was NOT built (as expected)"

echo "Testing --arch in dry-run (should parse and not build)..."
if $PIXI_CMD -o "$IMAGE_NAME" --arch arm64 --dry-run > /dev/null 2>&1; then
    echo "Success: --arch parses correctly"
else
    echo "Error: --arch failed to parse"
    exit 1
fi

if [ -f "$IMAGE_NAME" ]; then
    echo "Error: Image was built despite --dry-run + --arch"
    exit 1
fi
echo "Success: Image was NOT built (as expected)"

echo "Testing --build-arg in dry-run (should parse and not build)..."
if $PIXI_CMD -o "$IMAGE_NAME" --build-arg VERSION=1.2.3 --dry-run > /dev/null 2>&1; then
    echo "Success: --build-arg parses correctly"
else
    echo "Error: --build-arg failed to parse"
    exit 1
fi

if [ -f "$IMAGE_NAME" ]; then
    echo "Error: Image was built despite --dry-run + --build-arg"
    exit 1
fi
echo "Success: Image was NOT built (as expected)"

echo "Testing --env-var + --env-file in dry-run (should appear in %environment)..."
printf 'FILE_MODE=prod\n# skipped comment\n' > myvars.env
ENV_OUT=$($PIXI_CMD -o "$IMAGE_NAME" --env-var CLI_COLOR=blue --env-file myvars.env --dry-run 2>&1)

if ! echo "$ENV_OUT" | grep -q 'export CLI_COLOR="blue"'; then
    echo "Error: --env-var not found in %environment"
    echo "Got: $ENV_OUT"
    exit 1
fi
if ! echo "$ENV_OUT" | grep -q 'export FILE_MODE="prod"'; then
    echo "Error: --env-file var not found in %environment"
    exit 1
fi
if echo "$ENV_OUT" | grep -q "skipped comment"; then
    echo "Error: comment line was not skipped"
    exit 1
fi
echo "Success: env vars correctly injected into %environment"

echo "Testing that --env-var does NOT select pixi environments (distinct from -e/--env)..."
if ! $PIXI_CMD -o "$IMAGE_NAME" --env-var FOO=bar --dry-run > /dev/null 2>&1; then
    echo "Error: --env-var should not conflict with environment selection"
    exit 1
fi
echo "Success: --env-var is distinct from -e/--env"

echo "Testing --gpu in dry-run (SIF adds GPU label + --nv hint)..."
GPU_OUT=$($PIXI_CMD -o "$IMAGE_NAME" --gpu --dry-run 2>&1)
if ! echo "$GPU_OUT" | grep -q "Pixitainer_GPU true"; then
    echo "Error: --gpu did not add the Pixitainer_GPU label"
    exit 1
fi
echo "Success: --gpu adds the GPU label"

echo "Testing --cache-dir in dry-run (parses and adds %setup block)..."
CACHE_OUT=$($PIXI_CMD -o "$IMAGE_NAME" --cache-dir ./.pixitainer-cache --dry-run 2>&1)
if ! echo "$CACHE_OUT" | grep -q '%setup'; then
    echo "Error: --cache-dir did not add the %setup block for the bind mount"
    exit 1
fi
echo "Success: --cache-dir adds %setup mount block"

# Cleanup
rm -f myvars.env
rm -rf .tmp_pixitainer_apptainer .tmp_pixitainer_singularity
rm -f "$IMAGE_NAME"
echo "All push/fakeroot/arch/build-arg/env/gpu/cache tests passed."
