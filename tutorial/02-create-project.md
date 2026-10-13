# Step 2 — Create the `thumb` project

**Goal:** write a tiny Python CLI that makes image thumbnails, managed by pixi.

We'll use a small project anyone can follow: a script called `thumb` that shrinks an image down to a thumbnail. It depends on Pillow (a real third-party library) — which is exactly why you'll want it in a container later.

## 2.1 Make the directory

```bash
mkdir thumb-project && cd thumb-project
```

## 2.2 Write the manifest

Create `pixi.toml`:

```toml
[workspace]
name = "thumb"
version = "0.1.0"
description = "A tiny CLI that turns any image into a thumbnail"
channels = ["conda-forge"]
platforms = ["linux-64"]

[dependencies]
python = ">=3.11"
pillow = ">=10"

[tasks]
thumb = "python thumb.py"
```

## 2.3 Write the script

Create `thumb.py` — shrink an image to a max width, keeping the aspect ratio:

```python
#!/usr/bin/env python3
"""thumb — turn any image into a thumbnail.

Usage: thumb -w WIDTH SRC DEST
"""
import argparse
from PIL import Image


def main() -> int:
    p = argparse.ArgumentParser(prog="thumb")
    p.add_argument("-w", "--width", type=int, default=100, help="max width in px")
    p.add_argument("src", help="input image")
    p.add_argument("dest", help="output thumbnail path")
    args = p.parse_args()

    img = Image.open(args.src)
    w = args.width
    h = round(img.height * w / img.width)
    img.thumbnail((w, h), Image.LANCZOS)
    img.save(args.dest)
    print(f"{args.src} ({img.width}x{img.height}) -> {args.dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

## 2.4 Install the environment

```bash
pixi install
```

This creates `pixi.lock`, which pins every dependency (Python + Pillow + their transitive deps) for reproducibility.

---

**← Back:** [Step 1 — Install](01-install.md) · **Next:** [Step 3 — Run it locally](03-run-locally.md) →
