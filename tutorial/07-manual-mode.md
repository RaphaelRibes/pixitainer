# Step 7 — Manual mode

**Goal:** build an image with a raw shell entrypoint, so you call `pixi` yourself.

## 7.1 Build with manual mode

Seamless mode (default) is great for running pixi tasks. But sometimes you want a **raw shell** inside the image — to poke around, run arbitrary commands, or use the environment interactively.

Build with manual mode:

```bash
pixi containerize -m -a copy.py:/opt/conf/copy.py -o copy-manual.sif
```

## 7.2 Run a task manually

Now the entrypoint is a plain shell, and you call `pixi` yourself:

```bash
apptainer run -f --bind "$PWD:/work" copy-manual.sif \
    pixi run --as-is -m /opt/conf/pixi.toml copy /work/input.txt /work/output.txt
```

> **Note:** `-m /opt/conf/pixi.toml` is mandatory in manual mode — otherwise pixi looks for a manifest in the current directory and won't find your project.

## 7.3 Drop into a shell

```bash
apptainer shell copy-manual.sif
```

---

## Exercises

**Exercise 7.1** — Fill in the missing word. The flag for manual mode is `-____` (or `--manual`):

<details>
<summary>Show answer</summary>

`m`

```bash
pixi containerize -m -a copy.py:/opt/conf/copy.py -o copy-manual.sif
```

</details>

**Exercise 7.2** — Fill in the missing word. In manual mode, the entrypoint is a plain ____, not `pixi run`:

<details>
<summary>Show answer</summary>

`shell`

```bash
# you call pixi yourself inside the image
```

</details>

**Exercise 7.3** — Fill in the missing word. In manual mode you must pass `-m /opt/conf/____` so pixi finds your manifest:

<details>
<summary>Show answer</summary>

`pixi.toml`

```bash
pixi run --as-is -m /opt/conf/pixi.toml copy /work/input.txt /work/output.txt
```

</details>

**Exercise 7.4** — Fill in the missing word. To get an interactive shell inside the image, use `apptainer ____`:

<details>
<summary>Show answer</summary>

`shell`

```bash
apptainer shell copy-manual.sif
```

</details>

---

**← Back:** [Step 6 — The pathing gotcha](06-pathing.md) · **Next:** [Step 8 — Docker backend](08-docker.md) →
