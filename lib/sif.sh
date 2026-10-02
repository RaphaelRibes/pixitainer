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
    TMP_DIR="$OUTPUT_PARENT/.tmp_pixitainer_${BACKEND}"
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
    if [ "$GPU" = true ]; then
        CUSTOM_LABELS_SECTION=$'\n'"    Pixitainer_GPU true"
        log "ℹ️ GPU build: run with 'apptainer run --nv' (Apptainer) or Singularity's --nv to use the GPU."
    fi
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
        RUNSCRIPT_CONTENT="pixi run --locked --as-is -m $MANIFEST_DEST \"\$@\""
    else
        log "ℹ️ Manual mode: shell entrypoint (call 'pixi run' yourself)"
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
$(if [ -n "$CACHE_DIR" ]; then printf '\n%%setup\n    mkdir -p "$APPTAINER_ROOTFS/root/.cache"\n'; fi)

%environment
    export PIXI_HOME=/opt/pixi
    export PIXI_DIR=/opt/pixi
    export PIXI_PROJECT_MANIFEST=$MANIFEST_DEST
    export PATH="/opt/pixi/bin:\$PATH"
$(build_env_section "    export ")

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

    if [ "$FAKEROOT" = true ] && ! command -v newuidmap >/dev/null 2>&1; then
        echo "⚠️  Fakeroot is enabled but 'newuidmap' was not found in PATH."
        echo "   Apptainer needs the 'uidmap' package (newuidmap/newgidmap) for --fakeroot."
        echo "   Install it: sudo apt install uidmap"
        echo "   (or build as the invoking user: pixi containerize --no-fakeroot)"
        echo ""
    fi

    local -a cmd=("$binary" build --force)
    [ "$FAKEROOT" = true ] && cmd+=(--fakeroot)
    [ -n "$ARCH" ] && cmd+=(--arch "$ARCH")
    for ba in "${BUILD_ARGS[@]:-}"; do cmd+=(--build-arg "$ba"); done
    cmd+=("$OUTPUT_ABS" "$TARGET_DEF")
    # --bind must precede the positional args, or apptainer counts it as an
    # extra positional ("accepts 2 arg(s), received N").
    if [ -n "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
        log "ℹ️ Sharing package cache: $CACHE_DIR -> /root/.cache"
        cmd=("$binary" build --force)
        [ "$FAKEROOT" = true ] && cmd+=(--fakeroot)
        [ -n "$ARCH" ] && cmd+=(--arch "$ARCH")
        for ba in "${BUILD_ARGS[@]:-}"; do cmd+=(--build-arg "$ba"); done
        cmd+=(--bind "$CACHE_DIR:/root/.cache" "$OUTPUT_ABS" "$TARGET_DEF")
    fi

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
        local final_def
        final_def="$OUTPUT_PARENT/$(basename "${OUTPUT%.*}").def"
        mv "$TARGET_DEF" "$final_def"
        log "ℹ️ Definition file kept at: $final_def"
    fi
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

# ---------------------------------------------------------------------------
# SIF-specific TOML key handler (called by read_toml_config for unknown keys).
# ---------------------------------------------------------------------------
apply_toml_backend() {
    local key="$1" val="$2"
    local clean_val
    clean_val=$(echo "$val" | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    case "$key" in
        push)     _toml_set_bool PUSH "$clean_val" ;;
        fakeroot) _toml_set_bool FAKEROOT "$clean_val" ;;
        arch)     ARCH="$clean_val" ;;
        build-arg) BUILD_ARGS+=("$clean_val") ;;
        cache-dir) CACHE_DIR="$clean_val" ;;
        *)        return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# Parse SIF-specific CLI arguments.
# Runs after parse_common_args; consumes SIF-only flags from REMAINING_ARGS.
# ---------------------------------------------------------------------------
parse_sif_args() {
    local -a leftover=()
    local i=0
    while [ $i -lt ${#REMAINING_ARGS[@]} ]; do
        case "${REMAINING_ARGS[$i]}" in
            --push)
                PUSH=true
                i=$((i + 1))
                if [ $i -lt ${#REMAINING_ARGS[@]} ]; then
                    PUSH_URI="${REMAINING_ARGS[$i]}"
                    i=$((i + 1))
                fi
                ;;
            --no-fakeroot)  FAKEROOT=false; i=$((i + 1)) ;;
            --arch)         ARCH="${REMAINING_ARGS[$((i + 1))]}"; i=$((i + 2)) ;;
            --build-arg)    BUILD_ARGS+=("${REMAINING_ARGS[$((i + 1))]}"); i=$((i + 2)) ;;
            --cache-dir)    CACHE_DIR="${REMAINING_ARGS[$((i + 1))]}"; i=$((i + 2)) ;;
            *)              leftover+=("${REMAINING_ARGS[$i]}"); i=$((i + 1)) ;;
        esac
    done
    REMAINING_ARGS=("${leftover[@]}")
}

# ---------------------------------------------------------------------------
# Push the built SIF image to a registry (apptainer/singularity push).
# ---------------------------------------------------------------------------
run_sif_push() {
    [ "$PUSH" = true ] || return 0
    [ -n "$PUSH_URI" ] || { echo "Error: --push requires a target URI (e.g. oras://user/image:tag)"; exit 1; }
    log "🚀 Pushing image to $PUSH_URI..."
    if [ "$QUIET" = true ]; then
        "$BACKEND" push "$OUTPUT_ABS" "$PUSH_URI" > /dev/null 2>&1 || exit 1
    elif [ "$VERBOSE" = true ]; then
        "$BACKEND" push "$OUTPUT_ABS" "$PUSH_URI"
    else
        "$BACKEND" push "$OUTPUT_ABS" "$PUSH_URI" || exit 1
    fi
    log "✅ Success! Image pushed to $PUSH_URI"
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

    # SIF-specific defaults (Docker sets its own at the top of its entrypoint).
    PUSH="${PUSH:-false}"
    PUSH_URI="${PUSH_URI:-}"
    FAKEROOT="${FAKEROOT:-true}"
    ARCH="${ARCH:-}"
    declare -a BUILD_ARGS=()

    pre_parse_path "$@"
    find_pre_manifest
    read_toml_config "$BACKEND" "$PRE_MANIFEST_SRC"

    parse_common_args "$@"
    parse_sif_args
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

    log "ℹ️ Base image: $BASE_IMAGE"
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

    run_sif_push

    sif_final_cleanup
}
