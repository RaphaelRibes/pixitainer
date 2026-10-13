# Step 4 — Containerize with Apptainer

**Goal:** build a `.sif` Apptainer image from your `thumb` project.

## 4.1 Build the image

From inside `thumb-project/`, run:

```bash
pixi containerize -a thumb.py:/opt/conf/thumb.py -o thumb.sif
```

Unpacking that command:

- `pixi containerize` — the **Apptainer** backend. Default mode is **seamless**: the image's entrypoint is `pixi run`, so you call your tasks directly.
- `-a thumb.py:/opt/conf/thumb.py` — **add a file** into the image. Pixitainer only copies your manifest (`pixi.toml`) and lockfile (`pixi.lock`) automatically. Your script `thumb.py` is *not* — so you add it with `-a SRC:DEST`.
- `-o thumb.sif` — the output image path (default is `pixitainer.sif`).

When it finishes you'll have a `thumb.sif` file — a self-contained Apptainer image with Python + Pillow baked in.

> **Tip:** add `-d` (dry-run) to print the generated `.def` file without building.

---

## Try it

Run with `-d` and read the generated `.def`:

```bash
pixi containerize -d -a thumb.py:/opt/conf/thumb.py -o thumb.sif
```

Look at the `%files` block. You'll see exactly three things copied in: your manifest, your lockfile, and your script — nothing else. That's the core mental model of Pixitainer: it ships the **environment** (from `pixi.lock`), and you ship the **code** (with `-a`).

---

**← Back:** [Step 3 — Run it locally](03-run-locally.md) · **Next:** [Step 5 — Run the task in the container](05-run-in-container.md) →
