#!/bin/bash
# tool.sh — Shared functions for the `tool` subcommand.
#
# The `tool` subcommand containerizes one or more conda packages with
# `pixi global install`, WITHOUT requiring a pixi.toml / pixi.lock and without
# being tied to any project directory. It can therefore be run from anywhere.
#
#   pixi containerize tool python
#   pixi containerize tool -c bioconda fastp
#   pixi containerize-docker tool -c bioconda samtools -o samtools:1.21
#
# Sourced after common.sh (and sif.sh for the SIF backends) by every entrypoint.
# shellcheck disable=SC2034  # Variables are consumed by the sourcing scripts.

# ---------------------------------------------------------------------------
# Tool-mode help text.
# $1 = backend ("apptainer" | "singularity" | "docker")
# ---------------------------------------------------------------------------
print_tool_usage() {
    local backend="$1"
    local cmd
    case "$backend" in
        singularity) cmd="pixi containerize-singularity tool" ;;
        docker)      cmd="pixi containerize-docker tool" ;;
        *)           cmd="pixi containerize tool" ;;
    esac

    echo "Usage: $cmd [options] PACKAGE [PACKAGE...]"
    echo ""
    echo "Containerize one or more conda packages with 'pixi global install'."
    echo "No pixi.toml / pixi.lock is required: this can be run from anywhere."
    echo "Version: $PIXITAINER_VERSION"
    echo ""
    echo "Packages use the conda MatchSpec syntax (pin versions inline), e.g.:"
    echo "  fastp                fastp=0.23.4         'python>=3.11'"
    echo ""

    echo "Tool Options:"
    echo "  -c, --channel CHAN        Channel to pull from (repeatable, default: conda-forge)"
    echo "                            When set, 'conda-forge' is appended automatically if missing."
    echo ""

    echo "Core Options:"
    if [ "$backend" = "docker" ]; then
        echo "  -o, --output TAG          Docker image tag (default: <package>:latest)"
    else
        echo "  -o, --output OUTPUT       Output image path (default: <package>.sif)"
    fi
    echo "  -m, --manual              Use a shell entrypoint instead of the tool binary"
    echo "                            (by default the package's binary is the entrypoint)"
    echo ""

    echo "Environment & Image Setup:"
    echo "  -b, --base-image IMAGE    Specify base image (default: $TOOL_DEFAULT_BASE)"
    echo ""

    echo "Pixi Versioning:"
    echo "  -V, --pixi-version VER    Specify pixi version (default: same as host)"
    echo "  -L, --latest              Force the use of the latest pixi version (cannot be used with -V)"
    echo ""

    echo "Advanced Modifications:"
    echo "  -a, --add-file SRC:DEST   Add a file/folder to the image (format: source:destination)"
    echo "      --post-command CMD    Add a command to run after install (repeatable)"
    echo "  -l, --label KEY:VALUE     Add a custom label to the image (repeatable)"
    if [ "$backend" = "docker" ]; then
        echo "  -k, --keep-def            Keep the generated Dockerfile (do not delete it)"
    else
        echo "  -k, --keep-def            Export the .def file (do not delete temporary files)"
    fi
    echo ""

    echo "Output Options:"
    if [ "$backend" = "docker" ]; then
        echo "  -d, --dry-run             Output the Dockerfile to stdout without building"
    else
        echo "  -d, --dry-run             Output the .def file to stdout without building"
    fi
    echo ""

    echo "General Options:"
    echo "  -q, --quiet               Quiet mode (suppress output, 0 on success, 1 on error)"
    echo "  -v, --verbose             Verbose mode (show the full build output)"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "The image is slimmed automatically: the pixi cache and the pixi binary"
    echo "(build-time only) are removed, leaving just the tool's environment."
    echo ""
    echo "Note: inside 'tool' mode, -c means --channel (not --post-command)."
    echo "      Use the long form --post-command for post commands."
}

# Default base image for `tool` mode. Because every package comes from conda,
# the base OS is irrelevant, so we default to a small glibc image instead of
# the host-matched one used in project mode. Overridable with -b/--base-image.
TOOL_DEFAULT_BASE="debian:stable-slim"

# ---------------------------------------------------------------------------
# Initialise tool-mode default variables. Call after init_common_defaults.
# Sets: TOOL_PKGS, CHANNELS, CHANNEL_FLAGS, BASE_IMAGE, SEAMLESS
# ---------------------------------------------------------------------------
init_tool_defaults() {
    TOOL_PKGS=()
    CHANNELS=()
    CHANNEL_FLAGS=""
    BASE_IMAGE="$TOOL_DEFAULT_BASE"
    SEAMLESS=true   # tool images run the tool by default; --manual opts out
}

# ---------------------------------------------------------------------------
# Parse tool-mode CLI arguments.
# $1 = backend, $@ (after shift) = the arguments after the `tool` keyword.
# Populates TOOL_PKGS / CHANNELS plus the shared globals (OUTPUT, BASE_IMAGE…).
# ---------------------------------------------------------------------------
parse_tool_args() {
    local backend="$1"; shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--channel)       CHANNELS+=("$2");          shift 2 ;;
            -o|--output)        OUTPUT="$2";               shift 2 ;;
            -b|--base-image)    BASE_IMAGE="$2";           shift 2 ;;
            -m|--manual)        SEAMLESS=false;            shift   ;;
            -V|--pixi-version)  TARGET_PIXI_VERSION="$2";  shift 2 ;;
            -L|--latest)        LATEST_PIXI=true;          shift   ;;
            -a|--add-file)      EXTRA_FILES+=("$2");       shift 2 ;;
            --post-command)     POST_COMMANDS+=("$2");     shift 2 ;;
            -l|--label)         LABELS+=("$2");            shift 2 ;;
            -k|--keep-def)      KEEP_DEF=true;             shift   ;;
            -d|--dry-run)       DRY_RUN=true;              shift   ;;
            -q|--quiet)         QUIET=true;                shift   ;;
            -v|--verbose)       VERBOSE=true;              shift   ;;
            -h|--help)          print_tool_usage "$backend"; exit 0 ;;
            --)                 shift; while [[ $# -gt 0 ]]; do TOOL_PKGS+=("$1"); shift; done ;;
            -*)
                echo "Error: Unknown option for 'tool' mode: $1"
                print_tool_usage "$backend"
                exit 1 ;;
            *)                  TOOL_PKGS+=("$1");         shift   ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Validate tool-mode arguments.
# ---------------------------------------------------------------------------
validate_tool_args() {
    local backend="$1"
    if [ ${#TOOL_PKGS[@]} -eq 0 ]; then
        echo "Error: 'tool' mode requires at least one package."
        print_tool_usage "$backend"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Strip version / build constraints from a MatchSpec to get the package name.
# e.g. 'python>=3.11' -> python, 'fastp=0.23.4' -> fastp
# ---------------------------------------------------------------------------
tool_clean_name() {
    local spec="$1"
    spec="${spec%%[*}"   # drop [build=...]
    spec="${spec%% *}"   # drop space-separated constraint
    spec="${spec%%=*}"   # drop =version
    spec="${spec%%>*}"   # drop >=, >
    spec="${spec%%<*}"   # drop <=, <
    spec="${spec%%!*}"   # drop !=
    spec="${spec%%~*}"   # drop ~=
    echo "$spec"
}

# ---------------------------------------------------------------------------
# Default output names derived from the first package.
# ---------------------------------------------------------------------------
tool_default_output_sif()    { echo "$(tool_clean_name "${TOOL_PKGS[0]}").sif"; }
tool_default_output_docker() { echo "$(tool_clean_name "${TOOL_PKGS[0]}"):latest"; }

# ---------------------------------------------------------------------------
# Resolve channels (apply default / ensure conda-forge is first) and build the
# flag string used by `pixi global install`.
# Sets: CHANNELS (normalized), CHANNEL_FLAGS
# ---------------------------------------------------------------------------
build_tool_channel_flags() {
    local -a resolved_channels=()
    local has_cf=false c

    for c in "${CHANNELS[@]}"; do
        if [ "$c" = "conda-forge" ]; then
            has_cf=true
            continue
        fi
        resolved_channels+=("$c")
    done

    CHANNELS=("conda-forge")
    if [ ${#resolved_channels[@]} -gt 0 ]; then
        CHANNELS+=("${resolved_channels[@]}")
    fi

    if [ "$has_cf" = false ] && [ ${#resolved_channels[@]} -gt 0 ]; then
        log "ℹ️ Auto-added 'conda-forge' channel (required by most packages)"
    fi

    CHANNEL_FLAGS=""
    local c
    for c in "${CHANNELS[@]}"; do
        CHANNEL_FLAGS="$CHANNEL_FLAGS -c $c"
    done
    CHANNEL_FLAGS="${CHANNEL_FLAGS# }"
}

# ---------------------------------------------------------------------------
# Build the `pixi global install` command.
# $1 = optional extra flags injected verbatim before the channel flags.
# Sets: INSTALL_CMD
# ---------------------------------------------------------------------------
# shellcheck disable=SC2120
build_tool_install_cmd() {
    local extra_flags="${1:-}"
    build_tool_channel_flags

    local p pkgs=""
    for p in "${TOOL_PKGS[@]}"; do
        pkgs="$pkgs \"$p\""
    done
    pkgs="${pkgs# }"

    if [ ${#TOOL_PKGS[@]} -eq 1 ]; then
        log "ℹ️ Containerizing tool: ${TOOL_PKGS[0]}"
    else
        log "ℹ️ Containerizing tools:"
        for p in "${TOOL_PKGS[@]}"; do log "      - $p"; done
    fi
    log "ℹ️ Channels: ${CHANNELS[*]}"

    INSTALL_CMD="pixi global install $extra_flags$CHANNEL_FLAGS $pkgs"
}

# ---------------------------------------------------------------------------
# Image-slimming commands, printed one per line. These run AFTER the install
# and any post-commands, while pixi is still present (pixi clean needs it),
# and finish by deleting pixi itself, which is only needed at build time:
# the exposed binaries are standalone trampolines under /opt/pixi/bin.
#
# In Docker these MUST be chained into the same RUN as the install, otherwise
# the removed files persist in a lower layer (see generate_tool_dockerfile).
# ---------------------------------------------------------------------------
tool_slim_steps() {
    # shellcheck disable=SC2016  # $HOME must stay literal: it expands inside the
    # container at build time, not when this script is sourced on the host.
    printf '%s\n' \
        'pixi clean cache --yes >/dev/null 2>&1 || true' \
        'rm -rf /opt/pixi/bin/pixi /opt/pixi/completions /opt/pixi/cache "$HOME/.cache/rattler" /root/.cache 2>/dev/null || true' \
        'find /opt/pixi/envs -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true'
}

# ---------------------------------------------------------------------------
# Seamless (tool binary as entrypoint) is the default, but it only has a
# well-defined target for a single package. When several packages are
# requested, fall back to a manual (shell) entrypoint so every tool stays
# reachable by name. A user-supplied --manual is already SEAMLESS=false here.
# ---------------------------------------------------------------------------
tool_resolve_seamless() {
    if [ "$SEAMLESS" = true ] && [ ${#TOOL_PKGS[@]} -gt 1 ]; then
        SEAMLESS=false
        log "ℹ️ Multiple packages: using a manual entrypoint (run a tool by name)"
    fi
}

# ---------------------------------------------------------------------------
# Build the SIF runscript for tool mode.
# Sets: RUNSCRIPT_CONTENT
# ---------------------------------------------------------------------------
build_tool_runscript_sif() {
    if [ "$SEAMLESS" = true ]; then
        local bin
        bin="$(tool_clean_name "${TOOL_PKGS[0]}")"
        log "ℹ️ Entrypoint: '$bin' (use --manual for a shell entrypoint)"
        RUNSCRIPT_CONTENT="exec $bin \"\$@\""
    else
        RUNSCRIPT_CONTENT='exec "$@"'
    fi
}

# ---------------------------------------------------------------------------
# Build the %files section for a tool .def (bootstrap + extra files only:
# no manifest, no lock file).
# Sets: FILES_SECTION
# Requires: BOOTSTRAP_SH
# ---------------------------------------------------------------------------
build_tool_files_section() {
    FILES_SECTION="    \"$BOOTSTRAP_SH\" /opt/bootstrap.sh"

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
# Generate the tool-mode .def file (no manifest, uses `pixi global install`).
# Sets: TARGET_DEF
# ---------------------------------------------------------------------------
generate_tool_def_file() {
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
    Pixi_Version $PIXI_VERSION
    Pixitainer_Mode tool$CUSTOM_LABELS_SECTION

%files
$FILES_SECTION

%environment
    export PIXI_HOME=/opt/pixi
    export PIXI_DIR=/opt/pixi
    export PATH="/opt/pixi/bin:\$PATH"

%post
    . /opt/bootstrap.sh
    set -e

    echo "STEP: Installing system prerequisites and Pixi"
    bootstrap_install

    $PIXI_VERSION_CMD

    echo "STEP: Installing tool(s) globally"
    pixi config set --global run-post-link-scripts insecure
    $INSTALL_CMD

    $(if [ ${#POST_COMMANDS[@]} -gt 0 ]; then
        echo "echo \"STEP: Running extra post commands\""
        printf '    %s\n' "${POST_COMMANDS[@]}"
    fi)

    echo "STEP: Slimming image"
$(tool_slim_steps | sed 's/^/    /')

    echo "STEP: Cleaning"
    bootstrap_cleanup

%runscript
    $RUNSCRIPT_CONTENT
EOF
}

# ---------------------------------------------------------------------------
# Generate the tool-mode Dockerfile (no manifest, uses `pixi global install`).
# Sets: DOCKERFILE
# Requires the Docker entrypoint globals (TMP_DIR, COPY_EXTRA_LINES…).
# ---------------------------------------------------------------------------
generate_tool_dockerfile() {
    DOCKERFILE="$TMP_DIR/Dockerfile"

    local pixi_version_env_line=""
    if [ -n "$PIXI_INSTALL_VER" ]; then
        pixi_version_env_line="ENV PIXI_VERSION=$PIXI_INSTALL_VER"
    fi

    local label_lines
    label_lines="LABEL Created_With=\"Pixitainer (https://github.com/RaphaelRibes/pixitainer)\" \\"$'\n'"      Pixitainer_Version=\"$PIXITAINER_VERSION\" \\"$'\n'"      Pixi_Version=\"$PIXI_VERSION\" \\"$'\n'"      Pixitainer_Mode=\"tool\""

    log_labels
    local label lkey lval
    for label in "${LABELS[@]}"; do
        lkey="${label%%:*}"
        lval="${label#*:}"
        label_lines="$label_lines"$'\n'"LABEL $lkey=\"$lval\""
    done

    log_post_commands

    local entrypoint_line cmd_line
    if [ "$SEAMLESS" = true ]; then
        local bin
        bin="$(tool_clean_name "${TOOL_PKGS[0]}")"
        log "ℹ️ Entrypoint: '$bin' (use --manual for a shell entrypoint)"
        entrypoint_line="ENTRYPOINT [\"$bin\"]"
        cmd_line='CMD []'
    else
        entrypoint_line='ENTRYPOINT ["/bin/bash", "-c", "exec \"$@\"", "--"]'
        cmd_line='CMD ["/bin/bash"]'
    fi

    # Build ONE RUN that installs prerequisites + pixi, installs the tool(s),
    # runs post-commands, then slims and cleans up. Doing it all in a single
    # layer is what actually shrinks the image: files created and deleted within
    # the same RUN (the pixi binary, the rattler cache, curl) leave no trace in
    # the final image, whereas deleting them in a later layer would not.
    local -a chain=(
        '. /opt/bootstrap.sh'
        'bootstrap_install'
        'pixi config set --global run-post-link-scripts insecure'
        "$INSTALL_CMD"
    )
    local cmd slim
    for cmd in "${POST_COMMANDS[@]}"; do chain+=("$cmd"); done
    while IFS= read -r slim; do chain+=("$slim"); done < <(tool_slim_steps)
    chain+=('bootstrap_cleanup')

    local run_block="RUN set -e; \\"
    local total=${#chain[@]} idx=0
    for cmd in "${chain[@]}"; do
        idx=$((idx + 1))
        if [ "$idx" -lt "$total" ]; then
            run_block+=$'\n'"    $cmd; \\"
        else
            run_block+=$'\n'"    $cmd"
        fi
    done

    cat <<EOF > "$DOCKERFILE"
# Generated by Pixitainer $PIXITAINER_VERSION (tool mode)
# https://github.com/RaphaelRibes/pixitainer

FROM $BASE_IMAGE

$label_lines

# --- Environment ---
ENV PIXI_HOME=/opt/pixi
ENV PIXI_DIR=/opt/pixi
ENV PATH="/opt/pixi/bin:\$PATH"
$pixi_version_env_line

# --- Bootstrap files ---
COPY ctx/bootstrap.sh /opt/bootstrap.sh
$COPY_EXTRA_LINES

# --- Install tool(s) and slim down (single layer) ---
$run_block

# --- Entrypoint ---
$entrypoint_line
$cmd_line
EOF
}

# ---------------------------------------------------------------------------
# Entry point for the SIF backends (Apptainer / Singularity).
# Usage: tool_main_sif BINARY "$@"   (BINARY ∈ {apptainer, singularity})
# Requires common.sh + sif.sh + tool.sh sourced, and BOOTSTRAP_SH set.
# ---------------------------------------------------------------------------
tool_main_sif() {
    BACKEND="$1"; shift

    init_common_defaults
    init_tool_defaults
    # Note: no detect_base_image here — tool mode defaults to a small base
    # (TOOL_DEFAULT_BASE); -b/--base-image still overrides it.

    parse_tool_args "$BACKEND" "$@"
    validate_common_args
    validate_tool_args "$BACKEND"
    tool_resolve_seamless

    OUTPUT="${OUTPUT:-$(tool_default_output_sif)}"

    resolve_sif_paths

    log "ℹ️ Base image: $BASE_IMAGE"
    log "📂 Output target: $OUTPUT_ABS"

    build_tool_files_section
    build_tool_install_cmd
    build_tool_runscript_sif
    resolve_pixi_version
    log_labels
    format_sif_labels
    log_post_commands
    generate_tool_def_file

    sif_dry_run_check
    run_sif_build "$BACKEND"
    sif_final_cleanup
}

# ---------------------------------------------------------------------------
# Entry point for the Docker backend.
# Usage: tool_main_docker "$@"
# Requires common.sh + tool.sh sourced, BOOTSTRAP_SH set, and the Docker
# entrypoint's helper functions (stage_docker_files, run_docker_build) and
# default globals to be defined before this is called.
# ---------------------------------------------------------------------------
tool_main_docker() {
    init_common_defaults
    init_tool_defaults
    # Note: no detect_base_image here — tool mode defaults to a small base
    # (TOOL_DEFAULT_BASE); -b/--base-image still overrides it.

    # The Docker entrypoint pre-sets OUTPUT="pixitainer:latest" at top level;
    # clear it so the tool-name default (or -o) wins.
    OUTPUT=""

    parse_tool_args "docker" "$@"
    validate_common_args
    validate_tool_args "docker"
    tool_resolve_seamless

    OUTPUT="${OUTPUT:-$(tool_default_output_docker)}"

    # Reuse the Docker build infra; make sure the globals it reads are sane.
    USE_BUILDKIT=false
    WD="$(pwd -P)"                       # for relative --add-file sources
    TMP_DIR="$(pwd -P)/.tmp_pixitainer_docker"

    log "🐳 Docker image tag: $OUTPUT"

    mkdir -p "$TMP_DIR/ctx"
    cp "$BOOTSTRAP_SH" "$TMP_DIR/ctx/bootstrap.sh"

    stage_docker_files
    build_tool_install_cmd
    resolve_pixi_version
    generate_tool_dockerfile

    if [ "$DRY_RUN" = true ]; then
        cat "$DOCKERFILE"
        rm -rf "$TMP_DIR"
        exit 0
    fi

    run_docker_build

    if [ "$KEEP_DEF" = true ]; then
        local safe_tag final_dockerfile
        safe_tag=$(echo "$OUTPUT" | tr '/:' '_')
        final_dockerfile="$(pwd -P)/Dockerfile.$safe_tag"
        cp "$DOCKERFILE" "$final_dockerfile"
        log "ℹ️ Dockerfile kept at: $final_dockerfile"
    fi

    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}