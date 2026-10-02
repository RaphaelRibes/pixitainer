# Changelog

## [0.9.0] - 2026-09-28

### 🚀 Features

- SIF (Apptainer/Singularity) backends now raise close to Docker parity:
  - `--push URI` pushes the built image (`oras://…`) straight to a registry after the build.
  - `--arch ARCH` cross-builds for another architecture (e.g. `arm64` on x86), alongside the default `--fakeroot` with a new `--no-fakeroot` opt-out.
  - `--build-arg KEY=VAL` passes build-time variables, substituted as `{{ KEY }}` in the `.def` (via Apptainer's native flag, not `%arguments`).
  - `--cache-dir DIR` now works in **project mode**, not just `tool` mode — a host directory is bind-mounted into the build so downloaded packages are reused across builds (a `%setup` block pre-creates `/root/.cache` so the mount succeeds on slim bases).
- New cross-backend `--env-var KEY=VAL` / `--env-file FILE` inject environment variables into the image on **all** backends (SIF `%environment`, Docker `ENV` lines).
- New `--gpu` flag marks an image as GPU-capable: Docker emits `NVIDIA_VISIBLE_DEVICES=all` + `NVIDIA_DRIVER_CAPABILITIES` (works with `docker run --gpus all`); Apptainer/Singularity add a `Pixitainer_GPU` label and print the `run --nv` hint.
- Docker project-mode builds now use a BuildKit cache mount for the rattler download cache (same as `tool` mode), so the cache is shared across builds for free and no longer part of the final image.

## [0.8.3] - 2026-08-03

### 🚀 Features

- The `conda-forge` channel is no longer required when installing pixitainer: `pixi global install -c https://prefix.dev/raphaelribes pixitainer` now works out of the box. The README install instructions and the package descriptions have been updated accordingly.
- New `--cache-dir` option on the `tool` subcommand reuses downloaded conda packages across Apptainer/Singularity builds (host directory bind-mounted into the build, never part of the image). Docker tool builds now always use a BuildKit cache mount automatically, so the download cache is shared across builds for free.

## [0.8.2] - 2026-07-05

### 🐛 Bug Fixes

- Docker `tool` builds now show the same clean, named steps as the Apptainer/Singularity backends (Presetup → Installing prerequisites → Installing tool(s) → Slimming → Cleaning) instead of echoing the whole single-layer `RUN` through the spinner. Full build output is still available with `-v` / `--verbose`.
- The Docker `tool` header now prints the base image (`ℹ️ Base image: …`), matching the SIF backends.

## [0.8.1] - 2026-07-03

### 🚀 Features

- The `tool` subcommand now always installs the latest pixi and never downgrades. The `-V` / `--pixi-version` and `-L` / `--latest` options have been removed from `tool` mode (project mode keeps them).

## [0.8.0] - 2026-07-01

### 🚀 Features

- Added the `tool` subcommand to containerize one or more conda packages directly with `pixi global install`, without needing a `pixi.toml` / `pixi.lock`. It can be run from anywhere, supports inline version pinning via conda MatchSpec (e.g. `tool fastp=0.23.4`), and can install several packages into a single image.
- `tool` images are auto-slimmed: the pixi download cache and the build-time pixi binary are removed (for Docker, install and cleanup happen in a single layer), and the default base is the small `debian:stable-slim`.
- Seamless execution is now the default for all backends (`pixi containerize`, `-singularity`, `-docker`). Use `-m` / `--manual` (or `manual = true` in the `[tool.pixitainer]` TOML table) to get a raw shell entrypoint instead.

### ⚠️ Deprecations

- `-s` / `--seamless` and the `seamless` TOML key are deprecated since 0.8.0, as seamless is now the default. They still work but print a deprecation notice; use `--manual` / `manual` to opt out.

## [0.7.1] - 2026-05-05

### 🐛 Bug Fixes

- Fixed `build_install_cmd` dropping `$extra_flags` when a single environment was specified
- Fixed `resolve_pixi_version` running `pixi -V` unnecessarily when version was already provided
- Fixed help text inconsistency: all backends now correctly say "(default: same as host)"
- Fixed temp directory collision between Apptainer and Singularity builds (`_apptainer` / `_singularity` suffix)
- Fixed temp file leak in `run_with_spinner` by adding cleanup trap
- Fixed developer install command in README (pixitainer-docker was installing the wrong package)

### 🧹 Maintenance

- Updated tests for new temp directory naming
- Added GitHub Actions CI workflow (ShellCheck, dry-run tests, TOML config validation)
- README grammar and clarity improvements

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