#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts" / "verify_pr_ui_capture.py"
PR_HYGIENE_PATH = ROOT / "docs" / "pr-hygiene.md"


def load_module():
    spec = importlib.util.spec_from_file_location("verify_pr_ui_capture", SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("verify_pr_ui_capture.py could not be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def pr_event(number: int, title: str, body: str, labels: list[str]) -> dict:
    return {
        "pull_request": {
            "number": number,
            "title": title,
            "body": body,
            "labels": [{"name": label} for label in labels],
        }
    }


class VerifyPrUiCaptureTest(unittest.TestCase):
    def setUp(self) -> None:
        self.module = load_module()

    def test_ui_pr_requires_capture_section(self) -> None:
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", "## 요약\n- 변경", ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("## UI 캡처" in error for error in errors))

    def test_ui_pr_rejects_plain_raw_preview_url(self) -> None:
        body = (
            "## 요약\n- 변경\n\n"
            "## UI 캡처\n"
            "- 화면: https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("인라인 이미지" in error for error in errors))

    def test_ui_pr_accepts_matching_inline_raw_preview(self) -> None:
        body = (
            "## 요약\n- 변경\n\n"
            "## UI 캡처\n"
            "- ![인게임 일시정지 모달](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png)\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_preview_outside_capture_section_does_not_satisfy_contract(self) -> None:
        body = (
            "## UI 캡처\n- 캡처 없음\n\n"
            "## 기타\n"
            "![인게임 일시정지 모달](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png)\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))

    def test_ui_pr_rejects_plain_url_even_when_another_preview_is_inline(self) -> None:
        body = (
            "## UI 캡처\n"
            "![일시정지 모달](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png)\n"
            "설정 화면: https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/settings-960x540.png\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("모든 캡처 URL" in error for error in errors))

    def test_ui_pr_rejects_inline_preview_without_alt_text(self) -> None:
        body = (
            "## UI 캡처\n"
            "- ![](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png)\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("대체 텍스트" in error for error in errors))

    def test_ui_pr_rejects_inline_preview_with_whitespace_only_alt_text(self) -> None:
        body = (
            "## UI 캡처\n"
            "- ![   ](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png)\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("대체 텍스트" in error for error in errors))

    def test_ui_pr_rejects_image_syntax_that_markdown_does_not_render(self) -> None:
        raw_url = (
            "https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png"
        )
        literal_bodies = {
            "escaped": f"## UI 캡처\n\\![화면]({raw_url})\n",
            "inline_code": f"## UI 캡처\n`![화면]({raw_url})`\n",
            "multi_backtick_inline_code": f"## UI 캡처\n``![화면]({raw_url})``\n",
            "fenced_code": f"## UI 캡처\n```markdown\n![화면]({raw_url})\n```\n",
            "indented_code": f"## UI 캡처\n\n    ![화면]({raw_url})\n",
            "html_comment": f"## UI 캡처\n<!-- ![화면]({raw_url}) -->\n",
            "raw_html_block": f"## UI 캡처\n<pre>\n![화면]({raw_url})\n</pre>\n",
            "unclosed_raw_html_block": f"## UI 캡처\n<div>\n![화면]({raw_url})\n",
        }

        for case, body in literal_bodies.items():
            with self.subTest(case=case):
                event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

                errors = self.module.validate_pr_capture(event)

                self.assertNotEqual(errors, [])

    def test_non_ui_pr_does_not_require_capture(self) -> None:
        event = pr_event(205, "[Docs] 문서 정리", "## 요약\n- 문서", ["area:run"])

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_capture_url_must_match_current_pr_number(self) -> None:
        body = (
            "## UI 캡처\n"
            "- ![인게임 일시정지 모달](https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-999/session-pause-modal-960x540.png)\n"
        )
        event = pr_event(203, "[Scene] UI 라벨 수정", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))

    def test_pr_hygiene_documents_inline_image_preview(self) -> None:
        guide = PR_HYGIENE_PATH.read_text(encoding="utf-8")

        self.assertIn("Markdown 인라인 이미지", guide)
        self.assertIn("![인게임 맵 탭]", guide)


if __name__ == "__main__":
    unittest.main()
