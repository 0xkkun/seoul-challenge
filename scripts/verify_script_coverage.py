#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import deque
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MIN_COVERAGE = 90.0
REFERENCE_RE = re.compile(r"res://([^\"'\s\)\]\[,]+)")
GD_LOAD_REFERENCE_RE = re.compile(
    r"(?:\b(?:preload|load)\s*\(|\bResourceLoader\.load\s*\()\s*"
    r"[\"']res://([^\"']+)[\"']"
)
GD_EXTENDS_REFERENCE_RE = re.compile(r"^\s*extends\s+[\"']res://([^\"']+)[\"']", re.MULTILINE)
CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.MULTILINE)
RESOURCE_SUFFIXES = (".gd", ".tscn", ".tres")
EXCLUDED_SCRIPT_PREFIXES = (
    "scripts/dev/",
)
EXCLUDED_SCRIPT_PATHS = {
    "scripts/actors/sample_actor.gd",
    "scripts/interactables/sample_interactable.gd",
    "scripts/interactables/sample_pooled_marker.gd",
}
IGNORED_FALLBACK_DIRS = {
    ".git",
    ".godot",
    "build",
    "exports",
    "test-results",
}


@dataclass(frozen=True)
class CoverageReport:
    total_scripts: int
    covered_scripts: set[str]
    uncovered_scripts: set[str]
    excluded_scripts: set[str]
    coverage_percent: float

    def passes(self, minimum_percent: float) -> bool:
        return self.coverage_percent + 0.0001 >= minimum_percent


def compute_script_coverage(root: Path = ROOT) -> CoverageReport:
    root = root.resolve()
    project_files = set(list_project_files(root))
    production_scripts = {
        path
        for path in project_files
        if path.startswith("scripts/") and path.endswith(".gd") and is_production_script(path)
    }
    excluded_scripts = {
        path
        for path in project_files
        if path.startswith("scripts/") and path.endswith(".gd") and not is_production_script(path)
    }
    resource_files = {
        path
        for path in project_files
        if path.endswith(RESOURCE_SUFFIXES) or path == "project.godot"
    }
    class_name_paths = collect_class_name_paths(root, production_scripts)
    seeds = collect_test_seed_paths(root, project_files)
    covered_scripts = trace_covered_scripts(
        root,
        resource_files,
        production_scripts,
        class_name_paths,
        seeds,
    )
    uncovered_scripts = production_scripts - covered_scripts
    coverage_percent = (
        100.0
        if not production_scripts
        else round((len(covered_scripts) / len(production_scripts)) * 100.0, 2)
    )
    return CoverageReport(
        total_scripts=len(production_scripts),
        covered_scripts=covered_scripts,
        uncovered_scripts=uncovered_scripts,
        excluded_scripts=excluded_scripts,
        coverage_percent=coverage_percent,
    )


def list_project_files(root: Path) -> list[str]:
    git_files = list_git_tracked_files(root)
    if git_files:
        return git_files
    files: list[str] = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        relative_parts = path.relative_to(root).parts
        if any(part in IGNORED_FALLBACK_DIRS for part in relative_parts):
            continue
        files.append(path.relative_to(root).as_posix())
    return sorted(files)


def list_git_tracked_files(root: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "ls-files"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    return [line for line in result.stdout.splitlines() if line]


def is_production_script(path: str) -> bool:
    if path in EXCLUDED_SCRIPT_PATHS:
        return False
    return not path.startswith(EXCLUDED_SCRIPT_PREFIXES)


def collect_test_seed_paths(root: Path, project_files: set[str]) -> set[str]:
    seeds: set[str] = set()
    for path in sorted(project_files):
        if path.startswith("tests/") and path.endswith(RESOURCE_SUFFIXES):
            seeds.add(path)
            text = read_text(root, path)
            seeds.update(find_references_for_file(path, text))
    if "project.godot" in project_files:
        for reference in find_resource_references(read_text(root, "project.godot")):
            if reference.startswith("scripts/autoload/"):
                seeds.add(reference)
    return seeds


def collect_class_name_paths(root: Path, production_scripts: set[str]) -> dict[str, str]:
    class_name_paths: dict[str, str] = {}
    for path in sorted(production_scripts):
        match = CLASS_NAME_RE.search(read_text(root, path))
        if match:
            class_name_paths[match.group(1)] = path
    return class_name_paths


def trace_covered_scripts(
    root: Path,
    resource_files: set[str],
    production_scripts: set[str],
    class_name_paths: dict[str, str],
    seed_paths: set[str],
) -> set[str]:
    covered_scripts: set[str] = set()
    visited: set[str] = set()
    queue: deque[str] = deque(sorted(seed_paths))
    while queue:
        path = queue.popleft()
        if path in visited:
            continue
        visited.add(path)
        if path not in resource_files:
            continue
        if path in production_scripts:
            covered_scripts.add(path)
        text = read_text(root, path)
        for reference in sorted(find_references_for_file(path, text)):
            if reference.endswith(RESOURCE_SUFFIXES):
                queue.append(reference)
        for class_path in sorted(find_class_name_references(text, class_name_paths)):
            queue.append(class_path)
    return covered_scripts


def find_resource_references(text: str) -> set[str]:
    return {
        match.group(1).strip()
        for match in REFERENCE_RE.finditer(text)
        if match.group(1).strip()
    }


def find_gd_load_references(text: str) -> set[str]:
    references = {
        match.group(1).strip()
        for match in GD_LOAD_REFERENCE_RE.finditer(text)
        if match.group(1).strip()
    }
    references.update(
        match.group(1).strip()
        for match in GD_EXTENDS_REFERENCE_RE.finditer(text)
        if match.group(1).strip()
    )
    return references


def find_references_for_file(path: str, text: str) -> set[str]:
    if path.endswith(".gd"):
        return find_gd_load_references(text)
    return find_resource_references(text)


def find_class_name_references(text: str, class_name_paths: dict[str, str]) -> set[str]:
    references: set[str] = set()
    for class_name, path in class_name_paths.items():
        if re.search(r"\b%s\b" % re.escape(class_name), text):
            references.add(path)
    return references


def read_text(root: Path, relative_path: str) -> str:
    path = root / relative_path
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8", errors="ignore")


def print_report(report: CoverageReport, minimum_percent: float) -> None:
    covered_count = len(report.covered_scripts)
    print(
        "[verify_script_coverage] scripts: %d/%d covered (%.2f%%, minimum %.2f%%)"
        % (covered_count, report.total_scripts, report.coverage_percent, minimum_percent)
    )
    if report.excluded_scripts:
        print(
            "[verify_script_coverage] excluded scripts: %d"
            % len(report.excluded_scripts)
        )
    if report.uncovered_scripts:
        print("[verify_script_coverage] uncovered scripts:")
        for path in sorted(report.uncovered_scripts):
            print("  %s" % path)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify script-level test coverage for Godot GDScript files."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="Project root to scan. Defaults to the repository root.",
    )
    parser.add_argument(
        "--min",
        type=float,
        default=DEFAULT_MIN_COVERAGE,
        help="Minimum required script coverage percentage.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    report = compute_script_coverage(args.root)
    print_report(report, args.min)
    if not report.passes(args.min):
        print(
            "[verify_script_coverage] FAIL: script coverage %.2f%% below minimum %.2f%%"
            % (report.coverage_percent, args.min),
            file=sys.stderr,
        )
        return 1
    print("[verify_script_coverage] OK: script coverage gate passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
