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
INLINE_PREVIEW_TEMPLATE = r"(?<!\\)!\[[^\]\r\n]*[^\s\]\r\n][^\]\r\n]*\]\(\s*(?P<url>{raw_url})\s*\)"
EMPTY_ALT_PREVIEW_TEMPLATE = r"(?<!\\)!\[\s*\]\(\s*(?P<url>{raw_url})\s*\)"
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
FENCE_OPEN_RE = re.compile(r"^[ \t]{0,3}(`{3,}|~{3,})")
CODE_SPAN_DELIMITER_RE = re.compile(r"(?<!`)`+(?!`)")


def validate_pr_capture(event: dict[str, Any]) -> list[str]:
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        return []
    if not _is_ui_pull_request(pr):
        return []

    number = int(pr.get("number", 0))
    body = str(pr.get("body") or "")
    rendered_body = _rendered_markdown_source(body)
    errors: list[str] = []

    if UI_CAPTURE_HEADING_RE.search(rendered_body) is None:
        errors.append("UI PR 본문에는 `## UI 캡처` 섹션이 필요합니다.")

    raw_url = RAW_PREVIEW_TEMPLATE.format(number=number)
    preview_re = re.compile(raw_url)
    raw_urls = preview_re.findall(rendered_body)
    if not raw_urls:
        errors.append(
            "UI PR 본문에는 "
            f"`https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-{number}/...png` "
            "형식의 캡처 링크가 필요합니다."
        )
    else:
        inline_preview_re = re.compile(INLINE_PREVIEW_TEMPLATE.format(raw_url=raw_url))
        empty_alt_preview_re = re.compile(EMPTY_ALT_PREVIEW_TEMPLATE.format(raw_url=raw_url))
        inline_urls = [match.group("url") for match in inline_preview_re.finditer(rendered_body)]
        empty_alt_urls = [match.group("url") for match in empty_alt_preview_re.finditer(rendered_body)]
        if empty_alt_urls:
            errors.append("UI 캡처 인라인 이미지에는 화면을 설명하는 대체 텍스트가 필요합니다.")
        if len(inline_urls) + len(empty_alt_urls) != len(raw_urls):
            errors.append("모든 캡처 URL은 PR에서 바로 보이는 Markdown 인라인 이미지 `![설명](URL)`로 작성해야 합니다.")

    return errors


def _rendered_markdown_source(body: str) -> str:
    without_comments = HTML_COMMENT_RE.sub("", body)
    rendered_lines: list[str] = []
    fence: tuple[str, int] | None = None
    for line in without_comments.splitlines(keepends=True):
        if fence is not None:
            fence_char, fence_length = fence
            close_re = re.compile(rf"^[ \t]{{0,3}}{re.escape(fence_char)}{{{fence_length},}}[ \t]*(?:\r?\n)?$")
            if close_re.match(line):
                fence = None
            continue
        open_match = FENCE_OPEN_RE.match(line)
        if open_match is not None:
            marker = open_match.group(1)
            fence = (marker[0], len(marker))
            continue
        rendered_lines.append(line)
    return _strip_inline_code_spans("".join(rendered_lines))


def _strip_inline_code_spans(source: str) -> str:
    rendered_parts: list[str] = []
    cursor = 0
    while True:
        opening = CODE_SPAN_DELIMITER_RE.search(source, cursor)
        if opening is None:
            rendered_parts.append(source[cursor:])
            break
        rendered_parts.append(source[cursor:opening.start()])
        delimiter = opening.group(0)
        closing_re = re.compile(rf"(?<!`){re.escape(delimiter)}(?!`)")
        closing = closing_re.search(source, opening.end())
        if closing is None:
            rendered_parts.append(source[opening.start():])
            break
        cursor = closing.end()
    return "".join(rendered_parts)


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
