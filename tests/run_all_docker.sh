#!/bin/bash
set -e

BATCH_SIZE=4
RESUME=0

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|--batch-size) BATCH_SIZE="$2"; shift ;;
        -r|--resume) RESUME=1 ;;
        -h|--help) echo "Usage: $0 [-b <batch_size>] [-r|--resume]"; exit 0 ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# --- Configuration ---
TESTS_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# Allow env var override from CI
if [ -z "$TOOL_SCRIPT" ]; then
    TOOL_SCRIPT="$(cd "$(dirname "$0")/.." && pwd -P)/pixi-containerize-docker"
fi
export TOOL_SCRIPT

if [ -z "$CONTAINER_CMD" ]; then
    CONTAINER_CMD="pixi run docker"
fi
export CONTAINER_CMD

BASE_WORK_DIR="${TESTS_DIR}/test_workspaces_docker"
SHARED_REPO_DIR="${TESTS_DIR}/TestRepoDocker"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BLUE='\033[0;34m'

# --- Preflight checks ---
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker daemon is not running."
    exit 1
fi

# --- Clean / resume ---
if [ "$RESUME" -eq 1 ] && [ -d "$BASE_WORK_DIR" ]; then
    echo -e "${BLUE}ℹ️  Resuming previous run, skipping already-passed tests...${NC}"
else
    rm -rf "$BASE_WORK_DIR"
fi
mkdir -p "$BASE_WORK_DIR"
STATE_DIR="${BASE_WORK_DIR}/.state"
mkdir -p "$STATE_DIR"

# --- Pre-pull base images to avoid race conditions ---
echo -e "${BLUE}ℹ️  Pre-pulling base images...${NC}"
docker pull ubuntu:24.04 > /dev/null 2>&1 || true
docker pull ubuntu:22.04 > /dev/null 2>&1 || true

echo -e "${GREEN}Starting Docker Test Suite (Parallel, Shared Repo Mode)...${NC}"

# --- Setup shared base repo ---
echo "Initializing shared base repository..."
rm -rf "$SHARED_REPO_DIR"
mkdir -p "$SHARED_REPO_DIR"
(
    cd "$SHARED_REPO_DIR"
    pixi init .
    pixi add python
    echo "test" > test.txt
)

chmod +x "$TOOL_SCRIPT"

# Call the script directly — no pixi run wrapper needed.
# Wrapping with "pixi run -m <parent>/pixi.toml" causes pixi to pick up the
# workspace build manifest and trigger a full conda package build instead of
# simply executing the shell script.
# Can be overridden via env var (e.g. in CI, call scripts directly).
if [ -z "$PIXI_CMD_TEMPLATE" ]; then
    export PIXI_CMD_TEMPLATE="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml $TOOL_SCRIPT -p"
fi

# --- Test runner ---
run_test_isolated() {
    TEST_SCRIPT_NAME=$1

    if [ "$RESUME" -eq 1 ] && [ -f "${STATE_DIR}/${TEST_SCRIPT_NAME}.passed" ]; then
        echo -e "${GREEN}>>> SKIP (ALREADY PASSED): $TEST_SCRIPT_NAME${NC}"
        return 0
    fi

    TEST_DIR="${BASE_WORK_DIR}/${TEST_SCRIPT_NAME%.sh}"
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"

    cp -r "$SHARED_REPO_DIR"/* "$TEST_DIR"/
    if [ -d "$SHARED_REPO_DIR/.pixi" ]; then
        cp -r "$SHARED_REPO_DIR/.pixi" "$TEST_DIR/"
    fi

    (
        export REPO_DIR="$TEST_DIR"
        export PIXI_CMD="$PIXI_CMD_TEMPLATE $TEST_DIR"
        LOG_FILE="${TEST_DIR}/test.log"

        cd "$TESTS_DIR"

        if ./$TEST_SCRIPT_NAME > "$LOG_FILE" 2>&1; then
            echo -e "${GREEN}>>> PASS: $TEST_SCRIPT_NAME${NC}"
            touch "${STATE_DIR}/${TEST_SCRIPT_NAME}.passed"
            exit 0
        else
            echo -e "${RED}>>> FAIL: $TEST_SCRIPT_NAME${NC}"
            echo -e "${RED}    See logs at: $LOG_FILE${NC}"
            exit 1
        fi
    )
}

TESTS_TO_RUN=(
    # --- Original tests ---
    "test_docker_defaults.sh"
    "test_docker_latest.sh"
    "test_docker_label.sh"
    "test_docker_seamless.sh"
    "test_docker_env.sh"
    "test_docker_base_image.sh"
    "test_docker_pixi_version.sh"
    "test_docker_keep_def.sh"
    "test_docker_dry_run.sh"
    "test_docker_post_cmd.sh"
    "test_docker_add_file.sh"
    "test_docker_tool_mode.sh"
    "test_docker_pyproject.sh"
    "test_docker_toml_options.sh"
    "test_docker_toml_advanced.sh"
    "test_docker_toml_versioning.sh"
    "test_docker_toml_path.sh"
    "test_docker_no_cache.sh"
    "test_docker_platform.sh"
    "test_docker_build_arg.sh"
    "test_docker_extra_tag.sh"
    "test_docker_save.sh"
    "test_docker_network.sh"
    "test_docker_user.sh"
    "test_docker_workdir.sh"
    "test_docker_squash.sh"
    "test_docker_secret.sh"
    "test_docker_cache.sh"
    "test_docker_ssh.sh"
)

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

# --- Cleanup test images ---
echo -e "\n${BLUE}ℹ️  Cleaning up test Docker images...${NC}"
docker images --format '{{.Repository}}:{{.Tag}}' | grep '^pixitainer-test:' | xargs -r docker rmi -f > /dev/null 2>&1 || true

echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
    rm -rf "$BASE_WORK_DIR"
else
    echo -e "${RED}$FAIL_COUNT test(s) failed.${NC}"
    exit 1
fi
