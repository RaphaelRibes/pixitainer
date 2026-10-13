# Step 11 — Advanced options

**Goal:** get to know Pixitainer's advanced flags: environment variables, a shared package cache, GPU support, and pushing images to a registry.

These were added in **v0.9.0**. They work across both the Apptainer/Singularity and Docker backends unless noted.

## 11.1 Environment variables

Pass `KEY=VAL` pairs that become environment variables inside the container. Use them for API keys, config, or any value your app reads at runtime.

```bash
pixi containerize -a thumb.py:/opt/conf/thumb.py --env-var FOO=bar -o thumb.sif
```

You can repeat `--env-var` for several variables, or read them from a file with `--env-file` (one `KEY=VAL` per line):

```bash
pixi containerize --env-file my.env -o thumb.sif
```

On the SIF backends these become `export FOO="bar"` lines in the image's `%environment`; on Docker they become `ENV` instructions. They're baked in at build time, so no flag is needed at `run`.

## 11.2 Shared package cache (Apptainer/Singularity)

Every build re-downloads and re-installs your dependencies. A **cache directory** lets one build reuse another's packages, making repeated builds much faster.

```bash
pixi containerize --cache-dir /tmp/pkgcache -o thumb.sif
```

The cache is bind-mounted into the container during the build (`%setup` mounts `/root/.cache`). Point several projects at the same directory to share it.

> **Note:** this flag is Apptainer/Singularity-only. Docker builds cache via BuildKit automatically.

## 11.3 GPU support

If your workflow needs the GPU (PyTorch, CUDA, etc.), add `--gpu`. It loads the NVIDIA runtime so the image can access your GPU at run time:

```bash
# build
pixi containerize --gpu -o thumb.sif

# run — you must also pass --nv to Apptainer / --gpus all to Docker
apptainer run --nv thumb.sif ...
docker run --gpus all ...
```

## 11.4 Pushing to a registry

`--push` builds and then pushes the image to an OCI/ORAS registry.

```bash
# ORAS (SIF backends)
pixi containerize -o thumb.sif --push oras://ghcr.io/you/thumb:v0.1

# Docker
pixi containerize-docker --push thumb:latest
```

For Docker, `--push` uses your existing registry login (e.g. `docker login`).

## 11.5 Other useful flags

| Flag | Backend | What it does |
|------|---------|--------------|
| `--arch ARCH` | SIF | Target architecture (e.g. `amd64`, `arm64`) |
| `--no-fakeroot` | SIF | Build as the invoking user instead of root |
| `--build-arg KEY=VAL` | SIF | Build-time variable, substituted as `{{ KEY }}` |
| `--squash` | Docker | Squash all layers into one |
| `--platform` | Docker | Target platform(s), e.g. `linux/arm64` |
| `--network MODE` | Docker | Build-time network: `bridge`/`host`/`none` |
| `--secret id=X,src=FILE` | Docker | BuildKit secret (never baked into layers) |
| `--ssh AGENT` | Docker | Forward an SSH agent into the build |

Dry-run tip: add `-d` to *any* of these commands to print the generated `.def`/`Dockerfile` without building, so you can inspect exactly what each flag produces.

---

## Try it

Pick one flag and inspect what it actually changes in the generated definition:

```bash
pixi containerize -d --env-var FOO=bar -o thumb.sif
```

Look for the `%environment` block — you'll see `export FOO="bar"` appear. Then try `--gpu` and look for the `Pixitainer_GPU` label. Dry-run is the fastest way to learn what each flag does without waiting for a build.

---

**← Finish:** this is the last step. **Back to the [index](README.md)**
