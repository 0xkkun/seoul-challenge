#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path


REQUIRED_FILES = [
    "scripts/export_web_preview.sh",
    ".github/workflows/web-preview.yml",
]

REQUIRED_SCRIPT_NEEDLES = [
    'PRESET="${WEB_PREVIEW_PRESET:-Web}"',
    'OUTPUT_DIR="${WEB_PREVIEW_DIR:-build/web}"',
    "WEB_PREVIEW_DIR must be a relative path without '..'",
    'rm -rf -- "$OUTPUT_DIR"',
    "--export-release",
    "[ -f \"$INDEX_PATH\" ]",
]

REQUIRED_WORKFLOW_NEEDLES = [
    "name: Web Preview",
    "pull_request:",
    "workflow_dispatch:",
    "contents: read",
    "build-web-preview:",
    "name: Web Preview",
    "publish-web-preview:",
    "name: Publish Web Preview",
    "needs: build-web-preview",
    "contents: write",
    "pages: write",
    "id-token: write",
    "concurrency:",
    "group: web-preview-build-",
    "group: web-preview-publish",
    "cancel-in-progress: true",
    "cancel-in-progress: false",
    "bash scripts/export_web_preview.sh",
    "include-templates: true",
    "actions/upload-artifact",
    "actions/download-artifact@v8.0.1",
    "retention-days: 14",
    "actions/upload-pages-artifact@v5.0.0",
    "actions/deploy-pages@v5.0.0",
    "if: steps.pages.outputs.build_type == 'workflow'",
    "web-previews",
    "destination_dir: pr-${{ github.event.pull_request.number }}",
    "github.event.pull_request.head.repo.full_name == github.repository",
    "GITHUB_STEP_SUMMARY",
]

REQUIRED_EXPORT_NEEDLES = [
    'name="Web"',
    'platform="Web"',
    'export_path="build/web/index.html"',
]

REQUIRED_DOC_NEEDLES = [
    "scripts/export_web_preview.sh",
    "web-previews",
    "GitHub Actions",
    "Web Preview",
]


def fail(message: str) -> None:
    print(f"[verify_web_preview_contract] FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def require_files() -> None:
    missing = [path for path in REQUIRED_FILES if not Path(path).is_file()]
    if missing:
        fail("missing required file(s): " + ", ".join(missing))


def require_needles(path: str, needles: list[str]) -> None:
    text = read(path)
    missing = [needle for needle in needles if needle not in text]
    if missing:
        fail(f"{path} missing contract text: " + ", ".join(missing))


def main() -> None:
    require_files()
    require_needles("scripts/export_web_preview.sh", REQUIRED_SCRIPT_NEEDLES)
    require_needles(".github/workflows/web-preview.yml", REQUIRED_WORKFLOW_NEEDLES)
    require_needles("export_presets.cfg", REQUIRED_EXPORT_NEEDLES)
    require_needles("docs/testing.md", REQUIRED_DOC_NEEDLES)
    print("[verify_web_preview_contract] OK: web preview contract matches CI harness")


if __name__ == "__main__":
    main()
