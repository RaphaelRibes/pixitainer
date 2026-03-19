#!/bin/bash
set -e

cd "$REPO_DIR"

# Cleanup previous isolated run, if any
rm -rf .gitignore .pixi pixitainer.sif toml_test.sif pixi.toml

echo "Initializing simple pixi project for TOML testing..."
# Create an isolated project
pixi init .
pixi add python

# Append the pixitainer config options to the generated pixi.toml
cat << 'EOF' >> pixi.toml

[tool.pixitainer]
output = "toml_test.sif"
base-image = "ubuntu:24.04"
add-file = ["test_file.txt:/opt/test_file.txt"]
post-command = ["echo 'Hello from post-command' > /opt/post_cmd.txt"]
label = ["APP_VERSION:1.2.3"]
env = ["default"]
quiet = "True"
EOF

# Create a sample file to inject
echo "Validating add-file works." > test_file.txt

echo "Building container from TOML configuration..."
# Override PIXI_CMD to use this new isolated project directory instead of RaMiLass
export PIXI_CMD="pixi run -m $(dirname "$TOOL_SCRIPT")/pixi.toml -- $TOOL_SCRIPT -p $REPO_DIR"

# Run without any extra CLI args - it should fully leverage the TOML config
$PIXI_CMD

if [ ! -f "toml_test.sif" ]; then
    echo "Error: toml_test.sif not found. TOML options were not applied."
    exit 1
fi

echo "Verifying container image..."

echo " -> Verifying Python is installed..."
$CONTAINER_CMD run toml_test.sif pixi run --as-is python --version | grep "Python 3."

echo " -> Verifying add-file..."
$CONTAINER_CMD run toml_test.sif cat /opt/test_file.txt | grep "Validating add-file works"

echo " -> Verifying post-command..."
$CONTAINER_CMD run toml_test.sif cat /opt/post_cmd.txt | grep "Hello from post-command"

echo " -> Verifying custom labels..."
$CONTAINER_CMD inspect toml_test.sif | grep -i "APP_VERSION" | grep "1.2.3"

echo "All TOML configuration bounds verified successfully."
