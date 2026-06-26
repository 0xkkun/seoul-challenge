#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GD_SCRIPT_DIRS = ("scripts", "tests")
DEVICE_UAT_SCAN_DIRS = ("scripts", "tests")
SET_META_RE = re.compile(r"(?P<target>[A-Za-z_][A-Za-z0-9_]*)\.set_meta\(\"(?P<meta>uat_action|test_id)\"")
FORBIDDEN_DEVICE_UAT_PATTERNS = (
    (re.compile(r"\badb\s+(?:-[^\s]+\s+)*shell\s+input\s+tap\b"), "adb shell input tap"),
    (re.compile(r"\binput\s+tap\s+\d+\s+\d+\b"), "input tap coordinates"),
    (re.compile(r"\btap_pct\b"), "tap_pct coordinate helper"),
    (re.compile(r"\buser://[A-Za-z0-9_./-]*uat[A-Za-z0-9_./-]*\.jsonl\b"), "user:// UAT command file"),
)


def fail(message: str) -> None:
    print(f"[verify_ui_automation_contract] FAIL: {message}", file=sys.stderr)


def gd_files() -> list[Path]:
    files: list[Path] = []
    for directory in GD_SCRIPT_DIRS:
        files.extend((ROOT / directory).rglob("*.gd"))
    return sorted(files)


def device_uat_contract_files() -> list[Path]:
    files: list[Path] = []
    verifier_path = Path(__file__).resolve()
    for directory in DEVICE_UAT_SCAN_DIRS:
        root = ROOT / directory
        files.extend(
            path
            for path in root.rglob("*")
            if path.is_file() and path.resolve() != verifier_path and path.suffix in {".gd", ".py", ".sh"}
        )
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

    for path in device_uat_contract_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        for pattern, label in FORBIDDEN_DEVICE_UAT_PATTERNS:
            for match in pattern.finditer(text):
                line_number = text.count("\n", 0, match.start()) + 1
                relative = path.relative_to(ROOT)
                problems.append(
                    f"{relative}:{line_number}: {label} is forbidden for Godot device UAT; use test_id/uat_action plus an explicit debug IPC bridge"
                )

    if problems:
        for problem in problems[:80]:
            fail(problem)
        raise SystemExit(1)

    print("[verify_ui_automation_contract] OK: uat actions have stable test ids")


if __name__ == "__main__":
    main()
