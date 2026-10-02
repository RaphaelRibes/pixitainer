# Step 4 — Containerize with Apptainer

**Goal:** build a `.sif` Apptainer image from your `copy` project.

## 4.1 Build the image

From inside `copy-project/`, run:

```bash
pixi containerize -a copy.py:/opt/conf/copy.py -o copy.sif
```

Let's unpack that command:

- `pixi containerize` — the **Apptainer** backend. Default mode is **seamless**: the image's entrypoint is `pixi run`, so you call your tasks directly.
- `-a copy.py:/opt/conf/copy.py` — **add a file** into the image. Pixitainer only copies your manifest (`pixi.toml`) and lockfile (`pixi.lock`) automatically. Your script `copy.py` is *not* — so you add it with `-a SRC:DEST`.
- `-o copy.sif` — the output image path (default is `pixitainer.sif`).

When it finishes you'll have a `copy.sif` file — a self-contained Apptainer image.

> **Tip:** add `-d` (dry-run) to print the generated `.def` file without building.

---

## Exercises

**Exercise 4.1** — Fill in the missing word. The Apptainer backend command is `pixi ____`:

<details>
<summary>Show answer</summary>

`containerize`

```bash
pixi containerize -a copy.py:/opt/conf/copy.py -o copy.sif
```

</details>

**Exercise 4.2** — Fill in the missing word. The `-a` flag **adds a ____** into the image:

<details>
<summary>Show answer</summary>

`file`

```bash
-a copy.py:/opt/conf/copy.py   # add copy.py into the image
```

</details>

**Exercise 4.3** — Fill in the missing word. The `-o` flag sets the output image ____:

<details>
<summary>Show answer</summary>

`path` (or `name`)

```bash
-o copy.sif
```

</details>

**Exercise 4.4** — Fill in the missing word. To see the generated `.def` file *without* building, add the `-____` flag:

<details>
<summary>Show answer</summary>

`d` (dry-run)

```bash
pixi containerize -d -a copy.py:/opt/conf/copy.py -o copy.sif
```

</details>

---

**← Back:** [Step 3 — Run it locally](03-run-locally.md) · **Next:** [Step 5 — Run the task in the container](05-run-in-container.md) →
