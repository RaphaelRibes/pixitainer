#!/bin/bash
set -e

BATCH_SIZE=4
RESUME=0
TOOL="apptainer"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--batch-size) BATCH_SIZE="$2"; shift ;;
        -r|--resume) RESUME=1 ;;
        -t|--tool) TOOL="$2"; shift ;;
        -h|--help) echo "Usage: $0 [-b <batch_size>] [-r|--resume] [-t|--tool apptainer|singularity]"; exit 0 ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [[ "$TOOL" != "apptainer" && "$TOOL" != "singularity" ]]; then
    echo "Error: --tool must be 'apptainer' or 'singularity'."
    exit 1
fi

# --- Configuration ---
TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"

if [[ "$TOOL" == "singularity" ]]; then
    TOOL_SCRIPT="$(cd "$(dirname "$0")/.." && pwd -P)/pixi-containerize-singularity"
    CONTAINER_CMD="singularity"
else
    TOOL_SCRIPT="$(cd "$(dirname "$0")/.." && pwd -P)/pixi-containerize"
    CONTAINER_CMD="pixi run -m $(cd "$(dirname "$0")/.." && pwd -P)/pixi.toml apptainer"
fi

# Base directory for individual test workspaces
BASE_WORK_DIR="${TESTS_DIR}/test_workspaces"
SHARED_REPO_DIR="${TESTS_DIR}/TestRepo"

# Export for sub-scripts
export TOOL_SCRIPT
export CONTAINER_CMD

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[0;34m'

# Clean previous workspaces
if [ "$RESUME" -eq 1 ] && [ -d "$BASE_WORK_DIR" ]; then
    echo -e "${BLUE}ℹ️  Resuming previous run, skipping already passed tests...${NC}"
else
    rm -rf "$BASE_WORK_DIR"
fi
mkdir -p "$BASE_WORK_DIR"
STATE_DIR="${BASE_WORK_DIR}/.state"
mkdir -p "$STATE_DIR"

# --- Pre-cache Base Images ---
# Prevents race conditions when multiple tests pull ubuntu:24.04 simultaneously
echo -e "${BLUE}ℹ️  Pre-caching base images...${NC}"
if [[ "$TOOL" == "singularity" ]] && command -v singularity &> /dev/null; then
    singularity pull --force "$BASE_WORK_DIR/warmup_24.sif" docker://ubuntu:24.04 > /dev/null 2>&1
    singularity pull --force "$BASE_WORK_DIR/warmup_22.sif" docker://ubuntu:22.04 > /dev/null 2>&1
    rm -f "$BASE_WORK_DIR"/warmup_*.sif
elif command -v apptainer &> /dev/null; then
    apptainer pull --force "$BASE_WORK_DIR/warmup_24.sif" docker://ubuntu:24.04 > /dev/null 2>&1
    apptainer pull --force "$BASE_WORK_DIR/warmup_22.sif" docker://ubuntu:22.04 > /dev/null 2>&1
    rm -f "$BASE_WORK_DIR"/warmup_*.sif
fi

echo -e "${GREEN}Starting Parallel Test Suite (Shared Repo Mode)...${NC}"

# --- Setup Shared Base Repository Stub ---
echo "Initializing isolated base repository..."
rm -rf "$SHARED_REPO_DIR"
mkdir -p "$SHARED_REPO_DIR"
(
    cd "$SHARED_REPO_DIR"
    if [ ! -f "pixi.toml" ]; then
        pixi init .
        pixi add python
        
        # Write a test file to be copied
        echo "test" > test.txt
    else
        echo "Base repository already initialized."
    fi
)

# Ensure the tool is executable
chmod +x "$TOOL_SCRIPT"

# Define the PIXI_CMD with the -p argument pointing to the test repo copy.
# Will be evaluated inside run_test_isolated
if [[ "$TOOL" == "singularity" ]]; then
    # Singularity is a system command, no need to run through pixi
    export PIXI_CMD_TEMPLATE="$TOOL_SCRIPT -p"
else
    export PIXI_CMD_TEMPLATE="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p"
fi

# PIDs array to keep track of background processes
pids=()
declare -A pid_map

# Function to run a test in its own output folder
run_test_isolated() {
    TEST_SCRIPT_NAME=$1

    if [ "$RESUME" -eq 1 ] && [ -f "${STATE_DIR}/${TEST_SCRIPT_NAME}.passed" ]; then
        echo -e "${GREEN}>>> SKIP (ALREADY PASSED): $TEST_SCRIPT_NAME${NC}"
        return 0
    fi

    # Create an empty directory for this test's output
    TEST_DIR="${BASE_WORK_DIR}/${TEST_SCRIPT_NAME%.sh}"

    # Wipe and recreate the test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    
    # Copy the cached isolated stub repository to the test sandbox to avoid re-resolving python every time
    cp -r "$SHARED_REPO_DIR"/* "$TEST_DIR"/
    if [ -d "$SHARED_REPO_DIR"/.pixi ]; then
        cp -r "$SHARED_REPO_DIR"/.pixi "$TEST_DIR"/
    fi

    (
        # Set REPO_DIR to the populated test folder.
        export REPO_DIR="$TEST_DIR"
        export PIXI_CMD="$PIXI_CMD_TEMPLATE $TEST_DIR"

        LOG_FILE="${TEST_DIR}/test.log"

        # Execute the test script from the tests directory
        cd "$TESTS_DIR"

        if ./$TEST_SCRIPT_NAME > "$LOG_FILE" 2>&1; then
            echo -e "${GREEN}>>> PASS: $TEST_SCRIPT_NAME${NC}"
            touch "${STATE_DIR}/${TEST_SCRIPT_NAME}.passed"
            exit 0
        else
            if grep -qE "Failed to create mount namespace|Failed to create user namespace" "$LOG_FILE"; then
                echo -e "${BLUE}>>> SKIP: $TEST_SCRIPT_NAME (namespace restriction detected)${NC}"
                touch "${STATE_DIR}/${TEST_SCRIPT_NAME}.passed"
                exit 0
            fi
            echo -e "${RED}>>> FAIL: $TEST_SCRIPT_NAME${NC}"
            echo -e "${RED}    See logs at: $LOG_FILE${NC}"
            exit 1
        fi
    )
}

# --- Launch Tests ---
TESTS_TO_RUN=(
    "test_defaults.sh"
    "test_latest.sh"
    "test_label.sh"
    "test_seamless.sh"
    "test_env.sh"
    "test_base_image.sh"
    "test_pixi_version.sh"
    "test_keep_def.sh"
    "test_dry_run.sh"
    "test_post_cmd.sh"
    "test_add_file.sh"
    "test_pyproject.sh"
    "test_toml_options.sh"
    "test_toml_advanced.sh"
    "test_toml_versioning.sh"
    "test_toml_path.sh"
)

# --- Wait for completion ---
echo -e "\n${BLUE}Executing tests in batches of ${BATCH_SIZE}...${NC}\n"

FAIL_COUNT=0
pids=()

for TEST_SCRIPT in "${TESTS_TO_RUN[@]}"; do
    run_test_isolated "$TEST_SCRIPT" &
    pids+=($!)

    if [[ ${#pids[@]} -ge $BATCH_SIZE ]]; then
        for pid in "${pids[@]}"; do
            wait "$pid" || ((FAIL_COUNT++))
        done
        pids=()
    fi
done

for pid in "${pids[@]}"; do
    wait "$pid" || ((FAIL_COUNT++))
done

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    rm -rf "$BASE_WORK_DIR"
else
    echo -e "${RED}$FAIL_COUNT tests failed.${NC}"
    exit 1
fi