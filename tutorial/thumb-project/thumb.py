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
