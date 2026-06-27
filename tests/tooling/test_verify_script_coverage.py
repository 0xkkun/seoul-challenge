#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True


def load_module():
    module_path = ROOT / "scripts/verify_script_coverage.py"
    spec = importlib.util.spec_from_file_location("verify_script_coverage", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write(root: Path, relative_path: str, text: str) -> None:
    path = root / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def test_resource_graph_marks_scene_and_resource_scripts_covered() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(root, "scripts/foo.gd", "extends Node\n")
        write(root, "scripts/bar.gd", "extends Node\n")
        write(root, "scripts/dev/debug_only.gd", "extends Node\n")
        write(
            root,
            "scenes/foo.tscn",
            '\n'.join([
                '[gd_scene load_steps=3 format=3]',
                '[ext_resource type="Script" path="res://scripts/foo.gd" id="1"]',
                '[ext_resource type="Resource" path="res://resources/bar.tres" id="2"]',
            ]),
        )
        write(
            root,
            "resources/bar.tres",
            '\n'.join([
                '[gd_resource type="Resource" load_steps=2 format=3]',
                '[ext_resource type="Script" path="res://scripts/bar.gd" id="1"]',
            ]),
        )
        write(
            root,
            "tests/unit/test_foo.gd",
            'extends Node\nconst FooScene := preload("res://scenes/foo.tscn")\nfunc test_foo() -> void:\n\tpass\n',
        )

        report = module.compute_script_coverage(root)

        assert report.total_scripts == 2
        assert report.covered_scripts == {"scripts/foo.gd", "scripts/bar.gd"}
        assert report.excluded_scripts == {"scripts/dev/debug_only.gd"}
        assert report.coverage_percent == 100.0
        assert report.passes(90.0)


def test_uncovered_scripts_fail_threshold_and_keep_names() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(root, "scripts/covered.gd", "extends Node\n")
        write(root, "scripts/missing.gd", "extends Node\n")
        write(
            root,
            "tests/unit/test_covered.gd",
            'extends Node\nconst Covered := preload("res://scripts/covered.gd")\nfunc test_covered() -> void:\n\tpass\n',
        )

        report = module.compute_script_coverage(root)

        assert report.total_scripts == 2
        assert report.covered_scripts == {"scripts/covered.gd"}
        assert report.uncovered_scripts == {"scripts/missing.gd"}
        assert report.coverage_percent == 50.0
        assert not report.passes(90.0)


def test_class_name_references_mark_scripts_covered() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(root, "scripts/base.gd", "class_name FixtureBase\nextends Node\n")
        write(root, "scripts/child.gd", "class_name FixtureChild\nextends FixtureBase\n")
        write(
            root,
            "tests/unit/test_child.gd",
            "extends Node\nfunc test_child() -> void:\n\tvar child := FixtureChild.new()\n\tchild.free()\n",
        )

        report = module.compute_script_coverage(root)

        assert report.total_scripts == 2
        assert report.covered_scripts == {"scripts/base.gd", "scripts/child.gd"}
        assert report.uncovered_scripts == set()
        assert report.coverage_percent == 100.0


def test_gd_navigation_constants_do_not_mark_scene_scripts_covered() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(
            root,
            "project.godot",
            '[autoload]\nSceneTransition="*res://scripts/autoload/scene_transition.gd"\n',
        )
        write(
            root,
            "scripts/autoload/scene_transition.gd",
            'extends Node\nconst SESSION_SCENE := "res://scenes/session/session_root.tscn"\n',
        )
        write(root, "scripts/session/session_root.gd", "extends Node\n")
        write(
            root,
            "scenes/session/session_root.tscn",
            '\n'.join([
                '[gd_scene load_steps=2 format=3]',
                '[ext_resource type="Script" path="res://scripts/session/session_root.gd" id="1"]',
            ]),
        )

        report = module.compute_script_coverage(root)

        assert report.total_scripts == 2
        assert report.covered_scripts == {"scripts/autoload/scene_transition.gd"}
        assert report.uncovered_scripts == {"scripts/session/session_root.gd"}
        assert report.coverage_percent == 50.0


def test_default_seed_roots_match_quick_gate_suites() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(root, "scripts/unit_only.gd", "extends Node\n")
        write(root, "scripts/performance_only.gd", "extends Node\n")
        write(
            root,
            "tests/unit/test_unit_only.gd",
            'extends Node\nconst UnitOnly := preload("res://scripts/unit_only.gd")\n',
        )
        write(
            root,
            "tests/performance/test_performance_only.gd",
            'extends Node\nconst PerformanceOnly := preload("res://scripts/performance_only.gd")\n',
        )

        report = module.compute_script_coverage(root)
        performance_report = module.compute_script_coverage(root, ("tests/performance",))

        assert report.total_scripts == 2
        assert report.covered_scripts == {"scripts/unit_only.gd"}
        assert report.uncovered_scripts == {"scripts/performance_only.gd"}
        assert report.coverage_percent == 50.0
        assert performance_report.covered_scripts == {"scripts/performance_only.gd"}


def test_cli_reports_uncovered_scripts_when_threshold_fails() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write(root, "scripts/covered.gd", "extends Node\n")
        write(root, "scripts/missing.gd", "extends Node\n")
        write(
            root,
            "tests/unit/test_covered.gd",
            'extends Node\nconst Covered := preload("res://scripts/covered.gd")\nfunc test_covered() -> void:\n\tpass\n',
        )

        result = subprocess.run(
            [
                sys.executable,
                str(ROOT / "scripts/verify_script_coverage.py"),
                "--root",
                str(root),
                "--min",
                "90",
            ],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

        assert result.returncode == 1
        assert "[verify_script_coverage] FAIL" in result.stdout
        assert "scripts/missing.gd" in result.stdout


def main() -> None:
    test_resource_graph_marks_scene_and_resource_scripts_covered()
    test_uncovered_scripts_fail_threshold_and_keep_names()
    test_class_name_references_mark_scripts_covered()
    test_gd_navigation_constants_do_not_mark_scene_scripts_covered()
    test_default_seed_roots_match_quick_gate_suites()
    test_cli_reports_uncovered_scripts_when_threshold_fails()
    print("[test_verify_script_coverage] OK")


if __name__ == "__main__":
    main()
