#!/usr/bin/env python3
"""copy — a tiny file-copying CLI.

Usage: copy SRC DEST

Copies SRC to DEST, preserving metadata. Uses only the Python standard
library, so it has no dependencies beyond Python itself.
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
