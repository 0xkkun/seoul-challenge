#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT_PATH = ROOT / "scripts" / "verify_pr_ui_capture.py"


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

    def test_ui_pr_accepts_matching_raw_preview_url(self) -> None:
        body = (
            "## 요약\n- 변경\n\n"
            "## UI 캡처\n"
            "- 화면: https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-203/session-pause-modal-960x540.png\n"
        )
        event = pr_event(203, "[UI] 인게임 일시정지 모달 표시 복구", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_non_ui_pr_does_not_require_capture(self) -> None:
        event = pr_event(205, "[Docs] 문서 정리", "## 요약\n- 문서", ["area:run"])

        errors = self.module.validate_pr_capture(event)

        self.assertEqual(errors, [])

    def test_ui_capture_url_must_match_current_pr_number(self) -> None:
        body = (
            "## UI 캡처\n"
            "- 화면: https://raw.githubusercontent.com/0xkkun/seoul-challenge/"
            "ui-previews/pr-999/session-pause-modal-960x540.png\n"
        )
        event = pr_event(203, "[Scene] UI 라벨 수정", body, ["area:ui"])

        errors = self.module.validate_pr_capture(event)

        self.assertTrue(any("pr-203" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
