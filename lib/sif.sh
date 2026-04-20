#!/bin/bash
# sif.sh — Shared functions for SIF-based backends (Apptainer & Singularity).
# Sourced after common.sh by pixi-containerize and pixi-containerize-singularity.
# shellcheck disable=SC2034

# ---------------------------------------------------------------------------
# Resolve output paths for SIF builds.
# Sets: OUTPUT_ABS, OUTPUT_PARENT, TMP_DIR
# ---------------------------------------------------------------------------
resolve_sif_paths() {
    local output_dir
    output_dir=$(dirname "$OUTPUT")
    if [[ "$output_dir" == "." ]]; then
        OUTPUT_ABS="$(pwd -P)/$OUTPUT"
        OUTPUT_PARENT="$(pwd -P)"
    else
        mkdir -p "$output_dir"
        OUTPUT_ABS="$(cd "$output_dir" && pwd -P)/$(basename "$OUTPUT")"
        OUTPUT_PARENT="$(cd "$output_dir" && pwd -P)"
    fi
    TMP_DIR="$OUTPUT_PARENT/.tmp_pixitainer"
}

# ---------------------------------------------------------------------------
# Build the %files section for the .def file.
# Sets: FILES_SECTION
# ---------------------------------------------------------------------------
build_sif_files_section() {
    FILES_SECTION="    \"$MANIFEST_SRC\" $MANIFEST_DEST"
    if [ -f "$PIXI_LOCK" ]; then
        FILES_SECTION="$FILES_SECTION"$'\n'"    \"$PIXI_LOCK\" /opt/conf/pixi.lock"
    fi

    if [ ${#EXTRA_FILES[@]} -eq 1 ]; then
        local file_spec="${EXTRA_FILES[0]}"
        if [[ "$file_spec" == *":"* ]]; then
            local src="${file_spec%%:*}" dest="${file_spec#*:}"
            log "ℹ️ Adding file: $src -> $dest"
            FILES_SECTION="$FILES_SECTION"$'\n'"    \"$src\" \"$dest\""
        else
            log "ℹ️ Adding file: $file_spec"
            FILES_SECTION="$FILES_SECTION"$'\n'"    \"$file_spec\""
        fi
    elif [ ${#EXTRA_FILES[@]} -gt 1 ]; then
        log "ℹ️ Adding files:"
        for file_spec in "${EXTRA_FILES[@]}"; do
            if [[ "$file_spec" == *":"* ]]; then
                local src="${file_spec%%:*}" dest="${file_spec#*:}"
                log "      - $src -> $dest"
                FILES_SECTION="$FILES_SECTION"$'\n'"    \"$src\" \"$dest\""
            else
                log "      - $file_spec"
                FILES_SECTION="$FILES_SECTION"$'\n'"    \"$file_spec\""
            fi
        done
    fi
}

# ---------------------------------------------------------------------------
# Format custom labels for the .def %labels section.
# Sets: CUSTOM_LABELS_SECTION
# ---------------------------------------------------------------------------
format_sif_labels() {
    CUSTOM_LABELS_SECTION=""
    for label in "${LABELS[@]}"; do
        local formatted_label="${label/:/ }"
        CUSTOM_LABELS_SECTION="$CUSTOM_LABELS_SECTION"$'\n'"    $formatted_label"
    done
}

# ---------------------------------------------------------------------------
# Build the seamless / non-seamless runscript content.
# Sets: RUNSCRIPT_CONTENT
# ---------------------------------------------------------------------------
build_sif_runscript() {
    if [ "$SEAMLESS" = true ]; then
        log "ℹ️ Seamless mode enabled"
        RUNSCRIPT_CONTENT="pixi run --locked --as-is -m $MANIFEST_DEST \"\$@\""
    else
        RUNSCRIPT_CONTENT='exec "$@"'
    fi
}

# ---------------------------------------------------------------------------
# Generate the .def definition file.
# Sets: TARGET_DEF
# ---------------------------------------------------------------------------
generate_def_file() {
    mkdir -p "$TMP_DIR"
    local def_name
    def_name="$(basename "${OUTPUT%.*}").def"
    TARGET_DEF="$TMP_DIR/$def_name"

    cat <<EOF > "$TARGET_DEF"
Bootstrap: docker
From: $BASE_IMAGE

%labels
    Created_With Pixitainer (https://github.com/RaphaelRibes/pixitainer)
    Pixitainer_Version $PIXITAINER_VERSION
    Pixi_Version $PIXI_VERSION$CUSTOM_LABELS_SECTION

%files
$FILES_SECTION

%environment
    export PIXI_HOME=/opt/pixi
    export PIXI_DIR=/opt/pixi
    export PIXI_PROJECT_MANIFEST=$MANIFEST_DEST
    export PATH="/opt/pixi/bin:\$PATH"

%post
    export DEBIAN_FRONTEND=noninteractive

    # 1. Install system dependencies
    echo "STEP: Updating the image"
    MISSING_PKGS=""
    if ! command -v curl >/dev/null 2>&1; then MISSING_PKGS="curl ca-certificates"; fi
    if ! command -v bash >/dev/null 2>&1; then MISSING_PKGS="\$MISSING_PKGS bash"; fi
    
    if [ -n "\$MISSING_PKGS" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            export DEBIAN_FRONTEND=noninteractive
            apt-get update && apt-get install -y --no-install-recommends \$MISSING_PKGS
            PKGMGR="apt"
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm \$MISSING_PKGS
            PKGMGR="pacman"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y \$MISSING_PKGS
            PKGMGR="dnf"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y \$MISSING_PKGS
            PKGMGR="yum"
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache \$MISSING_PKGS
            PKGMGR="apk"
        elif command -v zypper >/dev/null 2>&1; then
            zypper in -y \$MISSING_PKGS
            PKGMGR="zypper"
        else
            echo "Error: No known package manager found"
            exit 1
        fi
    fi

    # 2. Install Pixi globally to /opt/pixi
    export PIXI_HOME=/opt/pixi
    export PIXI_DIR=/opt/pixi
    echo "STEP: Downloading Pixi"
    curl -fsSL https://pixi.sh/install.sh | bash
    export PATH="/opt/pixi/bin:\$PATH"

    $PIXI_VERSION_CMD

    # 3. Setup the Project Environment
    mkdir -p /opt/conf
    cd /opt/conf

    echo "STEP: Installing the environment"
    pixi config set --local run-post-link-scripts insecure
    $INSTALL_CMD

    # 3.5 Run extra post commands
    $(if [ ${#POST_COMMANDS[@]} -gt 0 ]; then
        echo "echo \"STEP: Running extra post commands\""
        printf '    %s\n' "${POST_COMMANDS[@]}"
    fi)

    # 4. Cleanup
    echo "STEP: Cleaning"
    if [ -n "\$PKGMGR" ]; then
        if echo "\$MISSING_PKGS" | grep -q "curl"; then
            if [ "\$PKGMGR" = "apt" ]; then
                apt-get remove -y curl && apt-get autoremove -y
            elif [ "\$PKGMGR" = "pacman" ]; then
                pacman -Rns --noconfirm curl || true
            elif [ "\$PKGMGR" = "dnf" ] || [ "\$PKGMGR" = "yum" ]; then
                \$PKGMGR remove -y curl
            elif [ "\$PKGMGR" = "apk" ]; then
                apk del curl
            elif [ "\$PKGMGR" = "zypper" ]; then
                zypper rm -y curl
            fi
        fi
        
        if [ "\$PKGMGR" = "apt" ]; then
            apt-get clean && rm -rf /var/lib/apt/lists/*
        elif [ "\$PKGMGR" = "pacman" ]; then
            pacman -Scc --noconfirm || true
        elif [ "\$PKGMGR" = "dnf" ] || [ "\$PKGMGR" = "yum" ]; then
            \$PKGMGR clean all
        elif [ "\$PKGMGR" = "zypper" ]; then
            zypper clean
        fi
    fi

%runscript
    cd /opt/conf
    $RUNSCRIPT_CONTENT
EOF
}

# ---------------------------------------------------------------------------
# Step extractor for SIF builds (looks for "STEP: …" markers).
# ---------------------------------------------------------------------------
_sif_step_extractor() {
    local line="$1"
    if [[ "$line" == "STEP: "* ]]; then
        echo "${line#STEP: }"
    fi
}

# ---------------------------------------------------------------------------
# Run the SIF build (apptainer or singularity).
# $1 = binary name ("apptainer" or "singularity")
# ---------------------------------------------------------------------------
run_sif_build() {
    local binary="$1"
    local tool_name
    tool_name="$(tr '[:lower:]' '[:upper:]' <<< "${binary:0:1}")${binary:1}"

    local -a cmd=("$binary" build --force --fakeroot "$OUTPUT_ABS" "$TARGET_DEF")

    log "🚀 Starting $tool_name build..."

    if [ "$QUIET" = true ]; then
        if ! "${cmd[@]}" > /dev/null 2>&1; then
            exit 1
        fi
    elif [ "$VERBOSE" = true ]; then
        "${cmd[@]}"
    else
        if ! run_with_spinner "$tool_name" \
                "Presetup (downloading image, importing files)" \
                _sif_step_extractor \
                "${cmd[@]}"; then

            # Backend-specific error hints
            if [ "$binary" = "apptainer" ] && grep -qiE "conveyor failed to get|manifest unknown" "$BUILD_LOG_FILE"; then
                echo "💡 Hint: Apptainer failed to pull the base image '$BASE_IMAGE'."
                echo "   It may not exist on Docker Hub or requires authentication."
                echo "   Try specifying a valid base image using the '-b' flag."
                echo "   For example: pixi containerize -b ubuntu:24.04"
                echo ""
            fi

            echo "--- LOGS ---"
            cat "$BUILD_LOG_FILE"
            exit 1
        fi
    fi

    log "✅ Success! Image built at: $OUTPUT_ABS"
}

# ---------------------------------------------------------------------------
# Handle dry-run output and cleanup for SIF builds.
# ---------------------------------------------------------------------------
sif_dry_run_or_cleanup() {
    # Dry-run: output .def and exit
    if [ "$DRY_RUN" = true ]; then
        cat "$TARGET_DEF"
        rm -rf "$TMP_DIR"
        exit 0
    fi
}

sif_final_cleanup() {
    if [ "$KEEP_DEF" = true ]; then
        local final_def="$OUTPUT_PARENT/$(basename "${OUTPUT%.*}").def"
        mv "$TARGET_DEF" "$final_def"
        log "ℹ️ Definition file kept at: $final_def"
    fi
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
