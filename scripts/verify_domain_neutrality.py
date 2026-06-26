#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

PRIVATE_PROJECT_TERM = "tail" + "bound"

FORBIDDEN_TERMS = [
    PRIVATE_PROJECT_TERM,
    "firebase",
    "admob",
    "iap",
    "sentry",
    "roguelite",
    "boss",
    "enemy",
    "projectile",
    "weapon",
    "damage",
    "score",
    "quest",
    "stage",
    "level_up",
    "shrine",
    "reaper",
    "shaman",
]

FORBIDDEN_PATTERNS = [
    re.compile(rf"(?<![a-z0-9_]){re.escape(term)}(?![a-z0-9_])")
    for term in FORBIDDEN_TERMS
]

SKIP_PATHS = {
    "DESIGN.md",
    "scripts/verify_domain_neutrality.py",
}

TEXT_SUFFIXES = {
    ".gd",
    ".tscn",
    ".tres",
    ".godot",
    ".cfg",
    ".csv",
    ".md",
    ".py",
    ".sh",
    ".yml",
    ".yaml",
    ".json",
    ".svg",
    ".txt",
}


def git_files() -> list[str]:
    out = subprocess.check_output(["git", "ls-files", "--others", "--cached", "--exclude-standard"], text=True)
    return [line for line in out.splitlines() if line and line not in SKIP_PATHS]


def is_text_path(path: str) -> bool:
    p = Path(path)
    return p.name == "project.godot" or p.suffix in TEXT_SUFFIXES


def main() -> None:
    problems: list[str] = []
    for path in git_files():
        if not is_text_path(path):
            continue
        lower_path = path.lower()
        for pattern, term in zip(FORBIDDEN_PATTERNS, FORBIDDEN_TERMS, strict=True):
            if pattern.search(lower_path):
                problems.append(f"{path}: forbidden term in path: {term}")
        file_path = Path(path)
        if not file_path.is_file():
            continue
        text = file_path.read_text(encoding="utf-8", errors="ignore").lower()
        for pattern, term in zip(FORBIDDEN_PATTERNS, FORBIDDEN_TERMS, strict=True):
            if pattern.search(text):
                problems.append(f"{path}: forbidden term in content: {term}")

    if problems:
        print("[verify_domain_neutrality] FAIL: domain-specific or private terms found", file=sys.stderr)
        for problem in problems[:80]:
            print("  " + problem, file=sys.stderr)
        raise SystemExit(1)

    print("[verify_domain_neutrality] OK: reusable surface is domain-neutral")


if __name__ == "__main__":
    main()
