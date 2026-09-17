# Step 2 — Create the `copy` project

**Goal:** write a tiny Python CLI called `copy` that copies a file, managed by pixi.

## 2.1 Make the directory

```bash
mkdir copy-project && cd copy-project
```

## 2.2 Write the manifest

Create `pixi.toml`:

```toml
[workspace]
name = "copy"
version = "0.1.0"
description = "A tiny Python CLI that copies files"
channels = ["conda-forge"]
platforms = ["linux-64"]

[dependencies]
python = ">=3.11"

[tasks]
copy = "python copy.py"
```

## 2.3 Write the script

Create `copy.py` — a tiny file-copying CLI using only the Python standard library:

```python
#!/usr/bin/env python3
"""copy — a tiny file-copying CLI.

Usage: copy SRC DEST
"""
import shutil
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: copy SRC DEST", file=sys.stderr)
        return 2
    src, dest = sys.argv[1], sys.argv[2]
    shutil.copy2(src, dest)
    print(f"Copied {src} -> {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

## 2.4 Install the environment

```bash
pixi install
```

This creates `pixi.lock`, which pins every dependency for reproducibility.

---

## Exercises

**Exercise 2.1** — Fill in the missing word. The manifest file is called `pixi.____`:

<details>
<summary>Show answer</summary>

`toml`

```bash
pixi.toml
```

</details>

**Exercise 2.2** — Fill in the missing word. The `copy` task runs the command `python ____`:

```toml
[tasks]
copy = "python ____"
```

<details>
<summary>Show answer</summary>

`copy.py`

```toml
[tasks]
copy = "python copy.py"
```

</details>

**Exercise 2.3** — Fill in the missing word. Running `pixi ____` installs the environment and creates the lockfile:

<details>
<summary>Show answer</summary>

`install`

```bash
pixi install
```

</details>

---

**← Back:** [Step 1 — Install](01-install.md) · **Next:** [Step 3 — Run it locally](03-run-locally.md) →
