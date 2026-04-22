#!/bin/sh
# bootstrap.sh — Install prerequisites (curl, ca-certificates, bash) and Pixi
# in the container, and optionally remove what we added afterwards.
#
# Designed to be SOURCED (not executed) so that MISSING_PKGS and PKGMGR persist
# from install to cleanup across the same shell process.
#
#   . /opt/bootstrap.sh
#   bootstrap_install   # detects distro, installs curl/bash/ca-certs, installs Pixi
#   # ... user setup ...
#   bootstrap_cleanup   # removes curl (if we added it) and cleans the pkg cache
#
# POSIX sh compatible — do not add bash-isms.
# shellcheck shell=sh

bootstrap_install() {
    export DEBIAN_FRONTEND=noninteractive

    MISSING_PKGS=""
    if ! command -v curl >/dev/null 2>&1; then MISSING_PKGS="curl ca-certificates"; fi
    if ! command -v bash >/dev/null 2>&1; then MISSING_PKGS="$MISSING_PKGS bash"; fi

    PKGMGR=""
    if [ -n "$MISSING_PKGS" ]; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update && apt-get install -y --no-install-recommends $MISSING_PKGS
            PKGMGR="apt"
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm $MISSING_PKGS
            PKGMGR="pacman"
        elif command -v dnf >/dev/null 2>&1; then
            dnf install -y $MISSING_PKGS
            PKGMGR="dnf"
        elif command -v yum >/dev/null 2>&1; then
            yum install -y $MISSING_PKGS
            PKGMGR="yum"
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache $MISSING_PKGS
            PKGMGR="apk"
        elif command -v zypper >/dev/null 2>&1; then
            zypper in -y $MISSING_PKGS
            PKGMGR="zypper"
        else
            echo "Error: No known package manager found" >&2
            exit 1
        fi
    fi

    export PIXI_HOME=/opt/pixi
    export PIXI_DIR=/opt/pixi
    curl -fsSL https://pixi.sh/install.sh | bash
    export PATH="/opt/pixi/bin:$PATH"
}

bootstrap_cleanup() {
    [ -z "$PKGMGR" ] && return 0

    if echo "$MISSING_PKGS" | grep -q "curl"; then
        case "$PKGMGR" in
            apt)     apt-get remove -y curl && apt-get autoremove -y ;;
            pacman)  pacman -Rns --noconfirm curl || true ;;
            dnf|yum) $PKGMGR remove -y curl ;;
            apk)     apk del curl ;;
            zypper)  zypper rm -y curl ;;
        esac
    fi

    case "$PKGMGR" in
        apt)     apt-get clean && rm -rf /var/lib/apt/lists/* ;;
        pacman)  pacman -Scc --noconfirm || true ;;
        dnf|yum) $PKGMGR clean all ;;
        zypper)  zypper clean ;;
    esac
}
