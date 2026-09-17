# Step 10 — TOML configuration

**Goal:** put your Pixitainer options in `pixi.toml` instead of typing flags every time.

## 10.1 Add a `[tool.pixitainer]` table

Since **v0.6.0**, Pixitainer reads a `[tool.pixitainer]` table in your manifest. Add this to `pixi.toml`:

```toml
[tool.pixitainer]
output = "copy.sif"
add-file = ["copy.py:/opt/conf/copy.py"]
```

Now a plain `pixi containerize` picks up those defaults:

```bash
pixi containerize
```

## 10.2 Override on the command line

CLI arguments **always win** over the TOML table:

```bash
pixi containerize -o my-copy.sif
```

## 10.3 Per-backend overrides

Since **v0.7.0**, you can set different defaults per backend:

```toml
[tool.pixitainer]
output = "copy.sif"
add-file = ["copy.py:/opt/conf/copy.py"]

[tool.pixitainer.docker]
output = "copy:latest"
```

Priority (lowest → highest):

```
[tool.pixitainer]  <  [tool.pixitainer.<backend>]  <  CLI arguments
```

---

## Exercises

**Exercise 10.1** — Fill in the missing word. The configuration table is called `[tool.____]`:

<details>
<summary>Show answer</summary>

`pixitainer`

```toml
[tool.pixitainer]
output = "copy.sif"
```

</details>

**Exercise 10.2** — Fill in the missing word. The `add-file` key adds a file into the image, in the format `____:DEST`:

<details>
<summary>Show answer</summary>

`SRC`

```toml
add-file = ["copy.py:/opt/conf/copy.py"]
#            SRC        DEST
```

</details>

**Exercise 10.3** — Fill in the missing word. CLI arguments have the ____ priority (highest or lowest):

<details>
<summary>Show answer</summary>

`highest`

```text
[tool.pixitainer]  <  [tool.pixitainer.<backend>]  <  CLI arguments
```

</details>

**Exercise 10.4** — Fill in the missing word. To set Docker-specific defaults, use the `[tool.pixitainer.____]` table:

<details>
<summary>Show answer</summary>

`docker`

```toml
[tool.pixitainer.docker]
output = "copy:latest"
```

</details>

---

**← Back:** [Step 9 — `tool` mode](09-tool-mode.md) · **Back to the [index](README.md)**
