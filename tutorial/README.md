# Pixitainer Wiki

Learn Pixitainer step by step by containerizing one small project the whole way: a tiny Python CLI called **`copy`** that copies a file.

## How to use this wiki

- Each page is **one step**. Read it, do the exercises, then move to the next page.
- Exercises are **fill-in-the-blank**: a command or word with a missing part, like `pixi containerize -a copy.py:____`.
- **No answers are shown inline.** To check yourself, click the **spoiler** at the bottom of each exercise:

<details>
<summary>Example spoiler — click me</summary>

The answer is hidden here. Click to reveal it.

</details>

- Work through the pages **in order** — each one builds on the last.

## The example project

Everything uses the same project, [`copy-project/`](copy-project/): a `pixi.toml` manifest, a `copy.py` script, and a `pixi.lock` lockfile. You'll create it yourself in [Step 2](02-create-project.md).

## Table of contents

| # | Page | What you'll do |
|---|------|----------------|
| 1 | [Install pixi & Pixitainer](01-install.md) | Set up the tools |
| 2 | [Create the `copy` project](02-create-project.md) | Write the manifest and script |
| 3 | [Run it locally](03-run-locally.md) | Run the task with pixi |
| 4 | [Containerize with Apptainer](04-containerize-apptainer.md) | Build a `.sif` image |
| 5 | [Run the task in the container](05-run-in-container.md) | Run the task from the image |
| 6 | [The pathing gotcha](06-pathing.md) | Bind your directory, use absolute paths |
| 7 | [Manual mode](07-manual-mode.md) | Get a raw shell entrypoint |
| 8 | [Docker backend](08-docker.md) | Build the same image with Docker |
| 9 | [`tool` mode](09-tool-mode.md) | Containerize a single package, no project |
| 10 | [TOML configuration](10-toml-config.md) | Put your options in `pixi.toml` |
| 11 | [Advanced options](11-advanced-options.md) | Env vars, shared cache, GPU, pushing |

---

**Start here:** [Step 1 — Install pixi & Pixitainer](01-install.md) →
