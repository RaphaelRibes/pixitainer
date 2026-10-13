# Step 8 — Docker backend

**Goal:** build and run the same `thumb` image with Docker.

## 8.1 Build the image

Everything you did with Apptainer works with Docker too. The command is `pixi containerize-docker`:

```bash
pixi containerize-docker -a thumb.py:/opt/conf/thumb.py -o thumb:latest
```

> **Note:** for Docker, `-o` is an image **tag** (default `pixitainer:latest`), not a file path.

## 8.2 Run the task

```bash
docker run --rm -v "$PWD:/work" thumb:latest thumb -w 100 /work/photo.png /work/small.png
```

- `--rm` removes the container after it exits.
- `-v "$PWD:/work"` is Docker's version of `--bind` — it mounts your current directory as `/work`.

## 8.3 Verify and clean up

```bash
file small.png        # → PNG image data, 99 x 62
rm -f small.png
```

The project runs identically in Docker — same task, same flags, same output. The only differences are the backend command (`containerize-docker`) and the `-o`/`-v` syntax.

---

**← Back:** [Step 7 — Manual mode](07-manual-mode.md) · **Next:** [Step 9 — `tool` mode](09-tool-mode.md) →
