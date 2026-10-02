# Step 9 — `tool` mode

**Goal:** containerize a single conda package with no project at all.

## 9.1 Containerize a tool

Since **v0.8.0**, you don't need a `pixi.toml`. The `tool` subcommand pulls one or more conda packages straight into an image, from anywhere on your system.

For example, containerize `jq` (a JSON processor):

```bash
pixi containerize tool -o jq.sif jq
```

## 9.2 Run the tool

The tool's binary is the image entrypoint, so you call it directly:

```bash
echo '{"tool":"pixitainer"}' | apptainer run jq.sif jq .tool
# → "pixitainer"
```

## 9.3 Pin versions and add channels

You can pin versions with conda MatchSpec syntax, and install several tools into one image:

```bash
pixi containerize tool 'python>=3.11' jq
pixi containerize tool -c bioconda samtools bcftools
```

> **Note:** with several packages there's no single binary to bind, so the image falls back to a manual entrypoint — run each tool by name.

---

## Exercises

**Exercise 9.1** — Fill in the missing word. The `tool` subcommand needs no `pixi.____`:

<details>
<summary>Show answer</summary>

`toml`

```bash
# tool mode runs standalone, no manifest needed
```

</details>

**Exercise 9.2** — Fill in the missing word. To containerize `jq`, you run `pixi containerize ____ jq`:

<details>
<summary>Show answer</summary>

`tool`

```bash
pixi containerize tool -o jq.sif jq
```

</details>

**Exercise 9.3** — Fill in the missing word. The tool's binary is the image ____, so you call it directly:

<details>
<summary>Show answer</summary>

`entrypoint`

```bash
apptainer run jq.sif jq .tool
```

</details>

**Exercise 9.4** — Fill in the missing word. To add a channel like `bioconda`, use the `-____` flag:

<details>
<summary>Show answer</summary>

`c` (channel)

```bash
pixi containerize tool -c bioconda samtools bcftools
```

</details>

---

**← Back:** [Step 8 — Docker](08-docker.md) · **Next:** [Step 10 — TOML configuration](10-toml-config.md) →
