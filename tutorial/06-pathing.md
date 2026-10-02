# Step 6 — The pathing gotcha

**Goal:** understand why the run command uses absolute paths and `--bind`, and avoid the classic errors.

## 6.1 The problem

Inside the container, the working directory is **`/opt/conf`** (where Pixitainer puts your project), *not* the directory you ran `apptainer run` from. So:

- A relative path like `input.txt` would resolve to `/opt/conf/input.txt` — which doesn't exist on your host.
- The container is **read-only** by default, so you can't write into `/opt/conf` either.

## 6.2 The fix

**Bind** your current directory into the container and use **absolute paths**:

```bash
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
```

- `--bind "$PWD:/work"` makes your current folder appear as `/work` inside the container.
- `/work/input.txt` and `/work/output.txt` are then real, writable paths.

---

## Exercises

**Exercise 6.1** — Fill in the missing word. Inside the container, the working directory is `____`:

<details>
<summary>Show answer</summary>

`/opt/conf`

```bash
# the container's cwd is /opt/conf, not your host directory
```

</details>

**Exercise 6.2** — Fill in the missing word. The container is ____ by default, so you can't write into `/opt/conf`:

<details>
<summary>Show answer</summary>

`read-only`

```bash
# use --bind + absolute paths, or add --writable-tmpfs
```

</details>

**Exercise 6.3** — Fill in the missing word. The `--bind "$PWD:/work"` flag makes your current folder appear as `____` inside the container:

<details>
<summary>Show answer</summary>

`/work`

```bash
--bind "$PWD:/work"   # host $PWD → container /work
```

</details>

**Exercise 6.4** — Fill in the missing word. If a task tries to write to `/opt/conf` you get the error `os error ____` (read-only file system):

<details>
<summary>Show answer</summary>

`30`

```bash
# os error 30 = read-only file system
# fix: --bind + absolute paths, or --writable-tmpfs
```

</details>

---

**← Back:** [Step 5 — Run in the container](05-run-in-container.md) · **Next:** [Step 7 — Manual mode](07-manual-mode.md) →
