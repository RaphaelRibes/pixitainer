# Step 7 — Manual mode

**Goal:** build an image with a raw shell entrypoint, so you call `pixi` yourself.

## 7.1 Build with manual mode

Seamless mode (default) is great for running pixi tasks. But sometimes you want a **raw shell** inside the image — to poke around, run arbitrary commands, or use the environment interactively.

Build with manual mode:

```bash
pixi containerize -m -a thumb.py:/opt/conf/thumb.py -o thumb-manual.sif
```

## 7.2 Run a task manually

Now the entrypoint is a plain shell, and you call `pixi` yourself:

```bash
apptainer run -f --bind "$PWD:/work" thumb-manual.sif \
    pixi run --as-is -m /opt/conf/pixi.toml thumb -w 100 /work/photo.png /work/small.png
```

> **Note:** `-m /opt/conf/pixi.toml` is mandatory in manual mode — otherwise pixi looks for a manifest in the current directory and won't find your project.

## 7.3 Drop into a shell

```bash
apptainer shell thumb-manual.sif
```

You'll get an interactive shell inside the image. Run anything you'd type with pixi:

```bash
pixi run --as-is -m /opt/conf/pixi.toml python -c "import PIL; print(PIL.__version__)"
```

> **Note:** in manual mode, only `pixi` is on `$PATH` — your environment's tools (like `python`) are reached *through* pixi, not directly. That's why the `-m /opt/conf/pixi.toml` prefix is needed on every command.

---

## Try it

Compare the two run commands side by side:

| Mode | Entrypoint handles | You must type |
|------|-------------------|---------------|
| Seamless | `pixi run` | `thumb -w 100 ...` |
| Manual | a shell | `pixi run --as-is -m /opt/conf/pixi.toml thumb -w 100 ...` |

Seamless saves you the `-m /opt/conf/pixi.toml` ceremony on every call. Manual is what you want when you're debugging or calling the environment non-interactively from a script.

---

**← Back:** [Step 6 — The pathing gotcha](06-pathing.md) · **Next:** [Step 8 — Docker backend](08-docker.md) →
