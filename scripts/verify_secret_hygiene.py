#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

SECRET_PATH_PATTERNS = [
    re.compile(r"(^|/)\.env(\.|$)"),
    re.compile(r"config/.*(secret|token|credential|private|local).*", re.IGNORECASE),
    re.compile(r".*(google-services|GoogleService-Info)\.(json|plist)$"),
]

SECRET_VALUE_PATTERNS = [
    re.compile(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"(?i)(api[_-]?key|secret|token)\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{24,}"),
]

TEXT_SUFFIXES = {".gd", ".cfg", ".json", ".md", ".py", ".sh", ".yml", ".yaml", ".txt", ".csv"}


def git_files() -> list[str]:
    out = subprocess.check_output(["git", "ls-files"], text=True)
    return [line for line in out.splitlines() if line]


def main() -> None:
    problems: list[str] = []
    for path in git_files():
        for pattern in SECRET_PATH_PATTERNS:
            if pattern.search(path):
                problems.append(f"secret-like tracked path: {path}")
        file_path = Path(path)
        if not file_path.is_file() or file_path.suffix not in TEXT_SUFFIXES:
            continue
        text = file_path.read_text(encoding="utf-8", errors="ignore")
        for pattern in SECRET_VALUE_PATTERNS:
            if pattern.search(text):
                problems.append(f"secret-like value in: {path}")

    if problems:
        print("[verify_secret_hygiene] FAIL: secret hygiene violation", file=sys.stderr)
        for problem in problems[:80]:
            print("  " + problem, file=sys.stderr)
        raise SystemExit(1)

    print("[verify_secret_hygiene] OK: no tracked secret-like files or values")


if __name__ == "__main__":
    main()
