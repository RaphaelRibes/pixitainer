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

## Exercises

**Exercise 1.1** — Fill in the missing word. Pixi is installed with:

```bash
curl -fsSL https://pixi.sh/____.sh | sh
```

<details>
<summary>Show answer</summary>

`install`

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

</details>

**Exercise 1.2** — Fill in the missing word. Pixitainer is installed *globally* with the `pixi global ____` command:

```bash
pixi global ____ -c https://prefix.dev/raphaelribes pixitainer
```

<details>
<summary>Show answer</summary>

`install`

```bash
pixi global install -c https://prefix.dev/raphaelribes pixitainer
```

</details>

**Exercise 1.3** — Fill in the missing word. To check Pixitainer is installed, you run `pixi containerize ____`:

```bash
pixi containerize ____
```

<details>
<summary>Show answer</summary>

`--help`

```bash
pixi containerize --help
```

</details>

---

**Next:** [Step 2 — Create the `copy` project](02-create-project.md) →
