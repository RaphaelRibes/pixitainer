# Pixitainer Tutorial: Containerize a Python project in 10 minutes

This tutorial walks you through **Pixitainer** from zero to a working container, using one small project the whole way: a tiny Python command-line tool called **`copy`** that copies a file.

You'll learn, step by step:

1. Install pixi and Pixitainer
2. Create the `copy` project
3. Run it locally with pixi
4. Containerize it with **Apptainer** (seamless mode)
5. Run the task inside the container
6. Handle the container pathing gotcha
7. Use **manual** mode
8. Build the same image with **Docker**
9. Containerize a single tool with no project at all (`tool` mode)
10. Configure everything in your `pixi.toml`

Every command below was tested and works. The finished example project lives in [`copy-project/`](copy-project/).

---

## What is Pixitainer?

Pixitainer is a [pixi extension](https://pixi.sh/latest/integration/extensions/introduction/) that puts your pixi environment into a container image — **Apptainer/Singularity** (`.sif`) or **Docker**. You keep developing with the fast, easy pixi workflow, and when you're ready you freeze that environment into a portable, reproducible image.

The idea: *pixi is fast and easy but not a container; containers are portable but a pain to set up. Pixitainer gives you both.*

---

## Prerequisites

- **Linux** (Apptainer and Singularity don't run on macOS/Windows)
- **pixi** — install it in Step 1
- **Apptainer** *or* **Docker** (or both) to build and run the images

---

## Step 1 — Install pixi and Pixitainer

Install pixi:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

Then install Pixitainer globally. Pick the backend you'll use:

```bash
# Apptainer
pixi global install -c https://prefix.dev/raphaelribes pixitainer

# Singularity
pixi global install -c https://prefix.dev/raphaelribes pixitainer-singularity

# Docker
pixi global install -c https://prefix.dev/raphaelribes pixitainer-docker
```

> **Note:** if pixi isn't on your `PATH` in a new shell, add it: `export PATH="$HOME/.pixi/bin:$PATH"`.

Check it works:

```bash
pixi containerize --help
```

You should see the Pixitainer usage text.

---

## Step 2 — Create the `copy` project

Make a directory and a `pixi.toml`:

```bash
mkdir copy-project && cd copy-project
```

Create `pixi.toml`:

```toml
[workspace]
name = "copy"
version = "0.1.0"
description = "A tiny Python CLI that copies files"
channels = ["conda-forge"]
platforms = ["linux-64"]

[dependencies]
python = ">=3.11"

[tasks]
copy = "python copy.py"
```

Now create the actual tool, `copy.py` — a tiny file-copying CLI using only the Python standard library:

```python
#!/usr/bin/env python3
"""copy — a tiny file-copying CLI.

Usage: copy SRC DEST
"""
import shutil
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: copy SRC DEST", file=sys.stderr)
        return 2
    src, dest = sys.argv[1], sys.argv[2]
    shutil.copy2(src, dest)
    print(f"Copied {src} -> {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Install the environment (this creates `pixi.lock`, which pins every dependency for reproducibility):

```bash
pixi install
```

---

## Step 3 — Run it locally with pixi

Create a test file and run the `copy` task:

```bash
echo "hello pixitainer" > input.txt
pixi run copy input.txt output.txt
```

You should see:

```
✨ Pixi task (copy): python copy.py input.txt output.txt
Copied input.txt -> output.txt
```

Check the result and clean up:

```bash
cat output.txt        # → hello pixitainer
rm -f input.txt output.txt
```

Your project works. Now let's freeze it into a container.

---

## Step 4 — Containerize it with Apptainer (seamless mode)

From inside `copy-project/`, build the image:

```bash
pixi containerize -a copy.py:/opt/conf/copy.py -o copy.sif
```

Let's unpack that command:

- `pixi containerize` — the Apptainer backend (default mode is **seamless**: the image's entrypoint is `pixi run`, so you call your tasks directly).
- `-a copy.py:/opt/conf/copy.py` — **add a file** into the image. Pixitainer only copies your manifest (`pixi.toml`) and lockfile (`pixi.lock`) into the container automatically. Your actual script `copy.py` is *not* — so we add it with `-a SRC:DEST`. Without this, the container can't find `copy.py`.
- `-o copy.sif` — the output image path (default is `pixitainer.sif`).

When the build finishes you'll have a `copy.sif` file — a self-contained Apptainer image.

> **Tip:** want to see what Pixitainer *would* build without actually building? Add `-d` (dry-run) to print the generated `.def` file to stdout.

---

## Step 5 — Run the task inside the container

Now run the `copy` task from the image, exactly like you ran it with pixi:

```bash
echo "hello from container" > input.txt
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
```

You should see:

```
✨ Pixi task (copy): python copy.py /work/input.txt /work/output.txt
Copied /work/input.txt -> /work/output.txt
```

Verify and clean up:

```bash
cat output.txt        # → hello from container
rm -f input.txt output.txt
```

Your pixi environment is now running **inside a container**. The same `copy.sif` will run identically on any machine with Apptainer — that's the whole point.

---

## Step 6 — The pathing gotcha (read this!)

You probably noticed the run command uses **absolute paths** (`/work/input.txt`) and a **`--bind`** flag. That's not random — it's the one thing that trips everyone up.

Inside the container, the working directory is **`/opt/conf`** (where Pixitainer puts your project), *not* the directory you ran `apptainer run` from. So:

- A relative path like `input.txt` would resolve to `/opt/conf/input.txt` — which doesn't exist on your host.
- The container is **read-only** by default, so you can't write into `/opt/conf` either.

The fix is to **bind** your current directory into the container and use absolute paths:

```bash
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
```

- `--bind "$PWD:/work"` makes your current folder appear as `/work` inside the container.
- `/work/input.txt` and `/work/output.txt` are then real, writable paths.

> **If you get `os error 30` (read-only file system):** this is the same issue — a task tried to write to `/opt/conf`. Use `--bind` + absolute paths, or add `--writable-tmpfs` to `apptainer run`.

---

## Step 7 — Manual mode (`-m`)

Seamless mode is great for running pixi tasks. But sometimes you want a **raw shell** inside the image — for example to poke around, run arbitrary commands, or use the environment interactively.

Build with manual mode:

```bash
pixi containerize -m -a copy.py:/opt/conf/copy.py -o copy-manual.sif
```

Now the entrypoint is a plain shell, and you call `pixi` yourself:

```bash
apptainer run -f --bind "$PWD:/work" copy-manual.sif \
    pixi run --as-is -m /opt/conf/pixi.toml copy /work/input.txt /work/output.txt
```

> **Note:** `-m /opt/conf/pixi.toml` is mandatory in manual mode — otherwise pixi looks for a manifest in the current directory and won't find your project.

You can also drop into an interactive shell:

```bash
apptainer shell copy-manual.sif
```

---

## Step 8 — Build the same image with Docker

Everything you just did with Apptainer works with Docker too. The command is `pixi containerize-docker`:

```bash
pixi containerize-docker -a copy.py:/opt/conf/copy.py -o copy:latest
```

> **Note:** for Docker, `-o` is an image **tag** (default `pixitainer:latest`), not a file path.

Run the task:

```bash
echo "hello from docker" > input.txt
docker run --rm -v "$PWD:/work" copy:latest copy /work/input.txt /work/output.txt
```

- `--rm` removes the container after it exits.
- `-v "$PWD:/work"` is Docker's version of `--bind` — it mounts your current directory as `/work`.

Verify and clean up:

```bash
cat output.txt        # → hello from docker
rm -f input.txt output.txt
```

---

## Step 9 — Containerize a single tool (no project needed)

Since **v0.8.0**, you don't need a `pixi.toml` at all. The `tool` subcommand pulls one or more conda packages straight into an image, from anywhere on your system.

For example, containerize `jq` (a JSON processor):

```bash
pixi containerize tool -o jq.sif jq
```

Then run it — the tool's binary is the image entrypoint, so you call it directly:

```bash
echo '{"tool":"pixitainer"}' | apptainer run jq.sif jq .tool
# → "pixitainer"
```

You can pin versions with conda MatchSpec syntax, and install several tools into one image:

```bash
pixi containerize tool 'python>=3.11' jq
pixi containerize tool -c bioconda samtools bcftools
```

> **Note:** with several packages there's no single binary to bind, so the image falls back to a manual entrypoint — run each tool by name.

---

## Step 10 — Configure everything in `pixi.toml`

Instead of typing flags every time, you can put your options in the manifest. Since **v0.6.0**, Pixitainer reads a `[tool.pixitainer]` table; since **v0.7.0** it supports per-backend overrides.

Add this to your `pixi.toml`:

```toml
[tool.pixitainer]
output = "copy.sif"
add-file = ["copy.py:/opt/conf/copy.py"]
```

Now a plain `pixi containerize` picks up those defaults:

```bash
pixi containerize
```

You can still override on the command line — **CLI arguments always win**:

```bash
pixi containerize -o my-copy.sif
```

Per-backend overrides let you set different defaults for Apptainer vs Docker:

```toml
[tool.pixitainer]
output = "copy.sif"
add-file = ["copy.py:/opt/conf/copy.py"]

[tool.pixitainer.docker]
output = "copy:latest"
```

Priority (lowest → highest):

```
[tool.pixitainer]  <  [tool.pixitainer.<backend>]  <  CLI arguments
```

---

## Troubleshooting

**`os error 30` — read-only file system**
A task tried to write to `/opt/conf`. Bind your working directory and use absolute paths, or add `--writable-tmpfs` to `apptainer run`.

**`Failed to create mount namespace` (Debian/Ubuntu)**
Apptainer needs unprivileged user namespaces. Add an alias to your `.bashrc` and run it after each boot:

```bash
alias fixnamespace="sudo sysctl -w kernel.unprivileged_userns_clone=1 && sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0"
```

**`No such file or directory: 'copy.py'` inside the container**
You forgot `-a copy.py:/opt/conf/copy.py`. Pixitainer only copies the manifest and lockfile automatically — add your scripts with `-a SRC:DEST`.

**`No candidates were found for <package>` in `tool` mode**
The package isn't on the channel. Use a real conda-forge package name, or add a channel with `-c` (e.g. `-c bioconda`).

---

## Recap

You took a tiny Python project, ran it locally with pixi, and froze it into portable Apptainer and Docker images — then ran the same task inside those containers. You also learned the two things that trip everyone up: **adding your own files with `-a`** and **binding your working directory with `--bind`/`-v`**.

The complete example project is in [`copy-project/`](copy-project/) — copy it, run the steps, and you're containerizing your own projects in minutes.
