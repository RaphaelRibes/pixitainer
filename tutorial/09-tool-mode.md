# Step 9 — `tool` mode

**Goal:** containerize a single conda package with no project at all.

## 9.1 The scenario

So far you've containerized a full pixi project. But sometimes you just want **one tool** — a single binary you can run anywhere, with no project folder and no manifest.

## 9.2 Containerize a tool

Since **v0.8.0**, `pixi containerize tool` pulls one or more conda packages straight into an image, from anywhere on your system. For example, containerize `jq` (a JSON processor):

```bash
pixi containerize tool -o jq.sif jq
```

## 9.3 Run the tool

The tool's binary is the image entrypoint, so you call it directly:

```bash
echo '{"tool":"pixitainer"}' | apptainer run jq.sif jq .tool
# → "pixitainer"
```

## 9.4 Pin versions and add channels

You can pin versions with conda MatchSpec syntax, and install several tools into one image:

```bash
pixi containerize tool 'python>=3.11' jq
pixi containerize tool -c bioconda samtools bcftools
```

> **Note:** with several packages there's no single binary to bind, so the image falls back to a manual entrypoint — run each tool by name.

---

## Try it

Compare the two modes you now know:

| Mode | Command | What's in the image |
|------|---------|---------------------|
| Project | `pixi containerize -a thumb.py:...` | Your manifest-env **plus** your code |
| Tool | `pixi containerize tool jq` | Just a conda package — no code of yours |

Use **project** mode when you're shipping *your own* code with its environment. Use **tool** mode to freeze a ready-made CLI (or a set of them) into a portable image.

---

**← Back:** [Step 8 — Docker](08-docker.md) · **Next:** [Step 10 — TOML configuration](10-toml-config.md) →
