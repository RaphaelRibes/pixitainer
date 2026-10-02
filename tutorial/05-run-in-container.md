# Step 5 — Run the task in the container

**Goal:** run the `copy` task from the `.sif` image, exactly like you ran it with pixi.

## 5.1 Run the task

```bash
echo "hello from container" > input.txt
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
```

You should see:

```
✨ Pixi task (copy): python copy.py /work/input.txt /work/output.txt
Copied /work/input.txt -> /work/output.txt
```

## 5.2 Verify and clean up

```bash
cat output.txt        # → hello from container
rm -f input.txt output.txt
```

Your pixi environment is now running **inside a container**. The same `copy.sif` will run identically on any machine with Apptainer — that's the whole point.

---

## Exercises

**Exercise 5.1** — Fill in the missing word. You run a task from the image with `apptainer ____`:

<details>
<summary>Show answer</summary>

`run`

```bash
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
```

</details>

**Exercise 5.2** — Fill in the missing word. The `-f` flag tells Apptainer to run the image as a ____ (not a sandbox):

<details>
<summary>Show answer</summary>

`file` (a single-file SIF image)

```bash
apptainer run -f copy.sif ...
```

</details>

**Exercise 5.3** — Fill in the missing word. The `--bind "$PWD:/work"` flag makes your current directory appear as `____` inside the container:

<details>
<summary>Show answer</summary>

`/work`

```bash
--bind "$PWD:/work"   # host $PWD → container /work
```

</details>

**Exercise 5.4** — Fill in the missing word. The task name you pass to the image is `____`:

<details>
<summary>Show answer</summary>

`copy`

```bash
apptainer run -f --bind "$PWD:/work" copy.sif copy /work/input.txt /work/output.txt
#                                                       ^^^^ the task
```

</details>

---

**← Back:** [Step 4 — Containerize](04-containerize-apptainer.md) · **Next:** [Step 6 — The pathing gotcha](06-pathing.md) →
