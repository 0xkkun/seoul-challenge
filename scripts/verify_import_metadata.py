#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys


def git_lines(*args: str) -> list[str]:
    out = subprocess.check_output(["git", *args], text=True)
    return [line for line in out.splitlines() if line]


def main() -> None:
    untracked_imports = [
        path
        for path in git_lines("ls-files", "--others", "--exclude-standard", "*.import")
        if not path.startswith(".godot/")
    ]
    if untracked_imports:
        print("[verify_import_metadata] FAIL: untracked Godot import metadata found", file=sys.stderr)
        for path in untracked_imports[:50]:
            print(f"  {path}", file=sys.stderr)
        print("Commit asset-side *.import files with their source assets.", file=sys.stderr)
        raise SystemExit(1)

    tracked_bad = [path for path in git_lines("ls-files", "*.import") if path.startswith(".godot/")]
    if tracked_bad:
        print("[verify_import_metadata] FAIL: .godot cache import files are tracked", file=sys.stderr)
        for path in tracked_bad[:50]:
            print(f"  {path}", file=sys.stderr)
        raise SystemExit(1)

    untracked_uids = git_lines("ls-files", "--others", "--exclude-standard", "*.gd.uid")
    if untracked_uids:
        print("[verify_import_metadata] FAIL: untracked GDScript UID sidecars found", file=sys.stderr)
        for path in untracked_uids[:50]:
            print(f"  {path}", file=sys.stderr)
        raise SystemExit(1)

    print("[verify_import_metadata] OK: Godot import metadata hygiene clean")


if __name__ == "__main__":
    main()
