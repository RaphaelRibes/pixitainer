# Step 1 — Install pixi & Pixitainer

**Goal:** get pixi and Pixitainer on your machine.

## 1.1 Install pixi

Pixi is a fast, easy dependency manager. Install it with:

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

> **Note:** if pixi isn't on your `PATH` in a new shell, add it:
> `export PATH="$HOME/.pixi/bin:$PATH"`

## 1.2 Install Pixitainer

Pixitainer is a pixi extension. Install it globally, choosing the backend you'll use:

```bash
# Apptainer
pixi global install -c https://prefix.dev/raphaelribes pixitainer

# Singularity
pixi global install -c https://prefix.dev/raphaelribes pixitainer-singularity

# Docker
pixi global install -c https://prefix.dev/raphaelribes pixitainer-docker
```

## 1.3 Check it works

```bash
pixi containerize --help
```

You should see the Pixitainer usage text.

---

**Next:** [Step 2 — Create the `thumb` project](02-create-project.md) →
