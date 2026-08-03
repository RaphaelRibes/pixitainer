#!/bin/bash
# common.sh — Shared functions and defaults for all pixitainer backends.
# Sourced by pixi-containerize, pixi-containerize-singularity, pixi-containerize-docker.
# shellcheck disable=SC2034  # Variables are used by the sourcing scripts.

PIXITAINER_VERSION="0.8.2"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log() {
    if [ "$QUIET" = false ]; then
        echo "$@"
    fi
}

# ---------------------------------------------------------------------------
# Auto-detect a reasonable base image from the host OS
# Sets: BASE_IMAGE
# ---------------------------------------------------------------------------
detect_base_image() {
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release

        if [[ "$ID" == "ubuntu" || "$ID" == "debian" || "$ID" == "fedora" || "$ID" == "alpine" || "$ID" == "rockylinux" || "$ID" == "almalinux" ]]; then
            if [ -z "$VERSION_ID" ]; then
                BASE_IMAGE="${ID}"
            else
                BASE_IMAGE="${ID}:${VERSION_ID}"
            fi
        elif [[ "$ID" == "arch" || "$ID" == "archlinux" || "$ID_LIKE" == *"arch"* ]]; then
            BASE_IMAGE="archlinux"
        elif [[ "$ID_LIKE" == *"debian"* || "$ID_LIKE" == *"ubuntu"* ]]; then
            BASE_IMAGE="ubuntu:24.04"
        elif [[ "$ID_LIKE" == *"fedora"* || "$ID_LIKE" == *"rhel"* || "$ID_LIKE" == *"centos"* ]]; then
            BASE_IMAGE="fedora"
        elif [[ "$ID_LIKE" == *"suse"* ]]; then
            BASE_IMAGE="opensuse/tumbleweed"
        else
            echo "⚠️  Warning: Unsupported OS '$ID'. Defaulting to ubuntu:24.04 as base image."
            BASE_IMAGE="ubuntu:24.04"
        fi
    else
        echo "⚠️  Warning: /etc/os-release not found. Defaulting to ubuntu:24.04 as base image."
        BASE_IMAGE="ubuntu:24.04"
    fi
}

# ---------------------------------------------------------------------------
# Initialise shared default variables.
# Must be called before TOML / CLI parsing.
# Sets: PROJECT_PATH, SEAMLESS, TARGET_PIXI_VERSION, LATEST_PIXI, KEEP_DEF,
#       VERBOSE, QUIET, DRY_RUN, NO_INSTALL, ENVS, EXTRA_FILES,
#       POST_COMMANDS, LABELS
# ---------------------------------------------------------------------------
init_common_defaults() {
    PROJECT_PATH="."
    SEAMLESS=true   # seamless is the default; --manual / manual=true opts out
    TARGET_PIXI_VERSION=""
    LATEST_PIXI=false
    KEEP_DEF=false
    VERBOSE=false
    QUIET=false
    DRY_RUN=false
    NO_INSTALL=false
    ENVS=()
    EXTRA_FILES=()
    POST_COMMANDS=()
    LABELS=()
}

# ---------------------------------------------------------------------------
# TOML section parser.
# Usage: parse_toml_section SECTION FILE
# Prints "key|raw_value" lines for every key in the given TOML table.
# ---------------------------------------------------------------------------
parse_toml_section() {
    local section="$1"
    local file="$2"
    local esc_section
    esc_section=$(printf '%s' "$section" | sed 's/\./\\\\./g')
    awk -v sec="$section" -v esc="$esc_section" '
    $0 ~ ("^\\[" esc "\\]") { flag=1; next }
    /^\[/ { flag=0 }
    flag {
        sub(/#.*/, "")
        gsub(/\r$/, "")
        gsub(/^[ \t]+|[ \t]+$/, "")
        if (!length) next

        if (in_array) {
            accumulated = accumulated " " $0
            if ($0 ~ /\]/) {
                in_array = 0
                print current_key "|" accumulated
                accumulated = ""
                current_key = ""
            }
            next
        }

        idx = index($0, "=")
        if (!idx) next

        key = substr($0, 1, idx-1)
        val = substr($0, idx+1)
        gsub(/^[ \t]+|[ \t]+$/, "", key)
        gsub(/^[ \t]+|[ \t]+$/, "", val)

        if (val ~ /^\[/ && val !~ /\]/) {
            in_array = 1
            current_key = key
            accumulated = val
            next
        }

        print key "|" val
    }
    END {
        if (in_array && current_key != "") {
            print current_key "|" accumulated
        }
    }
    ' "$file"
}

# ---------------------------------------------------------------------------
# Helper: set a boolean variable from a TOML string value.
# Usage: _toml_set_bool VARNAME VALUE
# Sets VARNAME to "true" if VALUE (case-insensitive) is "true", else "false".
# ---------------------------------------------------------------------------
_toml_set_bool() {
    if [[ "${2,,}" == "true" ]]; then printf -v "$1" true; else printf -v "$1" false; fi
}

# ---------------------------------------------------------------------------
# Apply a single TOML key/value for the *shared* option set.
# $1 = key,  $2 = raw value,  $3 = reset_mode ("true" on subtable pass)
# Returns 0 if the key was handled, 1 if the key is unknown (backend-specific).
# ---------------------------------------------------------------------------
apply_toml_common() {
    local key="$1"
    local val="$2"
    local reset_mode="${3:-false}"

    local clean_val
    clean_val=$(echo "$val" | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    case "$key" in
        output)       OUTPUT="$clean_val" ;;
        path)         PROJECT_PATH="$clean_val" ;;
        manual)       if [[ "${clean_val,,}" == "true" ]]; then SEAMLESS=false; else SEAMLESS=true; fi ;;
        seamless)     # Deprecated since 0.8.0: seamless is now the default. Kept as an alias.
                      echo "⚠️  Warning: the 'seamless' config key is deprecated since 0.8.0; seamless is now the default. Use 'manual' instead." >&2
                      _toml_set_bool SEAMLESS "$clean_val" ;;
        base-image)   BASE_IMAGE="$clean_val" ;;
        no-install)   _toml_set_bool NO_INSTALL  "$clean_val" ;;
        pixi-version) TARGET_PIXI_VERSION="$clean_val" ;;
        latest)       _toml_set_bool LATEST_PIXI "$clean_val" ;;
        keep-def)     _toml_set_bool KEEP_DEF    "$clean_val" ;;
        dry-run)      _toml_set_bool DRY_RUN     "$clean_val" ;;
        quiet)        _toml_set_bool QUIET       "$clean_val" ;;
        verbose)      _toml_set_bool VERBOSE     "$clean_val" ;;
        env|add-file|post-command|label)
            _apply_toml_array "$key" "$val" "$reset_mode"
            ;;
        *)
            return 1 ;;   # Not a shared key — let backend handle it
    esac
    return 0
}

# Internal helper: parse a TOML array value into the corresponding global array.
# When reset_mode=true the target array is cleared unconditionally, so that an
# empty subtable array (e.g. `env = []`) correctly replaces the general array.
_apply_toml_array() {
    local key="$1"
    local val="$2"
    local reset_mode="$3"

    if [ "$reset_mode" = "true" ]; then
        case "$key" in
            env)          ENVS=() ;;
            add-file)     EXTRA_FILES=() ;;
            post-command) POST_COMMANDS=() ;;
            label)        LABELS=() ;;
        esac
    fi

    while read -r elem; do
        [ -z "$elem" ] && continue
        local elem_clean="${elem//\"/}"
        case "$key" in
            env)          ENVS+=("$elem_clean") ;;
            add-file)     EXTRA_FILES+=("$elem_clean") ;;
            post-command) POST_COMMANDS+=("$elem_clean") ;;
            label)        LABELS+=("$elem_clean") ;;
        esac
    done < <(echo "$val" | grep -o '"[^"]*"')
}

# ---------------------------------------------------------------------------
# Read TOML configuration from manifest.
# $1 = backend name ("apptainer", "singularity", "docker")
# $2 = path to the manifest file (may be empty)
# Calls apply_toml_common for shared keys and, if defined, the function
# apply_toml_backend (provided by the sourcing script) for unknown keys.
# ---------------------------------------------------------------------------
read_toml_config() {
    local backend="$1"
    local manifest="$2"
    [ -z "$manifest" ] && return

    local _apply_one
    _apply_one() {
        local _key="$1" _val="$2" _reset="$3"
        apply_toml_common "$_key" "$_val" "$_reset" && return
        # Delegate to the backend-specific handler if it exists
        if declare -F apply_toml_backend >/dev/null 2>&1; then
            apply_toml_backend "$_key" "$_val" "$_reset"
        fi
    }

    # Pass 1 — general [tool.pixitainer]
    while IFS="|" read -r key val; do
        [ -z "$key" ] && continue
        _apply_one "$key" "$val" "false"
    done < <(parse_toml_section "tool.pixitainer" "$manifest")

    # Pass 2 — backend-specific [tool.pixitainer.<backend>]
    while IFS="|" read -r key val; do
        [ -z "$key" ] && continue
        _apply_one "$key" "$val" "true"
    done < <(parse_toml_section "tool.pixitainer.$backend" "$manifest")
}

# ---------------------------------------------------------------------------
# Pre-parse --path / -p from the raw argument list.
# $@ = original script arguments.
# Sets: PROJECT_PATH (if found)
# ---------------------------------------------------------------------------
pre_parse_path() {
    local i next
    for ((i=1; i<=$#; i++)); do
        if [[ "${!i}" == "-p" ]] || [[ "${!i}" == "--path" ]]; then
            next=$((i+1))
            PROJECT_PATH="${!next}"
            return
        fi
    done
}

# ---------------------------------------------------------------------------
# Locate the project manifest for TOML config reading.
# Uses PROJECT_PATH. Sets: PRE_MANIFEST_SRC
# ---------------------------------------------------------------------------
find_pre_manifest() {
    local toml_wd
    toml_wd=$(cd "$PROJECT_PATH" 2>/dev/null && pwd -P || echo "$PROJECT_PATH")
    if [ -f "$toml_wd/pixi.toml" ]; then
        PRE_MANIFEST_SRC="$toml_wd/pixi.toml"
    elif [ -f "$toml_wd/pyproject.toml" ]; then
        PRE_MANIFEST_SRC="$toml_wd/pyproject.toml"
    else
        PRE_MANIFEST_SRC=""
    fi
}

# ---------------------------------------------------------------------------
# Parse shared CLI arguments.
# Recognised flags are consumed; unrecognised ones are collected into the
# global array REMAINING_ARGS for the backend to process.
# $@ = original script arguments
# ---------------------------------------------------------------------------
parse_common_args() {
    REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)        OUTPUT="$2";             shift 2 ;;
            -p|--path)          PROJECT_PATH="$2";       shift 2 ;;
            -m|--manual)        SEAMLESS=false;          shift   ;;
            -s|--seamless)      # Deprecated since 0.8.0: seamless is now the default.
                                echo "⚠️  Warning: '-s'/'--seamless' is deprecated since 0.8.0; seamless is now the default. Use '--manual' for a shell entrypoint." >&2
                                SEAMLESS=true;           shift   ;;
            -b|--base-image)    BASE_IMAGE="$2";         shift 2 ;;
            -e|--env)           ENVS+=("$2");            shift 2 ;;
            -n|--no-install)    NO_INSTALL=true;         shift   ;;
            -V|--pixi-version)  TARGET_PIXI_VERSION="$2"; shift 2 ;;
            -L|--latest)        LATEST_PIXI=true;        shift   ;;
            -a|--add-file)      EXTRA_FILES+=("$2");     shift 2 ;;
            -c|--post-command)  POST_COMMANDS+=("$2");   shift 2 ;;
            -l|--label)         LABELS+=("$2");          shift 2 ;;
            -k|--keep-def)      KEEP_DEF=true;           shift   ;;
            -d|--dry-run)       DRY_RUN=true;            shift   ;;
            -q|--quiet)         QUIET=true;              shift   ;;
            -v|--verbose)       VERBOSE=true;            shift   ;;
            -h|--help)          usage; exit 0            ;;
            *)                  REMAINING_ARGS+=("$1");  shift   ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Validate shared argument constraints.
# ---------------------------------------------------------------------------
validate_common_args() {
    if [ "$LATEST_PIXI" = true ] && [ -n "$TARGET_PIXI_VERSION" ]; then
        echo "Error: The --latest flag cannot be used at the same time as --pixi-version."
        exit 1
    fi

    if [ -n "$TARGET_PIXI_VERSION" ]; then
        if ! printf '%s\n%s\n' "0.44.0" "$TARGET_PIXI_VERSION" | sort -V -c 2>/dev/null; then
            echo "Error: Specified Pixi version must be 0.44.0 or newer."
            exit 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# Resolve the working directory and locate the manifest + lock file.
# Sets: WD, MANIFEST_SRC, MANIFEST_DEST, PIXI_LOCK
# ---------------------------------------------------------------------------
resolve_manifest() {
    WD=$(cd "$PROJECT_PATH" && pwd -P)
    if [ -f "$WD/pixi.toml" ]; then
        MANIFEST_SRC="$WD/pixi.toml"
        MANIFEST_DEST="/opt/conf/pixi.toml"
    elif [ -f "$WD/pyproject.toml" ]; then
        MANIFEST_SRC="$WD/pyproject.toml"
        MANIFEST_DEST="/opt/conf/pyproject.toml"
    else
        if [ "$QUIET" = false ]; then
            echo "Error: Neither pixi.toml nor pyproject.toml found in $WD"
        fi
        exit 1
    fi
    PIXI_LOCK="$WD/pixi.lock"
}

# ---------------------------------------------------------------------------
# Build the pixi install command.
# $1 = extra flags to inject (e.g. "--no-progress" for Docker)
# Sets: INSTALL_CMD
# ---------------------------------------------------------------------------
build_install_cmd() {
    local extra_flags="${1:-}"
    if [ "$NO_INSTALL" = true ]; then
        INSTALL_CMD="echo 'Skipping environment installation'"
    elif [ ${#ENVS[@]} -eq 1 ]; then
        local env="${ENVS[0]}"
        log "ℹ️ Adding environment: $env"
        INSTALL_CMD="pixi install $extra_flags -e $env --frozen"
    elif [ ${#ENVS[@]} -gt 1 ]; then
        log "ℹ️ Adding environments:"
        local env_flags=""
        for env in "${ENVS[@]}"; do
            log "      - $env"
            env_flags="$env_flags -e $env"
        done
        INSTALL_CMD="pixi install $extra_flags$env_flags --frozen"
    else
        INSTALL_CMD="pixi install $extra_flags -a --frozen"
    fi
}

# ---------------------------------------------------------------------------
# Resolve the pixi version that will be installed inside the container.
# Sets: PIXI_VERSION, PIXI_INSTALL_VER, PIXI_VERSION_CMD
#   PIXI_VERSION      = human-readable version string (for labels).
#   PIXI_INSTALL_VER  = version to pin to ("" means "use whatever install.sh
#                       gives us" — i.e. the latest release). Docker consumes
#                       this as `ENV PIXI_VERSION=…` before the install RUN.
#   PIXI_VERSION_CMD  = shell command to run *after* install.sh if the version
#                       still needs to be pinned (used by the SIF %post flow,
#                       which calls install.sh without PIXI_VERSION and then
#                       self-updates). Empty when nothing to do.
# ---------------------------------------------------------------------------
resolve_pixi_version() {
    local host_ver=""

    if [ -n "$TARGET_PIXI_VERSION" ]; then
        PIXI_VERSION="$TARGET_PIXI_VERSION"
    elif [ "$LATEST_PIXI" = true ]; then
        PIXI_VERSION=$(curl -s https://api.github.com/repos/prefix-dev/pixi/releases/latest \
            | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/')
    else
        host_ver=$(pixi -V | awk '{print $NF}')
        PIXI_VERSION="$host_ver"
    fi

    if [ "$LATEST_PIXI" = true ]; then
        PIXI_INSTALL_VER=""
    else
        PIXI_INSTALL_VER="$PIXI_VERSION"
    fi

    if [ -n "$PIXI_INSTALL_VER" ]; then
        PIXI_VERSION_CMD="pixi self-update --version $PIXI_INSTALL_VER"
    else
        PIXI_VERSION_CMD=""
    fi
}

# ---------------------------------------------------------------------------
# Log labels and post-commands arrays (shared formatting).
# ---------------------------------------------------------------------------
log_labels() {
    if [ ${#LABELS[@]} -eq 1 ]; then
        log "ℹ️ Adding label: ${LABELS[0]}"
    elif [ ${#LABELS[@]} -gt 1 ]; then
        log "ℹ️ Adding labels:"
        for label in "${LABELS[@]}"; do
            log "      - $label"
        done
    fi
}

log_post_commands() {
    if [ ${#POST_COMMANDS[@]} -eq 1 ]; then
        log "ℹ️ Adding post-command: ${POST_COMMANDS[0]}"
    elif [ ${#POST_COMMANDS[@]} -gt 1 ]; then
        log "ℹ️ Adding post-commands:"
        for cmd in "${POST_COMMANDS[@]}"; do
            log "      - $cmd"
        done
    fi
}

# ---------------------------------------------------------------------------
# Generic spinner build runner.
# $1            = build tool display name (e.g. "Apptainer", "Singularity")
# $2            = initial step message
# $3            = function name to call for extracting step label from a line
#                 (receives the line as $1, should echo the label or nothing)
# $4..          = the build command array
#
# The step-extractor function is called for every output line. If it prints
# a non-empty string that becomes the new current step.
# For SIF builds the extractor looks for "STEP: …" markers.
# For Docker builds it looks for "Step N/M" or BuildKit "#N [stage]".
#
# On failure, the full log is printed to stderr.
# Returns the exit code of the build command.
# ---------------------------------------------------------------------------
run_with_spinner() {
    local tool_name="$1"; shift
    local initial_step="$1"; shift
    local step_extractor="$1"; shift
    # Remaining args are the build command
    local -a cmd=("$@")

    local LOG_FILE STEP_FILE CURRENT_STEP SPIN i EC LAST_STEP

    LOG_FILE="$(mktemp)"
    STEP_FILE="$(mktemp)"

    # Ensure temp files are cleaned up even on early exit / interrupt
    # shellcheck disable=SC2329  # Called indirectly via trap
    _spinner_cleanup() { rm -f "$LOG_FILE" "$STEP_FILE"; }
    trap _spinner_cleanup EXIT TERM INT

    CURRENT_STEP="$initial_step"
    echo "$CURRENT_STEP" > "$STEP_FILE"

    SPIN='-\|/'
    i=0

    tput civis 2>/dev/null || true

    set -o pipefail
    set +e

    "${cmd[@]}" 2>&1 | while IFS= read -r line; do
        echo "$line" >> "$LOG_FILE"

        local new_step
        new_step=$("$step_extractor" "$line")
        if [ -n "$new_step" ]; then
            printf "\r [✅] %s\033[K\n" "$CURRENT_STEP"
            CURRENT_STEP="$new_step"
            echo "$CURRENT_STEP" > "$STEP_FILE"
            i=0
        fi

        printf "\r [${SPIN:i++%4:1}] %s\033[K" "$CURRENT_STEP"
    done

    EC=$?
    LAST_STEP=$(cat "$STEP_FILE")
    tput cnorm 2>/dev/null || true

    if [ $EC -eq 0 ]; then
        printf "\r [✅] %s\033[K\n" "$LAST_STEP"
    else
        printf "\r [❌] %s\033[K\n" "$LAST_STEP"
        echo ""
        echo "❌ $tool_name build failed."
        echo ""
    fi

    # STEP_FILE is no longer needed. LOG_FILE is passed to the caller via
    # BUILD_LOG_FILE and must be removed by the caller once consumed.
    rm -f "$STEP_FILE"
    BUILD_LOG_FILE="$LOG_FILE"
    return $EC
}
