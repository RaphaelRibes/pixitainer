# Step 8 — Docker backend

**Goal:** build and run the same `copy` image with Docker.

## 8.1 Build the image

Everything you did with Apptainer works with Docker too. The command is `pixi containerize-docker`:

```bash
pixi containerize-docker -a copy.py:/opt/conf/copy.py -o copy:latest
```

> **Note:** for Docker, `-o` is an image **tag** (default `pixitainer:latest`), not a file path.

## 8.2 Run the task

```bash
echo "hello from docker" > input.txt
docker run --rm -v "$PWD:/work" copy:latest copy /work/input.txt /work/output.txt
```

- `--rm` removes the container after it exits.
- `-v "$PWD:/work"` is Docker's version of `--bind` — it mounts your current directory as `/work`.

## 8.3 Verify and clean up

```bash
cat output.txt        # → hello from docker
rm -f input.txt output.txt
```

---

## Exercises

**Exercise 8.1** — Fill in the missing word. The Docker backend command is `pixi containerize-____`:

<details>
<summary>Show answer</summary>

`docker`

```bash
pixi containerize-docker -a copy.py:/opt/conf/copy.py -o copy:latest
```

</details>

**Exercise 8.2** — Fill in the missing word. For Docker, `-o` sets the image ____ (not a file path):

<details>
<summary>Show answer</summary>

`tag`

```bash
-o copy:latest
```

</details>

**Exercise 8.3** — Fill in the missing word. Docker's version of `--bind` is the `-____` flag:

<details>
<summary>Show answer</summary>

`v` (volume)

```bash
docker run --rm -v "$PWD:/work" copy:latest copy /work/input.txt /work/output.txt
```

</details>

**Exercise 8.4** — Fill in the missing word. The `--____` flag removes the container after it exits:

<details>
<summary>Show answer</summary>

`rm`

```bash
docker run --rm ...
```

</details>

---

**← Back:** [Step 7 — Manual mode](07-manual-mode.md) · **Next:** [Step 9 — `tool` mode](09-tool-mode.md) →
