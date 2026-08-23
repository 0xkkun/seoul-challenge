#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
import zlib
from collections.abc import Callable
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from urllib import request
from urllib.parse import unquote, urlsplit


UI_TITLE_RE = re.compile(r"^\s*\[UI\]")
RAW_PREVIEW_TEMPLATE = (
    r"(?i:https://raw\.githubusercontent\.com/0xkkun/seoul-challenge)/"
    r"ui-previews/pr-{number}/[^\s]+?\.png(?:[?#][^\s]*)?"
)
ANY_RAW_PREVIEW_RE = re.compile(
    r"(?i:https://raw\.githubusercontent\.com/0xkkun/seoul-challenge)/"
    r"ui-previews/pr-\d+/[^\s]+?\.(?:png|jpg|jpeg|webp)(?:[?#][^\s]*)?"
)
ZERO_LENGTH_RE = re.compile(r"^[+-]?0+(?:\.0+)?(?:px|%|em|rem|vw|vh)?$", re.IGNORECASE)
VOID_HTML_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input", "link",
    "meta", "param", "source", "track", "wbr",
}
ALLOWED_PREVIEW_ATTRIBUTES = {
    ("a", "href"),
    ("img", "data-canonical-src"),
    ("img", "src"),
    ("img", "srcset"),
    ("source", "srcset"),
}
MAX_PREVIEW_BYTES = 10 * 1024 * 1024
MAX_DECODED_PREVIEW_BYTES = 64 * 1024 * 1024


class UiCaptureHtmlParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.section_found = False
        self.in_section = False
        self.images: list[tuple[str, str]] = []
        self.outside_images: list[tuple[str, str]] = []
        self.rejected_images: list[str] = []
        self.rejected_responsive_markup = False
        self.plain_links: list[str] = []
        self.visible_text_parts: list[str] = []
        self._heading_tag = ""
        self._heading_parts: list[str] = []
        self._anchors: list[dict[str, Any]] = []
        self._element_stack: list[tuple[str, bool, bool, bool]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag_name = tag.casefold()
        attr_map = {name.casefold(): value or "" for name, value in attrs}
        for attribute_name, value in attr_map.items():
            if (tag_name, attribute_name) not in ALLOWED_PREVIEW_ATTRIBUTES:
                self.rejected_images.extend(
                    match.group(0) for match in ANY_RAW_PREVIEW_RE.finditer(value)
                )
        if tag_name == "summary" and self._element_stack and self._element_stack[-1][0] == "details":
            details_tag, details_hidden, summary_hidden, summary_seen = self._element_stack[-1]
            parent_hidden = details_hidden if summary_seen else summary_hidden
            self._element_stack[-1] = (details_tag, details_hidden, summary_hidden, True)
        else:
            parent_hidden = self._element_stack[-1][1] if self._element_stack else False
        attribute_hidden = "hidden" in attr_map or _style_hides(attr_map.get("style", ""))
        closed_details = tag_name == "details" and "open" not in attr_map
        element_hidden = (
            parent_hidden
            or attribute_hidden
            or closed_details
            or tag_name == "picture"
        )
        if tag_name not in VOID_HTML_TAGS:
            details_summary_hidden = parent_hidden or attribute_hidden
            self._element_stack.append((tag_name, element_hidden, details_summary_hidden, False))
        if tag_name in {"img", "source"} and "srcset" in attr_map:
            self.rejected_images.extend(
                match.group(0) for match in ANY_RAW_PREVIEW_RE.finditer(attr_map["srcset"])
            )
            if self.in_section:
                self.rejected_responsive_markup = True
        if tag_name in {"h1", "h2"}:
            if element_hidden:
                return
            self.in_section = False
            self._heading_tag = tag_name
            self._heading_parts = []
            return
        if tag_name == "a":
            if not element_hidden:
                self._anchors.append({"href": attr_map.get("href", ""), "image_urls": []})
            return
        elif tag_name == "img":
            image_url = attr_map.get("data-canonical-src", "") or attr_map.get("src", "")
            if element_hidden:
                self.rejected_images.append(image_url)
                return
            if self._anchors:
                self._anchors[-1]["image_urls"].append(image_url)
            if "width" in attr_map or "height" in attr_map or "srcset" in attr_map:
                self.rejected_images.append(image_url)
                return
            if not self.in_section:
                self.outside_images.append((image_url, attr_map.get("alt", "")))
                return
            self.images.append((image_url, attr_map.get("alt", "")))

    def handle_data(self, data: str) -> None:
        if self._inside_hidden_element():
            return
        if self._heading_tag:
            self._heading_parts.append(data)
        self.visible_text_parts.append(data)

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
            if str(anchor["href"]) not in anchor["image_urls"]:
                self.plain_links.append(str(anchor["href"]))
        self._pop_element(tag_name)

    def _pop_element(self, tag_name: str) -> None:
        for index in range(len(self._element_stack) - 1, -1, -1):
            if self._element_stack[index][0] == tag_name:
                del self._element_stack[index:]
                return

    def _inside_hidden_element(self) -> bool:
        return bool(self._element_stack and self._element_stack[-1][1])


def _zero_dimension(value: str) -> bool:
    return bool(value.strip() and ZERO_LENGTH_RE.fullmatch(value.strip()))


def _has_unsafe_preview_path(url: str) -> bool:
    decoded_path = urlsplit(url).path
    for _pass in range(4):
        next_path = unquote(decoded_path)
        if next_path == decoded_path:
            break
        decoded_path = next_path
    if "\\" in decoded_path:
        return True
    return any(segment in {".", ".."} for segment in decoded_path.split("/"))


def _style_hides(style: str) -> bool:
    for declaration in style.casefold().split(";"):
        name, separator, value = declaration.partition(":")
        if separator == "":
            continue
        property_name = name.strip()
        property_value = re.sub(r"\s*!important\s*$", "", value.strip()).strip()
        if property_name == "display" and property_value == "none":
            return True
        if property_name == "visibility" and property_value == "hidden":
            return True
        if property_name in {"width", "height"}:
            return True
        if property_name in {"opacity", "max-width", "max-height"} and _zero_dimension(property_value):
            return True
    return False


def validate_pr_capture(
    event: dict[str, Any],
    url_probe: Callable[[str], bool] | None = None,
) -> list[str]:
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
        if preview_re.fullmatch(url) is not None and not _has_unsafe_preview_path(url)
    ]
    if not preview_images:
        errors.append(
            "UI PR 본문에는 "
            f"`https://raw.githubusercontent.com/0xkkun/seoul-challenge/ui-previews/pr-{number}/...png` "
            "형식으로 GitHub에 렌더링된 캡처 이미지가 필요합니다."
        )
    if any(preview_re.fullmatch(url) is None for url, _alt in all_preview_images):
        errors.append(f"모든 UI 캡처 이미지는 현재 PR 경로 `ui-previews/pr-{number}/`를 사용해야 합니다.")
    if any(_has_unsafe_preview_path(url) for url, _alt in all_preview_images):
        errors.append("UI 캡처 이미지 URL에는 정규화 결과를 바꾸는 dot segment를 사용할 수 없습니다.")
    if any(ANY_RAW_PREVIEW_RE.fullmatch(url) is not None for url, _alt in parser.outside_images):
        errors.append("모든 UI 캡처 이미지는 `## UI 캡처` 섹션 안에 있어야 합니다.")
    if any(ANY_RAW_PREVIEW_RE.fullmatch(url) is not None for url in parser.rejected_images):
        errors.append("모든 UI 캡처 URL은 즉시 보이는 이미지로 렌더링되어야 합니다.")
    if parser.rejected_responsive_markup:
        errors.append("UI 캡처 섹션에서는 responsive image markup을 사용할 수 없습니다.")
    if any(not alt.strip() for _url, alt in all_preview_images):
        errors.append("UI 캡처 이미지에는 화면을 설명하는 대체 텍스트가 필요합니다.")
    if url_probe is not None:
        for preview_url in dict.fromkeys(url for url, _alt in preview_images):
            if not url_probe(preview_url):
                errors.append(f"UI 캡처 이미지를 불러올 수 없습니다: {preview_url}")
    if (
        any(ANY_RAW_PREVIEW_RE.fullmatch(url) is not None for url in parser.plain_links)
        or ANY_RAW_PREVIEW_RE.search("".join(parser.visible_text_parts)) is not None
    ):
        errors.append("모든 캡처 URL은 PR에서 바로 보이는 Markdown 인라인 이미지 `![설명](URL)`로 작성해야 합니다.")

    return errors


def _preview_url_loads(url: str) -> bool:
    probe_request = request.Request(
        url,
        headers={
            "Accept": "image/*",
            "User-Agent": "seoul-challenge-ui-capture-validator",
        },
        method="GET",
    )
    try:
        with request.urlopen(probe_request, timeout=15) as response:
            status = int(getattr(response, "status", 0))
            content_type = str(response.getheader("Content-Type", "")).casefold()
            payload = response.read(MAX_PREVIEW_BYTES + 1)
            return (
                200 <= status < 300
                and content_type.startswith("image/")
                and len(payload) <= MAX_PREVIEW_BYTES
                and _valid_image_payload(content_type, payload)
            )
    except Exception:
        return False


def _valid_image_payload(content_type: str, data: bytes) -> bool:
    media_type = content_type.split(";", 1)[0].strip()
    if media_type == "image/png":
        return _valid_png_payload(data)
    return False


def _valid_png_payload(data: bytes) -> bool:
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    offset = 8
    seen_ihdr = False
    seen_plte = False
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    interlace_method = 0
    idat_parts: list[bytes] = []
    while offset + 12 <= len(data):
        chunk_length = int.from_bytes(data[offset:offset + 4], "big")
        chunk_type = data[offset + 4:offset + 8]
        if (
            len(chunk_type) != 4
            or any(byte not in range(ord("A"), ord("Z") + 1) and byte not in range(ord("a"), ord("z") + 1) for byte in chunk_type)
            or chunk_type[2] & 0x20
        ):
            return False
        known_critical_chunks = {b"IHDR", b"PLTE", b"IDAT", b"IEND"}
        if not chunk_type[0] & 0x20 and chunk_type not in known_critical_chunks:
            return False
        chunk_end = offset + 12 + chunk_length
        if chunk_end > len(data):
            return False
        chunk_data = data[offset + 8:offset + 8 + chunk_length]
        expected_crc = int.from_bytes(data[offset + 8 + chunk_length:chunk_end], "big")
        actual_crc = zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            return False
        if not seen_ihdr:
            if chunk_type != b"IHDR" or chunk_length != 13:
                return False
            width = int.from_bytes(chunk_data[0:4], "big")
            height = int.from_bytes(chunk_data[4:8], "big")
            bit_depth = chunk_data[8]
            color_type = chunk_data[9]
            compression_method = chunk_data[10]
            filter_method = chunk_data[11]
            interlace_method = chunk_data[12]
            valid_depths = {
                0: {1, 2, 4, 8, 16},
                2: {8, 16},
                3: {1, 2, 4, 8},
                4: {8, 16},
                6: {8, 16},
            }
            if (
                width <= 0
                or height <= 0
                or bit_depth not in valid_depths.get(color_type, set())
                or compression_method != 0
                or filter_method != 0
                or interlace_method not in {0, 1}
            ):
                return False
            seen_ihdr = True
        elif chunk_type == b"IHDR":
            return False
        if chunk_type == b"PLTE":
            seen_plte = True
        if chunk_type == b"IDAT":
            idat_parts.append(chunk_data)
        if chunk_type == b"IEND":
            return (
                chunk_length == 0
                and bool(idat_parts)
                and (color_type != 3 or seen_plte)
                and chunk_end == len(data)
                and _valid_png_scanlines(
                    b"".join(idat_parts),
                    width,
                    height,
                    bit_depth,
                    color_type,
                    interlace_method,
                )
            )
        offset = chunk_end
    return False


def _valid_png_scanlines(
    compressed_data: bytes,
    width: int,
    height: int,
    bit_depth: int,
    color_type: int,
    interlace_method: int,
) -> bool:
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    bits_per_pixel = channels * bit_depth
    passes = [(0, 0, 1, 1)]
    if interlace_method == 1:
        passes = [
            (0, 0, 8, 8),
            (4, 0, 8, 8),
            (0, 4, 4, 8),
            (2, 0, 4, 4),
            (0, 2, 2, 4),
            (1, 0, 2, 2),
            (0, 1, 1, 2),
        ]
    pass_rows: list[tuple[int, int]] = []
    expected_size = 0
    for start_x, start_y, step_x, step_y in passes:
        pass_width = 0 if width <= start_x else (width - start_x + step_x - 1) // step_x
        pass_height = 0 if height <= start_y else (height - start_y + step_y - 1) // step_y
        if pass_width == 0 or pass_height == 0:
            continue
        row_bytes = (pass_width * bits_per_pixel + 7) // 8
        pass_rows.append((pass_height, row_bytes))
        expected_size += pass_height * (row_bytes + 1)
    if expected_size <= 0 or expected_size > MAX_DECODED_PREVIEW_BYTES:
        return False
    try:
        decoder = zlib.decompressobj()
        decoded = decoder.decompress(compressed_data, expected_size + 1)
        if len(decoded) > expected_size or decoder.unconsumed_tail:
            return False
        decoded += decoder.flush(expected_size + 1 - len(decoded))
    except zlib.error:
        return False
    if (
        len(decoded) != expected_size
        or not decoder.eof
        or decoder.unused_data
        or decoder.unconsumed_tail
    ):
        return False
    cursor = 0
    for pass_height, row_bytes in pass_rows:
        for _row in range(pass_height):
            if decoded[cursor] > 4:
                return False
            cursor += row_bytes + 1
    return cursor == len(decoded)


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
    errors = validate_pr_capture(event, url_probe=_preview_url_loads)
    if errors:
        for error in errors:
            print(f"[verify_pr_ui_capture] FAIL: {error}", file=sys.stderr)
        return 1

    print("[verify_pr_ui_capture] OK: UI capture contract satisfied")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
