#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GD_SCRIPT_DIRS = ("scripts", "tests")
SET_META_RE = re.compile(r"(?P<target>[A-Za-z_][A-Za-z0-9_]*)\.set_meta\(\"(?P<meta>uat_action|test_id)\"")


def fail(message: str) -> None:
    print(f"[verify_ui_automation_contract] FAIL: {message}", file=sys.stderr)


def gd_files() -> list[Path]:
    files: list[Path] = []
    for directory in GD_SCRIPT_DIRS:
        files.extend((ROOT / directory).rglob("*.gd"))
    return sorted(files)


def main() -> None:
    problems: list[str] = []
    for path in gd_files():
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        for index, line in enumerate(lines):
            match = SET_META_RE.search(line)
            if match == None or match.group("meta") != "uat_action":
                continue

            target = match.group("target")
            window_start = max(0, index - 4)
            window_end = min(len(lines), index + 5)
            test_id_pattern = re.compile(rf"\b{re.escape(target)}\.set_meta\(\"test_id\"")
            has_test_id = any(test_id_pattern.search(candidate) for candidate in lines[window_start:window_end])
            if not has_test_id:
                relative = path.relative_to(ROOT)
                problems.append(f"{relative}:{index + 1}: {target}.set_meta(\"uat_action\") must be paired with test_id")

    if problems:
        for problem in problems[:80]:
            fail(problem)
        raise SystemExit(1)

    print("[verify_ui_automation_contract] OK: uat actions have stable test ids")


if __name__ == "__main__":
    main()
