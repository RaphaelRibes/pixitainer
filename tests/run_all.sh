#!/bin/bash
set -e

# --- Configuration ---
REPO_URL="https://github.com/MickaelCQ/RaMiLass.git"
TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TOOL_SCRIPT="$(cd "$(dirname "$0")/.." && pwd -P)/pixi-containerize"

# Base directory for individual test workspaces
BASE_WORK_DIR="${TESTS_DIR}/test_workspaces"
SHARED_REPO_DIR="${TESTS_DIR}/RaMiLass"

# Export for sub-scripts
export TOOL_SCRIPT

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[0;34m'

# --- Fix Path Depth Issue ---
# Tests running in 'tests/test_workspaces/test_name' attempt to verify using "$(pwd)/../../pixi.toml".
# Path resolution:
#   pwd     = .../tests/test_workspaces/test_name
#   ../..   = .../tests/
# So the test looks for 'tests/pixi.toml'. We must create the symlink there.

if [ ! -f "${TESTS_DIR}/pixi.toml" ]; then
    echo -e "${BLUE}ℹ️  Creating temporary symlink for verification...${NC}"
    # Link tests/pixi.toml -> ../pixi.toml (Project Root)
    ln -s ../pixi.toml "${TESTS_DIR}/pixi.toml"
    # Trap to remove the symlink on exit (INT and TERM ensure cleanup on Ctrl+C)
    trap 'rm -f "${TESTS_DIR}/pixi.toml"' EXIT INT TERM
fi

# Clean previous workspaces
rm -rf "$BASE_WORK_DIR"
mkdir -p "$BASE_WORK_DIR"

# --- Pre-cache Base Images ---
# Prevents race conditions when multiple tests pull ubuntu:24.04 simultaneously
echo -e "${BLUE}ℹ️  Pre-caching base images...${NC}"
if command -v apptainer &> /dev/null; then
    apptainer pull --force "$BASE_WORK_DIR/warmup_24.sif" docker://ubuntu:24.04 > /dev/null 2>&1
    apptainer pull --force "$BASE_WORK_DIR/warmup_22.sif" docker://ubuntu:22.04 > /dev/null 2>&1
    rm -f "$BASE_WORK_DIR"/warmup_*.sif
fi

echo -e "${GREEN}Starting Parallel Test Suite (Shared Repo Mode)...${NC}"

# --- Setup Shared Repository ---
if [ -d "$SHARED_REPO_DIR" ]; then
    echo "Shared repository already exists at $SHARED_REPO_DIR"
else
    echo "Cloning shared repository..."
    git clone "$REPO_URL" "$SHARED_REPO_DIR"
fi

# Ensure the tool is executable
chmod +x "$TOOL_SCRIPT"

# Define the PIXI_CMD with the -p argument pointing to the shared repo.
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p $SHARED_REPO_DIR"

# PIDs array to keep track of background processes
pids=()
declare -A pid_map

# Function to run a test in its own output folder
run_test_isolated() {
    TEST_SCRIPT_NAME=$1
    # Create an empty directory for this test's output
    TEST_DIR="${BASE_WORK_DIR}/${TEST_SCRIPT_NAME%.sh}"

    # Wipe and recreate the test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"

    (
        # Set REPO_DIR to the empty test folder.
        export REPO_DIR="$TEST_DIR"

        LOG_FILE="${TEST_DIR}/test.log"

        # Execute the test script from the tests directory
        cd "$TESTS_DIR"

        if ./$TEST_SCRIPT_NAME > "$LOG_FILE" 2>&1; then
            echo -e "${GREEN}>>> PASS: $TEST_SCRIPT_NAME${NC}"
        else
            echo -e "${RED}>>> FAIL: $TEST_SCRIPT_NAME${NC}"
            echo -e "${RED}    See logs at: $LOG_FILE${NC}"
            exit 1
        fi
    ) &

    pid=$!
    pids+=($pid)
    pid_map[$pid]=$TEST_SCRIPT_NAME
    echo -e "${BLUE}>>> Started $TEST_SCRIPT_NAME (PID $pid)${NC}"
}

# --- Launch Tests ---
run_test_isolated "test_defaults.sh"
run_test_isolated "test_seamless.sh"
run_test_isolated "test_env.sh"
run_test_isolated "test_base_image.sh"
run_test_isolated "test_pixi_version.sh"
run_test_isolated "test_keep_def.sh"
run_test_isolated "test_post_cmd.sh"
run_test_isolated "test_add_file.sh"

# --- Wait for completion ---
echo -e "\n${BLUE}Waiting for tests to complete...${NC}\n"

FAIL_COUNT=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        ((FAIL_COUNT++))
    fi
done

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    rm -rf "$BASE_WORK_DIR"
else
    echo -e "${RED}$FAIL_COUNT tests failed.${NC}"
    exit 1
fi