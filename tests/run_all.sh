#!/bin/bash
set -e

# --- Configuration ---
REPO_URL="https://github.com/MickaelCQ/RaMiLass.git"
TOOL_SCRIPT="$(pwd -P)/../pixi-containerize" # Assumes the python script is in the current dir

# Export for sub-scripts
export TOOL_SCRIPT
export REPO_DIR="RaMiLass"

# --- Colors for output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Test Suite for Pixitainer...${NC}"

# --- Setup Workspace ---
echo "Cloning repository..."
if [ -d "$REPO_DIR" ]; then
    echo "Repository already cloned."
else
    echo "Cloning repository into $REPO_DIR..."
    git clone "$REPO_URL" "$REPO_DIR"
fi
# Ensure the tool is executable
chmod +x "$TOOL_SCRIPT"

# --- Run Tests ---
# We pass the python interpreter explicitly to ensure compatibility
export PIXI_CMD="pixi run -m $(pwd -P)/../pixi.toml $TOOL_SCRIPT"

run_test() {
    TEST_SCRIPT=$1
    echo -e "\n${GREEN}>>> Running: $TEST_SCRIPT${NC}"
    if ./$TEST_SCRIPT; then
        echo -e "${GREEN}>>> PASS: $TEST_SCRIPT${NC}"
    else
        echo -e "${RED}>>> FAIL: $TEST_SCRIPT${NC}"
        exit 1
    fi
}

run_test "test_defaults.sh"
run_test "test_output.sh"
run_test "test_seamless.sh"
run_test "test_env.sh"
run_test "test_base_image.sh"
run_test "test_pixi_version.sh"
run_test "test_keep_def.sh"
run_test "test_verbose.sh"

echo -e "\n${GREEN}All tests passed successfully!${NC}"