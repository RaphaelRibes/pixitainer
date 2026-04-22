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
# Requires: BOOTSTRAP_SH (set by the entrypoint before calling sif_main)
# ---------------------------------------------------------------------------
build_sif_files_section() {
    FILES_SECTION="    \"$BOOTSTRAP_SH\" /opt/bootstrap.sh"
    FILES_SECTION+=$'\n'"    \"$MANIFEST_SRC\" $MANIFEST_DEST"
    if [ -f "$PIXI_LOCK" ]; then
        FILES_SECTION+=$'\n'"    \"$PIXI_LOCK\" /opt/conf/pixi.lock"
    fi

    local count=${#EXTRA_FILES[@]}
    [ "$count" -eq 0 ] && return
    [ "$count" -gt 1 ] && log "ℹ️ Adding files:"

    local file_spec src dest label
    for file_spec in "${EXTRA_FILES[@]}"; do
        if [[ "$file_spec" == *":"* ]]; then
            src="${file_spec%%:*}"
            dest="${file_spec#*:}"
            label="$src -> $dest"
            FILES_SECTION+=$'\n'"    \"$src\" \"$dest\""
        else
            label="$file_spec"
            FILES_SECTION+=$'\n'"    \"$file_spec\""
        fi
        if [ "$count" -eq 1 ]; then
            log "ℹ️ Adding file: $label"
        else
            log "      - $label"
        fi
    done
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
    . /opt/bootstrap.sh

    echo "STEP: Installing system prerequisites and Pixi"
    bootstrap_install

    $PIXI_VERSION_CMD

    mkdir -p /opt/conf
    cd /opt/conf

    echo "STEP: Installing the environment"
    pixi config set --local run-post-link-scripts insecure
    $INSTALL_CMD

    $(if [ ${#POST_COMMANDS[@]} -gt 0 ]; then
        echo "echo \"STEP: Running extra post commands\""
        printf '    %s\n' "${POST_COMMANDS[@]}"
    fi)

    echo "STEP: Cleaning"
    bootstrap_cleanup

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
            rm -f "$BUILD_LOG_FILE"
            exit 1
        fi
        rm -f "$BUILD_LOG_FILE"
    fi

    log "✅ Success! Image built at: $OUTPUT_ABS"
}

# ---------------------------------------------------------------------------
# Dry-run handler for SIF builds: if DRY_RUN, print the .def and exit 0.
# ---------------------------------------------------------------------------
sif_dry_run_check() {
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

# ---------------------------------------------------------------------------
# Shared entry point for the Apptainer and Singularity entrypoint scripts.
# Usage: sif_main BACKEND "$@"
#   BACKEND ∈ {apptainer, singularity}
# The caller must:
#   - source common.sh and sif.sh before calling,
#   - define a `usage` function (invoked by parse_common_args on -h),
#   - set BOOTSTRAP_SH to the absolute host path of lib/bootstrap.sh.
# ---------------------------------------------------------------------------
sif_main() {
    BACKEND="$1"; shift

    init_common_defaults
    detect_base_image

    pre_parse_path "$@"
    find_pre_manifest
    read_toml_config "$BACKEND" "$PRE_MANIFEST_SRC"

    parse_common_args "$@"
    if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
        echo "Error: Unknown option: ${REMAINING_ARGS[0]}"
        usage
        exit 1
    fi

    validate_common_args

    # Apply default output path after TOML + CLI have both been parsed.
    # Must sit here so TOML/CLI overrides take priority.
    OUTPUT="${OUTPUT:-pixitainer.sif}"

    resolve_manifest
    resolve_sif_paths

    log "📦 Containerizing project from: $WD"
    log "📂 Output target: $OUTPUT_ABS"

    build_sif_files_section
    build_install_cmd
    build_sif_runscript
    resolve_pixi_version
    log_labels
    format_sif_labels
    log_post_commands
    generate_def_file

    sif_dry_run_check

    run_sif_build "$BACKEND"

    sif_final_cleanup
}
