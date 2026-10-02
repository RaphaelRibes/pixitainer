# Step 11 — Advanced options

**Goal:** get to know Pixitainer's advanced flags: environment variables, a shared package cache, GPU support, and pushing images to a registry.

These were added in **v0.9.0**. They work across both the Apptainer/Singularity and Docker backends unless noted.

## 11.1 Environment variables

Pass `KEY=VAL` pairs that become environment variables inside the container. Use them for API keys, config, or any value your app reads at runtime.

```bash
pixi containerize -a copy.py:/opt/conf/copy.py --env-var FOO=bar -o copy.sif
```

You can repeat `--env-var` for several variables, or read them from a file with `--env-file` (one `KEY=VAL` per line):

```bash
pixi containerize --env-file my.env -o copy.sif
```

On the SIF backends these become `export FOO="bar"` lines in the image's `%environment`; on Docker they become `ENV` instructions. They're baked in at build time, so no flag is needed at `run`.

## 11.2 Shared package cache (Apptainer/Singularity)

Every build re-downloads and re-installs your dependencies. A **cache directory** lets one build reuse another's packages, making repeated builds much faster.

```bash
pixi containerize --cache-dir /tmp/pkgcache -o copy.sif
```

The cache is bind-mounted into the container during the build (`%setup` mounts `/root/.cache`). Point several projects at the same directory to share it.

> **Note:** this flag is Apptainer/Singularity-only. Docker builds cache via BuildKit automatically.

## 11.3 GPU support

If your workflow needs the GPU (PyTorch, CUDA, etc.), add `--gpu`. It loads the NVIDIA runtime so the image can access your GPU at run time:

```bash
# build
pixi containerize --gpu -o copy.sif

# run — you must also pass --nv to Apptainer / --gpus all to Docker
apptainer run --nv copy.sif ...
docker run --gpus all ...
```

## 11.4 Pushing to a registry

`--push` builds and then pushes the image to an OCI/ORAS registry.

```bash
# ORAS (SIF backends)
pixi containerize -o copy.sif --push oras://ghcr.io/you/copy:v0.1

# Docker
pixi containerize-docker --push copy:latest
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

## Exercises

**Exercise 11.1** — Fill in the missing word. The flag to inject an environment variable is `--env-____`:

<details>
<summary>Show answer</summary>

`var`

```bash
pixi containerize --env-var FOO=bar -o copy.sif
```

</details>

**Exercise 11.2** — Fill in the missing word. `--cache-dir` lets one build __Reuse__ another's downloaded packages:

<details>
<summary>Show answer</summary>

`reuse` (a shared package cache speeds up repeated builds)

</details>

**Exercise 11.3** — Fill in the missing word. To use the GPU at run time you also pass `--__` to Apptainer:

<details>
<summary>Show answer</summary>

`nv`

```bash
apptainer run --nv copy.sif ...
```

</details>

**Exercise 11.4** — Fill in the missing word. `--push` sends the image to a __.

<details>
<summary>Show answer</summary>

`registry`

```bash
pixi containerize -o copy.sif --push oras://ghcr.io/you/copy:v0.1
```

</details>

---

**← Finish:** this is the last step. **Back to the [index](README.md)**
