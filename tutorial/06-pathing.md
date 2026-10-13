# Step 6 — The pathing gotcha

**Goal:** understand why the run command uses absolute paths and `--bind`, and avoid the classic errors.

## 6.1 The problem

Inside the container, the working directory is **`/opt/conf`** (where Pixitainer puts your project), *not* the directory you ran `apptainer run` from. So:

- A relative path like `photo.png` would resolve to `/opt/conf/photo.png` — which doesn't exist on your host.
- The container is **read-only** by default, so you can't write into `/opt/conf` either.

## 6.2 The fix

**Bind** your current directory into the container and use **absolute paths**:

```bash
apptainer run -f --bind "$PWD:/work" thumb.sif thumb -w 100 /work/photo.png /work/small.png
```

- `--bind "$PWD:/work"` makes your current folder appear as `/work` inside the container.
- `/work/photo.png` and `/work/small.png` are then real, writable paths.

---

## Try it

Run the exact same command but **without** `--bind`, passing a relative path:

```bash
apptainer run -f thumb.sif thumb -w 100 photo.png small.png
```

You'll get a "No such file or directory" (or a crash trying to write to a read-only FS). This is the single most common mistake with Pixitainer images — once you've hit it and understood *why*, the `--bind` habit sticks.

---

**← Back:** [Step 5 — Run in the container](05-run-in-container.md) · **Next:** [Step 7 — Manual mode](07-manual-mode.md) →
