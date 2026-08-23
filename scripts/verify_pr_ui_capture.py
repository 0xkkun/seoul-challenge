#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from urllib import request


UI_TITLE_RE = re.compile(r"^\s*\[UI\]")
RAW_PREVIEW_TEMPLATE = (
    r"https://raw\.githubusercontent\.com/0xkkun/seoul-challenge/"
    r"ui-previews/pr-{number}/[^\s)]+?\.(?:png|jpg|jpeg|webp)"
)
ANY_RAW_PREVIEW_RE = re.compile(
    r"https://raw\.githubusercontent\.com/0xkkun/seoul-challenge/"
    r"ui-previews/pr-\d+/[^\s)]+?\.(?:png|jpg|jpeg|webp)"
)
ZERO_LENGTH_RE = re.compile(r"^[+-]?0+(?:\.0+)?(?:px|%|em|rem|vw|vh)?$", re.IGNORECASE)
VOID_HTML_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
}


class UiCaptureHtmlParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.section_found = False
        self.in_section = False
        self.images: list[tuple[str, str]] = []
        self.plain_links: list[str] = []
        self._heading_tag = ""
        self._heading_parts: list[str] = []
        self._anchors: list[dict[str, Any]] = []
        self._element_stack: list[tuple[str, bool]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag_name = tag.casefold()
        attr_map = {name.casefold(): value or "" for name, value in attrs}
        parent_hidden = self._element_stack[-1][1] if self._element_stack else False
        element_hidden = (
            parent_hidden
            or "hidden" in attr_map
            or _style_hides(attr_map.get("style", ""))
            or (tag_name == "details" and "open" not in attr_map)
        )
        if tag_name not in VOID_HTML_TAGS:
            self._element_stack.append((tag_name, element_hidden))
        if tag_name in {"h1", "h2"}:
            if element_hidden:
                return
            self.in_section = False
            self._heading_tag = tag_name
            self._heading_parts = []
            return
        if not self.in_section or element_hidden:
            return
        if tag_name == "a":
            self._anchors.append({"href": attr_map.get("href", ""), "image_urls": []})
        elif tag_name == "img":
            if _zero_dimension(attr_map.get("width", "")) or _zero_dimension(attr_map.get("height", "")):
                return
            image_url = attr_map.get("data-canonical-src", "") or attr_map.get("src", "")
            self.images.append((image_url, attr_map.get("alt", "")))
            if self._anchors:
                self._anchors[-1]["image_urls"].append(image_url)

    def handle_data(self, data: str) -> None:
        if self._heading_tag:
            self._heading_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag_name = tag.casefold()
        if tag_name == self._heading_tag:
            heading_text = re.sub(r"\s+", "", "".join(self._heading_parts)).casefold()
            if tag_name == "h2" and heading_text == "ui캡처".casefold():
                self.section_found = True
                self.in_section = True
            self._heading_tag = ""
            self._heading_parts = []
        elif tag_name == "a" and self._anchors:
            anchor = self._anchors.pop()
            if self.in_section and str(anchor["href"]) not in anchor["image_urls"]:
                self.plain_links.append(str(anchor["href"]))
        self._pop_element(tag_name)

    def _pop_element(self, tag_name: str) -> None:
        for index in range(len(self._element_stack) - 1, -1, -1):
            if self._element_stack[index][0] == tag_name:
                del self._element_stack[index:]
                return


def _zero_dimension(value: str) -> bool:
    return bool(value.strip() and ZERO_LENGTH_RE.fullmatch(value.strip()))


def _style_hides(style: str) -> bool:
    for declaration in style.casefold().split(";"):
        name, separator, value = declaration.partition(":")
        if separator == "":
            continue
        property_name = name.strip()
        property_value = value.strip()
        if property_name == "display" and property_value == "none":
            return True
        if property_name == "visibility" and property_value == "hidden":
            return True
        if property_name in {"opacity", "width", "height", "max-width", "max-height"} and _zero_dimension(property_value):
            return True
    return False


def validate_pr_capture(event: dict[str, Any]) -> list[str]:
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        return []
    if not _is_ui_pull_request(pr):
        return []

    number = int(pr.get("number", 0))
    body_html = pr.get("body_html")
    if not isinstance(body_html, str):
        return ["UI PR의 GitHub 렌더링 `body_html`을 불러와야 합니다."]
    errors: list[str] = []
    parser = UiCaptureHtmlParser()
    parser.feed(body_html)

    if not parser.section_found:
        errors.append("UI PR 본문에는 `## UI 캡처` 섹션이 필요합니다.")

    raw_url = RAW_PREVIEW_TEMPLATE.format(number=number)
    preview_re = re.compile(raw_url)
    all_preview_images = [
        (url, alt)
        for url, alt in parser.images
        if ANY_RAW_PREVIEW_RE.fullmatch(url) is not None
    ]
    preview_images = [
        (url, alt)
        for url, alt in all_preview_images
        if preview_re.fullmatch(url) is not None
    ]
    if not preview_images:
        errors.append(
            "UI PR 본문에는 "
            f"`https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-{number}/...png` "
            "형식으로 GitHub에 렌더링된 캡처 이미지가 필요합니다."
        )
    if any(preview_re.fullmatch(url) is None for url, _alt in all_preview_images):
        errors.append(f"모든 UI 캡처 이미지는 현재 PR 경로 `ui-previews/pr-{number}/`를 사용해야 합니다.")
    if any(not alt.strip() for _url, alt in all_preview_images):
        errors.append("UI 캡처 이미지에는 화면을 설명하는 대체 텍스트가 필요합니다.")
    if any(ANY_RAW_PREVIEW_RE.fullmatch(url) is not None for url in parser.plain_links):
        errors.append("모든 캡처 URL은 PR에서 바로 보이는 Markdown 인라인 이미지 `![설명](URL)`로 작성해야 합니다.")

    return errors


def _fetch_pr_body_html(event: dict[str, Any]) -> str:
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        raise ValueError("pull_request payload is missing")
    number = int(pr.get("number", 0))
    api_base = os.environ.get("GITHUB_API_URL", "")
    repository = os.environ.get("GITHUB_REPOSITORY", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    if api_base == "" or repository == "" or number <= 0 or token == "":
        raise ValueError("GITHUB_API_URL, GITHUB_REPOSITORY, pull request number, and GITHUB_TOKEN are required")
    api_url = f"{api_base.rstrip('/')}/repos/{repository}/pulls/{number}"
    api_request = request.Request(
        api_url,
        headers={
            "Accept": "application/vnd.github.full+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "seoul-challenge-ui-capture-validator",
        },
    )
    with request.urlopen(api_request, timeout=15) as response:
        payload = json.load(response)
    body_html = payload.get("body_html") if isinstance(payload, dict) else None
    if not isinstance(body_html, str):
        raise ValueError("GitHub pull request response did not include body_html")
    return body_html


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

    event = _load_event(Path(event_path))
    pr = event.get("pull_request")
    if isinstance(pr, dict) and _is_ui_pull_request(pr) and not isinstance(pr.get("body_html"), str):
        try:
            pr["body_html"] = _fetch_pr_body_html(event)
        except Exception as error:
            print(f"[verify_pr_ui_capture] FAIL: GitHub 렌더링 본문 조회 실패: {error}", file=sys.stderr)
            return 1
    errors = validate_pr_capture(event)
    if errors:
        for error in errors:
            print(f"[verify_pr_ui_capture] FAIL: {error}", file=sys.stderr)
        return 1

    print("[verify_pr_ui_capture] OK: UI capture contract satisfied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
