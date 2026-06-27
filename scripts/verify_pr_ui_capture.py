#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any


UI_CAPTURE_HEADING_RE = re.compile(r"(?im)^##\s*UI\s*캡처\s*$")
UI_TITLE_RE = re.compile(r"^\s*\[UI\]")
RAW_PREVIEW_TEMPLATE = (
    r"https://raw\.githubusercontent\.com/0xkkun/seoul-challenge/"
    r"ui-previews/pr-{number}/[^\s)]+?\.(?:png|jpg|jpeg|webp)"
)


def validate_pr_capture(event: dict[str, Any]) -> list[str]:
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        return []
    if not _is_ui_pull_request(pr):
        return []

    number = int(pr.get("number", 0))
    body = str(pr.get("body") or "")
    errors: list[str] = []

    if UI_CAPTURE_HEADING_RE.search(body) is None:
        errors.append("UI PR 본문에는 `## UI 캡처` 섹션이 필요합니다.")

    preview_re = re.compile(RAW_PREVIEW_TEMPLATE.format(number=number))
    if preview_re.search(body) is None:
        errors.append(
            "UI PR 본문에는 "
            f"`https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-{number}/...png` "
            "형식의 캡처 링크가 필요합니다."
        )

    return errors


def _is_ui_pull_request(pr: dict[str, Any]) -> bool:
    title = str(pr.get("title") or "")
    labels = pr.get("labels") or []
    label_names = {
        str(label.get("name") or "")
        for label in labels
        if isinstance(label, dict)
    }
    return bool(UI_TITLE_RE.search(title)) or "area:ui" in label_names


def _load_event(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError("GitHub event payload must be a JSON object")
    return data


def main() -> int:
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    if event_name != "pull_request":
        print("[verify_pr_ui_capture] OK: not a pull_request event")
        return 0

    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if event_path == "":
        print("[verify_pr_ui_capture] FAIL: GITHUB_EVENT_PATH is not set", file=sys.stderr)
        return 1

    errors = validate_pr_capture(_load_event(Path(event_path)))
    if errors:
        for error in errors:
            print(f"[verify_pr_ui_capture] FAIL: {error}", file=sys.stderr)
        return 1

    print("[verify_pr_ui_capture] OK: UI capture contract satisfied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
