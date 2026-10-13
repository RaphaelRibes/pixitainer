# Pixitainer Wiki

Learn Pixitainer step by step by containerizing one small project the whole way: a tiny Python CLI called **`thumb`** that turns any image into a thumbnail.

## How to use this wiki

- Each page is **one step**. Read it, run the commands, then move to the next page.
- Most pages end with a **Try it** section — a short exercise that makes you use what you just learned, with the expected output shown inline.
- Work through the pages **in order** — each one builds on the last.

## The example project

Everything uses the same project, [`thumb-project/`](thumb-project/): a `pixi.toml` manifest, a `thumb.py` script, and a `pixi.lock` lockfile. You'll create it yourself in [Step 2](02-create-project.md). It's deliberately small and dependency-light (Python + Pillow) so you can follow along with any image you have.

## Table of contents

| # | Page | What you'll do |
|---|------|----------------|
| 1 | [Install pixi & Pixitainer](01-install.md) | Set up the tools |
| 2 | [Create the `thumb` project](02-create-project.md) | Write the manifest and script |
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
