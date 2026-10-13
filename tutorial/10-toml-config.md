# Step 10 — TOML configuration

**Goal:** put your Pixitainer options in `pixi.toml` instead of typing flags every time.

## 10.1 Add a `[tool.pixitainer]` table

Since **v0.6.0**, Pixitainer reads a `[tool.pixitainer]` table in your manifest. Add this to `pixi.toml`:

```toml
[tool.pixitainer]
output = "thumb.sif"
add-file = ["thumb.py:/opt/conf/thumb.py"]
```

Now a plain `pixi containerize` picks up those defaults:

```bash
pixi containerize
```

## 10.2 Override on the command line

CLI arguments **always win** over the TOML table:

```bash
pixi containerize -o my-thumb.sif
```

## 10.3 Per-backend overrides

Since **v0.7.0**, you can set different defaults per backend:

```toml
[tool.pixitainer]
output = "thumb.sif"
add-file = ["thumb.py:/opt/conf/thumb.py"]

[tool.pixitainer.docker]
output = "thumb:latest"
```

Priority (lowest → highest):

```text
[tool.pixitainer]  <  [tool.pixitainer.<backend>]  <  CLI arguments
```

---

## Try it

Put the `[tool.pixitainer]` table from section 10.1 in your manifest, then run:

```bash
pixi containerize -d
```

You should see the image default to `thumb.sif` with `thumb.py` added — no flags needed. Then override just the output name:

```bash
pixi containerize -d -o other.sif
```

Watch the output target change but the `add-file` stay. Same option, two sources, CLI wins.

---

**← Back:** [Step 9 — `tool` mode](09-tool-mode.md) · **Back to the [index](README.md)**
