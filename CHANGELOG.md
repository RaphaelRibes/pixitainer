# Changelog

## [0.7.0] - 2026-04-22

### 🚀 Features

- Added support for Docker as a container backend (`pixi-containerize-docker`)
- Intelligent OS detection to automatically map unsupported distributions to appropriate Docker Hub base images
- Dynamic cross-platform package manager support (`apt`, `pacman`, `dnf`, `yum`, `apk`, `zypper`) for robust container builds
- Improved error messaging with actionable suggestions when base image authentication fails

### 💼 Other

- Major codebase refactoring: split monolithic scripts into modular libraries (`lib/`) for improved maintainability

## [0.6.2] - 2026-03-20

### 🚀 Features

- Added `-d/--dry-run` flag to output the container definition file without building it
- Improved verbose output for additional files, labels, and post-commands

## [0.6.1] - 2026-03-12

### 🚀 Features

- Pixitainer now tries to get the user OS version to use the correct base image by default.
- If it can't, it falls back to `ubuntu:24.04` and prints a warning

## [0.6.0] - 2026-03-11

### 🚀 Features

- Support for `[tool.pixitainer]` TOML table in `pixi.toml` / `pyproject.toml` manifests
- CLI arguments take precedence over TOML configuration
- Pixi version is now pinned to match the host machine version by default

### 🧪 Tests

- Comprehensive test suite for all TOML configuration options
- Tests for versioning, advanced options, and path resolution

## [0.5.0] - 2026-02-20

### 🚀 Features

- Make building the package more generic.
- Use pixi-build
- Install pixitainer in default environment

### 💼 Other

- Well, it works
- Removed unused code and add explaination on how to use the image correctly in the README
