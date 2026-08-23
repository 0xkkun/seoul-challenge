#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import io
import json
import os
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts" / "verify_pr_ui_capture.py"
PR_HYGIENE_PATH = ROOT / "docs" / "pr-hygiene.md"
VERIFY_WORKFLOW_PATH = ROOT / ".github" / "workflows" / "verify.yml"


def load_module():
    spec = importlib.util.spec_from_file_location("verify_pr_ui_capture", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("verify_pr_ui_capture.py could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def preview_url(number: int, name: str = "session-pause-modal-960x540.png") -> str:
    return (
        "https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
        f"ui-previews/pr-{number}/{name}"
    )


def pr_event(number: int, title: str, body: str, labels: list[str], body_html: str | None = None) -> dict:
    pull_request = {
        "number": number,
        "title": title,
        "body": body,
        "labels": [{"name": label} for label in labels],
    }
    if body_html is not None:
        pull_request["body_html"] = body_html
    return {"pull_request": pull_request}


class VerifyPrUiCaptureTest(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()

    def test_ui_pr_requires_capture_section(self) -> None:
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            "## 요약\n- 변경",
            ["area:ui"],
            "<h2>요약</h2><p>변경</p>",
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("## UI 캡처" in error for error in errors))

    def test_ui_pr_rejects_plain_raw_preview_url(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            "## UI 캡처\n화면: " + url,
            ["area:ui"],
            f'<h2>UI 캡처</h2><p><a href="{url}">화면</a></p>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("인라인 이미지" in error for error in errors))

    def test_ui_pr_accepts_matching_inline_raw_preview(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n![인게임 일시정지 모달]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><p><a href="{url}"><img src="{url}" alt="인게임 일시정지 모달"></a></p>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_pr_rejects_preview_that_probe_cannot_load(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n![화면]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{url}" alt="화면">',
        )

        try:
            errors = self.module.validate_pr_capture(event, url_probe=lambda _url: False)
        except TypeError as error:
            self.fail(f"validator should accept a URL probe: {error}")

        self.assertTrue(any("불러올 수" in error for error in errors))

    def test_ui_preview_outside_capture_section_does_not_satisfy_contract(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n- 캡처 없음\n\n## 기타\n![화면]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><p>캡처 없음</p><h2>기타</h2><img src="{url}" alt="화면">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))

    def test_plain_preview_link_outside_capture_section_is_rejected(self) -> None:
        image_url = preview_url(203)
        plain_url = preview_url(203, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n![화면]({image_url})\n\n## 기타\n[설정]({plain_url})",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><a href="{image_url}"><img src="{image_url}" alt="화면"></a>'
                f'<h2>기타</h2><a href="{plain_url}">설정</a>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_visible_plain_preview_text_is_rejected(self) -> None:
        image_url = preview_url(203)
        text_url = preview_url(203, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{image_url}" alt="화면">'
                f'<div>{text_url}</div>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_visible_plain_preview_url_in_heading_is_rejected(self) -> None:
        image_url = preview_url(203)
        heading_url = preview_url(203, "heading-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{image_url}" alt="화면"><h2>{heading_url}</h2>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_preview_image_outside_capture_section_is_rejected(self) -> None:
        section_url = preview_url(203)
        outside_url = preview_url(203, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n![화면]({section_url})\n\n## 기타\n![설정]({outside_url})",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{section_url}" alt="화면">'
                f'<h2>기타</h2><img src="{outside_url}" alt="설정">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("섹션 안" in error for error in errors))

    def test_ui_pr_rejects_plain_url_even_when_another_preview_is_inline(self) -> None:
        image_url = preview_url(203)
        plain_url = preview_url(203, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n![모달]({image_url})\n설정: {plain_url}",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><p><a href="{image_url}"><img src="{image_url}" alt="모달"></a></p>'
                f'<p>설정: <a href="{plain_url}">{plain_url}</a></p>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_preview_link_requires_an_image_with_the_same_url(self) -> None:
        image_url = preview_url(203)
        disguised_link = preview_url(203, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n![모달]({image_url})",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{image_url}" alt="모달">'
                f'<a href="{disguised_link}"><img src="https://example.com/decoy.png" alt="대체 이미지"></a>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_ui_pr_rejects_preview_url_in_other_media_attribute(self) -> None:
        image_url = preview_url(203)
        poster_url = preview_url(999, "poster-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{image_url}" alt="화면">'
                f'<video poster="{poster_url}"></video>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_responsive_picture_wrapper(self) -> None:
        fallback_url = preview_url(203)
        source_url = preview_url(999, "responsive-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                '<h2>UI 캡처</h2><picture>'
                f'<source srcset="{source_url}">'
                f'<img src="{fallback_url}" alt="화면">'
                '</picture>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_responsive_img_srcset(self) -> None:
        fallback_url = preview_url(203)
        source_url = preview_url(999, "responsive-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{fallback_url}" srcset="{source_url} 2x" alt="화면">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_raw_srcset_with_external_fallback(self) -> None:
        visible_url = preview_url(203)
        source_url = preview_url(999, "responsive-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{visible_url}" alt="화면">'
                f'<img src="https://example.com/fallback.png" srcset="{source_url} 2x" alt="반응형">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_raw_srcset_url_with_comma(self) -> None:
        visible_url = preview_url(203)
        source_url = preview_url(999, "foo,bar.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{visible_url}" alt="화면">'
                f'<img src="https://example.com/fallback.png" srcset="{source_url} 2x" alt="반응형">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_inline_preview_without_alt_text(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n![]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{url}" alt="">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("대체 텍스트" in error for error in errors))

    def test_ui_pr_rejects_inline_preview_with_whitespace_only_alt_text(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n![   ]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{url}" alt="   ">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("대체 텍스트" in error for error in errors))

    def test_github_rendered_html_is_authoritative_over_raw_markdown(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 인게임 일시정지 모달 표시 복구",
            f"## UI 캡처\n![화면]({url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><pre>![화면]({url})</pre>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_preview_hidden_in_closed_details(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n<details>\n![화면]({url})\n</details>",
            ["area:ui"],
            f'<h2>UI 캡처</h2><details><summary>캡처</summary><img src="{url}" alt="화면"></details>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_accepts_preview_in_open_details(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n<details open>\n![화면]({url})\n</details>",
            ["area:ui"],
            f'<h2>UI 캡처</h2><details open><summary>캡처</summary><img src="{url}" alt="화면"></details>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_pr_accepts_preview_in_closed_details_summary(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n<details>\n<summary>![화면]({url})</summary>\n</details>",
            ["area:ui"],
            f'<h2>UI 캡처</h2><details><summary><img src="{url}" alt="화면"></summary></details>',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_pr_rejects_preview_in_second_closed_details_summary(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                '<h2>UI 캡처</h2><details><summary>첫 요약</summary>'
                f'<summary><img src="{url}" alt="화면"></summary></details>'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_preview_hidden_by_html_visibility(self) -> None:
        url = preview_url(203)
        hidden_html = {
            "zero_size": f'<h2>UI 캡처</h2><img src="{url}" alt="화면" width="0" height="0">',
            "tiny_size": f'<h2>UI 캡처</h2><img src="{url}" alt="화면" width="1" height="1">',
            "hidden_parent": f'<h2>UI 캡처</h2><div hidden><img src="{url}" alt="화면"></div>',
            "display_none": f'<h2>UI 캡처</h2><div style="display: none"><img src="{url}" alt="화면"></div>',
            "display_none_important": f'<h2>UI 캡처</h2><div style="display: none !important"><img src="{url}" alt="화면"></div>',
            "visibility_hidden_important": f'<h2>UI 캡처</h2><div style="visibility: hidden !important"><img src="{url}" alt="화면"></div>',
        }

        for case, body_html in hidden_html.items():
            with self.subTest(case=case):
                event = pr_event(203, "[UI] 화면", "## UI 캡처", ["area:ui"], body_html)

                errors = self.module.validate_pr_capture(event)

                self.assertNotEqual(errors, [])

    def test_ui_pr_rejects_hidden_preview_mixed_with_valid_image(self) -> None:
        visible_url = preview_url(203)
        hidden_url = preview_url(203, "hidden-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{visible_url}" alt="화면">'
                f'<img src="{hidden_url}" alt="숨김" width="0">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("보이는 이미지" in error for error in errors))

    def test_ui_capture_heading_ignores_hidden_text(self) -> None:
        url = preview_url(203)
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            f'<h2><span hidden>UI </span>캡처</h2><img src="{url}" alt="화면">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("## UI 캡처" in error for error in errors))

    def test_ui_pr_requires_github_rendered_html(self) -> None:
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", "## UI 캡처", ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("body_html" in error for error in errors))

    def test_non_ui_pr_does_not_require_capture(self) -> None:
        event = pr_event(205, "[Docs] 문서 정리", "## 요약\n- 문서", ["area:run"])

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_capture_url_must_match_current_pr_number(self) -> None:
        wrong_url = preview_url(999)
        event = pr_event(
            203,
            "[Scene] UI 라벨 수정",
            f"## UI 캡처\n![인게임 일시정지 모달]({wrong_url})",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{wrong_url}" alt="인게임 일시정지 모달">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))

    def test_ui_capture_rejects_other_pr_preview_mixed_with_valid_image(self) -> None:
        current_url = preview_url(203)
        wrong_url = preview_url(999, "settings-960x540.png")
        event = pr_event(
            203,
            "[UI] 화면",
            f"## UI 캡처\n![현재]({current_url})\n![다른 PR]({wrong_url})",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                f'<img src="{wrong_url}" alt="다른 PR">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))

    def test_ui_capture_classifies_query_and_fragment_suffixes(self) -> None:
        current_url = preview_url(203)
        wrong_query_url = preview_url(999, "settings-960x540.png") + "?raw=1"
        plain_fragment_url = preview_url(203, "plain-960x540.png") + "#preview"
        cases = {
            "wrong_pr_image_query": (
                f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                f'<img src="{wrong_query_url}" alt="다른 PR">'
            ),
            "plain_link_fragment": (
                f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                f'<a href="{plain_fragment_url}">plain</a>'
            ),
        }

        for case, body_html in cases.items():
            with self.subTest(case=case):
                event = pr_event(203, "[UI] 화면", "## UI 캡처", ["area:ui"], body_html)

                errors = self.module.validate_pr_capture(event)

                self.assertNotEqual(errors, [])

    def test_ui_capture_classifies_parenthesized_query_values(self) -> None:
        current_url = preview_url(203)
        wrong_url = preview_url(999, "settings-960x540.png") + "?size=(large)"
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                f'<img src="{wrong_url}" alt="다른 PR">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_capture_rejects_dot_segment_paths(self) -> None:
        current_url = preview_url(203)
        unsafe_urls = {
            "raw": (
                "https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
                "ui-previews/pr-203/../pr-999/old.png"
            ),
            "encoded": (
                "https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
                "ui-previews/pr-203/%2e%2e/pr-999/old.png"
            ),
        }

        for case, unsafe_url in unsafe_urls.items():
            with self.subTest(case=case):
                event = pr_event(
                    203,
                    "[UI] 화면",
                    "## UI 캡처",
                    ["area:ui"],
                    (
                        f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                        f'<img src="{unsafe_url}" alt="우회">'
                    ),
                )

                errors = self.module.validate_pr_capture(event)

                self.assertNotEqual(errors, [])

    def test_ui_capture_classifies_case_insensitive_raw_host(self) -> None:
        current_url = preview_url(203)
        wrong_url = preview_url(999).replace(
            "raw.githubusercontent.com",
            "RAW.GITHUBUSERCONTENT.COM",
        )
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            (
                f'<h2>UI 캡처</h2><img src="{current_url}" alt="현재">'
                f'<img src="{wrong_url}" alt="다른 PR">'
            ),
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_ui_capture_keeps_preview_branch_path_case_sensitive(self) -> None:
        wrong_case_url = preview_url(203).replace(
            "ui-previews/pr-203",
            "UI-PREVIEWS/PR-203",
        )
        event = pr_event(
            203,
            "[UI] 화면",
            "## UI 캡처",
            ["area:ui"],
            f'<h2>UI 캡처</h2><img src="{wrong_case_url}" alt="화면">',
        )

        errors = self.module.validate_pr_capture(event)

        self.assertNotEqual(errors, [])

    def test_pr_hygiene_documents_inline_image_preview(self) -> None:
        guide = PR_HYGIENE_PATH.read_text(encoding="utf-8")

        self.assertIn("Markdown 인라인 이미지", guide)
        self.assertIn("![인게임 맵 탭]", guide)
        self.assertIn("GitHub 렌더링 결과", guide)

    def test_verify_workflow_exposes_github_token_for_body_html(self) -> None:
        workflow = VERIFY_WORKFLOW_PATH.read_text(encoding="utf-8")

        self.assertIn("GITHUB_TOKEN: ${{ github.token }}", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("pull-requests: read", workflow)

    def test_fetch_pr_body_html_uses_github_full_media_type(self) -> None:
        self.assertTrue(hasattr(self.module, "_fetch_pr_body_html"))
        event = pr_event(203, "[UI] 화면", "## UI 캡처", ["area:ui"])
        response = io.BytesIO(json.dumps({"body_html": "<h2>UI 캡처</h2>"}).encode("utf-8"))

        with (
            mock.patch.dict(os.environ, {
                "GITHUB_TOKEN": "test-token",
                "GITHUB_API_URL": "https://api.github.test",
                "GITHUB_REPOSITORY": "owner/repo",
            }),
            mock.patch.object(self.module.request, "urlopen", return_value=response) as urlopen,
        ):
            try:
                body_html = self.module._fetch_pr_body_html(event)
            except Exception as error:
                self.fail(f"GitHub Actions repository context should build the API URL: {error}")

        self.assertEqual(body_html, "<h2>UI 캡처</h2>")
        api_request = urlopen.call_args.args[0]
        self.assertEqual(api_request.full_url, "https://api.github.test/repos/owner/repo/pulls/203")
        self.assertEqual(api_request.get_header("Accept"), "application/vnd.github.full+json")
        self.assertEqual(api_request.get_header("Authorization"), "Bearer test-token")

    def test_preview_url_probe_requires_successful_image_response(self) -> None:
        self.assertTrue(hasattr(self.module, "_preview_url_loads"))

        class FakeResponse(io.BytesIO):
            def __init__(self, status: int, content_type: str, data: bytes = b"") -> None:
                super().__init__(data)
                self.status = status
                self.content_type = content_type

            def getheader(self, name: str, default: str = "") -> str:
                return self.content_type if name.casefold() == "content-type" else default

        valid_png = (
            b"\x89PNG\r\n\x1a\n"
            b"\x00\x00\x00\rIHDR"
            + (960).to_bytes(4, "big")
            + (540).to_bytes(4, "big")
            + b"\x08\x06\x00\x00\x00"
        )
        cases = {
            "image": (FakeResponse(200, "image/png", valid_png), True),
            "truncated_image": (FakeResponse(200, "image/png", b"not-a-png"), False),
            "not_found": (FakeResponse(404, "text/plain"), False),
            "not_image": (FakeResponse(200, "text/html"), False),
        }
        for case, (response, expected) in cases.items():
            with self.subTest(case=case), mock.patch.object(
                self.module.request,
                "urlopen",
                return_value=response,
            ) as urlopen:
                self.assertEqual(self.module._preview_url_loads(preview_url(203)), expected)
                if case == "image":
                    probe_request = urlopen.call_args.args[0]
                    self.assertEqual(probe_request.get_method(), "GET")
                    self.assertEqual(probe_request.get_header("Range"), "bytes=0-63")


if __name__ == "__main__":
    unittest.main()
