# Onboarding Death Retry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 온보딩 사망 결과에서 학교 복귀를 제거하고 같은 온보딩을 실패 안전하게 다시 시작한다.

**Architecture:** `SessionUIRoot`가 결과 종류별 action model을 계산하고, `SessionRoot`가 재시작 handoff와 실패 복구를 담당한다. 일반 사망과 온보딩 성공의 기존 분기는 유지하며 `onboarding death`만 별도 상태로 취급한다.

**Tech Stack:** Godot 4.6.3, GDScript, custom unit/integration runner, headed Chromium WebGL2 UAT

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- GitHub issue `#545`, branch `fix/issue-545-onboarding-death-retry`, worktree `../seoul-challenge-545`를 `origin/main`에서 생성한다.
- 온보딩 사망만 학교 복귀를 숨긴다. 일반 사망과 온보딩 성공 결과는 바꾸지 않는다.
- 재시작 실패를 학교 복귀로 대체하지 않는다.
- `test_id=session.return_button`, `test_id=session.retry_button`, `uat_action=session.retry`를 보존한다.
- 모든 commit, PR title/body는 한국어로 쓴다. PR은 ready, assignee, milestone, `P1`, `area:run`, `area:ui`를 갖는다.
- 검증 명령은 `PYTHON_BIN=/opt/homebrew/bin/python3.12`, `GODOT_BIN=/opt/homebrew/bin/godot`를 사용한다.

---

### Task 1: 결과 action model을 테스트하고 분리

**Files:**
- Modify: `tests/unit/test_session_summary_ui.gd`
- Modify: `scripts/ui/session_ui_root.gd:270-310`
- Modify: `scripts/ui/session_ui_root.gd:875-920`

**Interfaces:**
- Consumes: result Dictionary의 `outcome`, `died`, `onboarding_kind`, `reason`
- Produces: `result_action_model(result: Dictionary) -> Dictionary`, 확장된 `get_summary_snapshot()` action 필드

- [ ] **Step 1: 온보딩 사망·일반 사망·온보딩 성공의 실패 테스트 작성**

```gdscript
func test_onboarding_death_offers_retry_only() -> void:
	_ui.show_summary({
		"outcome": "death",
		"died": true,
		"onboarding_kind": SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_false(snapshot["return_visible"], "onboarding death hides school return")
	_runner.assert_true(snapshot["retry_visible"], "onboarding death keeps retry")
	_runner.assert_eq(snapshot["retry_text"], "다시 도전", "retry copy is explicit")
	_runner.assert_eq(snapshot["retry_variant"], PixelButtonStyle.VARIANT_PRIMARY, "retry is the primary onboarding death action")
	_runner.assert_eq(snapshot["narrative"], "다시 일어나 첫 탐험을 이어가자.", "death copy does not claim school return")


func test_regular_death_keeps_both_result_actions() -> void:
	_ui.show_summary({"outcome": "death", "died": true})
	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_true(snapshot["return_visible"], "regular death keeps school return")
	_runner.assert_true(snapshot["retry_visible"], "regular death keeps retry")


func test_onboarding_success_keeps_school_return_only() -> void:
	_ui.show_summary({
		"completed": true,
		"reason": "onboarding_friend_purified",
		"onboarding_kind": SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_true(snapshot["return_visible"], "onboarding success returns to school")
	_runner.assert_false(snapshot["retry_visible"], "onboarding success stays non-retryable")
```

- [ ] **Step 2: unit runner를 실행해 새 단정이 실패하는지 확인**

Run:

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: 새 snapshot key 또는 온보딩 death visibility/copy 단정이 FAIL.

- [ ] **Step 3: 결과 action model과 snapshot을 최소 구현**

```gdscript
func result_action_model(result: Dictionary) -> Dictionary:
	var death := _is_death_result(result)
	var onboarding := _is_onboarding_result(result)
	if death and onboarding:
		return {
			"return_visible": false,
			"retry_visible": true,
			"retry_text": "다시 도전",
			"retry_variant": PixelButtonStyle.VARIANT_PRIMARY,
		}
	if onboarding:
		return {
			"return_visible": true,
			"retry_visible": false,
			"retry_text": "다시 밤으로",
			"retry_variant": PixelButtonStyle.VARIANT_SECONDARY,
		}
	return {
		"return_visible": true,
		"retry_visible": true,
		"retry_text": "다시 밤으로",
		"retry_variant": PixelButtonStyle.VARIANT_SECONDARY,
	}
```

`show_summary()`는 model을 적용하고 `_result_narrative()`는 onboarding death를 일반 death보다 먼저 판정한다. `get_summary_snapshot()`에는 `return_visible`, `retry_visible`, `return_text`, `retry_text`, `retry_variant`를 추가한다.

- [ ] **Step 4: unit runner를 다시 실행해 600+ tests가 모두 PASS인지 확인**

Run: Step 2와 동일.

Expected: `Results: N passed, 0 failed`이며 세 새 테스트 PASS.

- [ ] **Step 5: action model 변경 커밋**

```bash
git add scripts/ui/session_ui_root.gd tests/unit/test_session_summary_ui.gd
git commit -m "[Session] 온보딩 사망 결과를 재도전 중심으로 전환"
```

### Task 2: 재시작 실패를 결과 화면에서 복구

**Files:**
- Modify: `tests/integration/test_session_contract.gd:2096-2190`
- Modify: `scripts/session/session_root.gd:1135-1165`

**Interfaces:**
- Consumes: `retry_session_callable(config: Dictionary) -> Error`, `SessionUIRoot.set_status(text)`
- Produces: `_on_retry_requested()`의 성공 handoff와 실패 복구 계약

- [ ] **Step 1: 온보딩 death 성공 재시작과 실패 복구 integration 테스트 작성**

```gdscript
func test_onboarding_death_retry_restarts_same_onboarding_without_school() -> void:
	var session := _instantiate_baseball_onboarding_session()
	var calls := {"school": 0, "configs": []}
	session.return_to_school_callable = func() -> void: calls["school"] += 1
	session.retry_session_callable = func(config: Dictionary) -> Error:
		calls["configs"].append(config.duplicate(true))
		return OK
	(session.get_node("%DeathReturnController") as DeathReturnController).trigger_death_return()
	(session.get_node("%SessionUIRoot").get_node("%RetryButton") as Button).pressed.emit()
	_runner.assert_eq(calls["school"], 0, "death retry never returns to school")
	_runner.assert_eq(calls["configs"].size(), 1, "retry creates one replacement")
	_runner.assert_eq(calls["configs"][0]["onboarding_kind"], SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN, "retry preserves onboarding kind")


func test_failed_onboarding_retry_keeps_summary_retryable() -> void:
	var session := _instantiate_baseball_onboarding_session()
	session.retry_session_callable = func(_config: Dictionary) -> Error: return ERR_CANT_CREATE
	(session.get_node("%DeathReturnController") as DeathReturnController).trigger_death_return()
	session.call("_on_retry_requested")
	var ui := session.get_node("%SessionUIRoot")
	_runner.assert_true(bool(ui.call("is_summary_visible")), "failed retry keeps death summary")
	_runner.assert_true((ui.get_node("%RetryButton") as Button).visible, "failed retry can be pressed again")
	_runner.assert_eq(session.get("_handoff_session_on_exit"), false, "failed retry cancels handoff")
```

- [ ] **Step 2: integration runner로 실패 재현**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
```

Expected: retry failure가 summary/status를 복구하지 못해 새 테스트 FAIL.

- [ ] **Step 3: `_on_retry_requested()` 실패 경로 구현**

```gdscript
func _on_retry_requested() -> void:
	var config := GameManager.get_active_config()
	_finish_all_onboarding_ui()
	_handoff_session_on_exit = true
	config["source"] = "session_result_retry"
	var result: Variant = retry_session_callable.call(config) if retry_session_callable.is_valid() else SceneTransition.start_session(config)
	if result is int and result != OK:
		_handoff_session_on_exit = false
		get_tree().paused = true
		session_ui_root.set_status("다시 시작하지 못했습니다. 다시 시도해 주세요.")
		session_ui_root.restore_summary_actions()
```

`restore_summary_actions()`는 마지막 `show_summary()` result의 action model만 다시 적용하며 새 navigation을 만들지 않는다.

- [ ] **Step 4: unit과 integration runner 재실행**

Run: Task 1 Step 2와 Task 2 Step 2.

Expected: 둘 다 0 failed.

- [ ] **Step 5: 재시작 실패 복구 커밋**

```bash
git add scripts/session/session_root.gd scripts/ui/session_ui_root.gd tests/integration/test_session_contract.gd tests/unit/test_session_summary_ui.gd
git commit -m "[Session] 온보딩 재도전 실패를 결과 화면에서 복구"
```

### Task 3: Release Web UAT와 merge gate

**Files:**
- Modify: `tests/uat/session_cleanup_web_fixture.gd`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Consumes: `uat_session_cleanup_mode=onboarding_death_retry|onboarding_retry_failure`
- Produces: `UAT_SESSION_CLEANUP_READY` marker와 #545 증거 행

- [ ] **Step 1: fixture에 두 결정론 mode 추가**

`onboarding_death_retry`는 real SessionRoot death summary에서 `return_visible=false`, `retry_visible=true`, replacement config의 onboarding kind 보존을 marker에 기록한다. `onboarding_retry_failure`는 `ERR_CANT_CREATE` callback 뒤 summary와 retry가 계속 보이는지 기록한다.

```gdscript
print("UAT_SESSION_CLEANUP_READY mode=%s return_visible=%s retry_visible=%s replacement_kind=%s summary=%s valid=%s" % [
	_mode,
	str(snapshot["return_visible"]).to_lower(),
	str(snapshot["retry_visible"]).to_lower(),
	String(replacement_kind),
	str(session_ui.is_summary_visible()).to_lower(),
	str(valid).to_lower(),
])
```

- [ ] **Step 2: quick와 full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

Expected: unit/integration/functional/tooling 모두 0 failed.

- [ ] **Step 3: release Web fixture를 export하고 headed Chromium에서 두 mode 검증**

fixture export는 `project.godot`의 main scene을 `res://tests/uat/session_cleanup_web_fixture.tscn`으로 임시 변경해 `bash scripts/export_web_preview.sh`를 실행한 뒤 즉시 복원한다. 각 URL은 `valid=true`, console/page/request error 0이어야 한다.

```text
http://127.0.0.1:8765/?uat_session_cleanup_mode=onboarding_death_retry
http://127.0.0.1:8765/?uat_session_cleanup_mode=onboarding_retry_failure
```

- [ ] **Step 4: 960×540 사망 결과와 재도전 후 화면 캡처**

캡처 파일명:

```text
onboarding-death-retry-960x540.png
onboarding-retry-restarted-960x540.png
```

- [ ] **Step 5: fixture·장부 커밋**

```bash
git add tests/uat/session_cleanup_web_fixture.gd tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] 온보딩 사망 재도전 Web 증거 추가"
```

- [ ] **Step 6: ready PR을 열고 merge loop 완료**

PR title: `[Session] 온보딩 사망 후 재도전 고정`

PR body에 quick/full 수, 두 UAT marker, 렌더링되는 raw PNG 두 장, `Closes #545`를 넣는다. current-head Codex pass, Quick/UI capture/Rooms/Web Preview green, unresolved 0이면 `gh pr merge "$(gh pr view --json number -q .number)" --merge --delete-branch`로 즉시 merge한다.
