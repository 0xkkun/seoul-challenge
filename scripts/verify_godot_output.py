#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


FAIL_PATTERNS = [
    re.compile(r"\bSCRIPT ERROR\b"),
    re.compile(r"\bFATAL\b"),
    re.compile(r"\bPANIC\b"),
    re.compile(r"\[FAIL\]"),
]

ALLOWLISTED_ERROR_LINES = [
    re.compile(r'^\s*ERROR: Condition "ret != noErr" is true\. Returning: ""$'),
    re.compile(r"^\s*ERROR: Cannot save file '.*/editor_settings-4\.6\.tres'\.$"),
    re.compile(r"^\s*ERROR: Error saving editor settings to .*/editor_settings-4\.6\.tres$"),
]


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: verify_godot_output.py <log-file>")

    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
    failures = []
    for pattern in FAIL_PATTERNS:
        match = pattern.search(text)
        if match:
            failures.append(pattern.pattern)

    for line in text.splitlines():
        if not re.match(r"^\s*ERROR:", line):
            continue
        if any(pattern.match(line) for pattern in ALLOWLISTED_ERROR_LINES):
            continue
        failures.append(line.strip())

    if failures:
        print("[verify_godot_output] FAIL: Godot log contains failure markers", file=sys.stderr)
        print(f"[verify_godot_output] Log: {path}", file=sys.stderr)
        for pattern in failures:
            print(f"  pattern: {pattern}", file=sys.stderr)
        raise SystemExit(1)

    print(f"[verify_godot_output] OK: {path}")


if __name__ == "__main__":
    main()
