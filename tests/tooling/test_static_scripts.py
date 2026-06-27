#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def main() -> None:
    run(sys.executable, "tests/tooling/test_verify_pr_ui_capture.py")
    run(sys.executable, "tests/tooling/test_verify_script_coverage.py")
    run(sys.executable, "scripts/verify_project_contract.py")
    run(sys.executable, "scripts/verify_import_metadata.py")
    run(sys.executable, "scripts/verify_secret_hygiene.py")
    run(sys.executable, "scripts/verify_ui_automation_contract.py")
    run(sys.executable, "scripts/verify_pixel_texture_filters.py")
    run(sys.executable, "scripts/verify_web_preview_contract.py")
    print("[test_static_scripts] OK")


if __name__ == "__main__":
    main()
