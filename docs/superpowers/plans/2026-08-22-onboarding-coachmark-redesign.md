# Onboarding Coachmark Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 첫 5분의 모든 온보딩을 중앙 대형 카드에서 `키칩 + 행동어 + 대상 코너 브래킷 + 짧은 성공 모션`으로 교체한다.

**Architecture:** 진행 상태는 기존 `IngameControlOnboarding`, `SessionRoot`, `PurifyOnboardingSpotlight`, `ParryOnboarding`, `NightIntroCutscene`이 계속 소유한다. 새 `OnboardingVisualTokens`와 `OnboardingCoachMark`는 색·형태·배치·모션만 제공하고 성공 signal, room gate, 저장 flag, tree pause를 변경하지 않는다.

**Tech Stack:** Godot `4.6.3.stable.official.7d41c59c4`, GDScript, non-.NET runtime, project unit/integration runners, release Web export, gstack headed Chromium WebGL2.

**Spec:** `docs/superpowers/specs/2026-08-22-onboarding-coachmark-redesign.md`

## Global Constraints

- 기준 viewport는 `960×540`, minimum safe area는 left/right `60px`, top `24px`, bottom `34px`다.
- touch comfort zone은 left/right `72px`, bottom `58px`다.
- 비모달 onboarding surface 합집합은 viewport의 `25%`를 넘지 않는다.
- 일반 coach label은 최대 `340×72px`, objective ribbon은 최대 `320×48px`다.
- 등장 `180ms`, bracket `220ms`, 성공 `200ms`, dismiss `140ms`; 무한 pulse를 사용하지 않는다.
- reduced motion ON에서는 onboarding tween duration이 `0`이다.
- PC 입력 계약은 `LMB=공격`, `SPACE=대시`, `E=말 걸기`; touch에는 PC key를 노출하지 않는다.
- 기존 성공 판정, gate, skip, `parry_tutorial_complete`, onboarding journey phase는 유지한다.
- 모든 비모달 onboarding Control은 `mouse_filter=IGNORE`다.
- 코드·테스트는 issue #513 전용 worktree에서만 수정한다.
- quick gate: `PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh`.
- full gate: `PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh`.

---

### Task 1: Visual Tokens, Coachmark, and Reduced Motion

**Files:**
- Create: `scripts/ui/onboarding_visual_tokens.gd`
- Create: `scripts/ui/onboarding_coach_mark.gd`
- Modify: `scripts/autoload/settings.gd`
- Modify: `scripts/ui/settings_ui.gd`
- Modify: `scenes/ui/settings_ui.tscn`
- Test: `tests/unit/test_onboarding_coach_mark.gd`
- Test: `tests/unit/test_settings.gd`
- Test: `tests/unit/test_settings_ui.gd`

**Interfaces:**
- Produces: `OnboardingVisualTokens.coach_style(tone: StringName) -> StyleBoxFlat`.
- Produces: `OnboardingVisualTokens.tone_color(tone: StringName) -> Color`.
- Produces: `OnboardingVisualTokens.motion_duration(kind: StringName, reduced_motion: bool) -> float`.
- Produces: `OnboardingCoachMark.configure(camera: Camera2D, reduced_motion: bool = false) -> void`.
- Produces: `OnboardingCoachMark.show_prompt(model: Dictionary) -> void`.
- Produces: `OnboardingCoachMark.complete() -> void`, `dismiss(immediate: bool = false) -> void`, `get_snapshot() -> Dictionary`.
- Produces: `Settings.KEY_REDUCED_MOTION := "reduced_motion"`, `is_reduced_motion_enabled() -> bool`, `set_reduced_motion_enabled(enabled: bool) -> void`.

- [ ] **Step 1: Write token and coachmark RED tests**

Create `tests/unit/test_onboarding_coach_mark.gd` with concrete assertions:

```gdscript
extends Node

const TOKENS_PATH := "res://scripts/ui/onboarding_visual_tokens.gd"
const COACH_PATH := "res://scripts/ui/onboarding_coach_mark.gd"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node

func _set_runner(runner: Node) -> void:
	_runner = runner

func test_tokens_fix_palette_sizes_and_motion() -> void:
	_runner.assert_true(ResourceLoader.exists(TOKENS_PATH), "tokens exist")
	if not ResourceLoader.exists(TOKENS_PATH):
		return
	var tokens := load(TOKENS_PATH)
	_runner.assert_eq(tokens.MAX_LABEL_SIZE, Vector2(340.0, 72.0))
	_runner.assert_eq(tokens.MAX_RIBBON_SIZE, Vector2(320.0, 48.0))
	_runner.assert_eq(tokens.tone_color(&"timing"), Color(0.38, 0.94, 0.89, 1.0))
	_runner.assert_eq(tokens.motion_duration(&"enter", false), 0.18)
	_runner.assert_eq(tokens.motion_duration(&"enter", true), 0.0)

func test_world_target_prompt_is_compact_safe_and_non_blocking() -> void:
	var coach := _new_coach()
	if coach == null:
		return
	var target := Node2D.new()
	target.name = "Wolf"
	add_child(target)
	coach.call("show_prompt", {
		"id": &"parry", "tone": &"timing", "action": "받아치기",
		"key_label": "LMB", "detail": "늑대가 달려들 때",
		"target_kind": &"world", "target": target, "placement": &"auto",
		"persistent": true,
	})
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_eq(snapshot.get("action"), "받아치기")
	_runner.assert_eq(snapshot.get("key_label"), "LMB")
	_runner.assert_true(MobileSafeArea.meets_landscape_minimum(snapshot.get("label_rect", Rect2())))
	_runner.assert_true(float(snapshot.get("screen_coverage", 1.0)) <= 0.25)
	_runner.assert_eq(snapshot.get("mouse_filter"), Control.MOUSE_FILTER_IGNORE)

func test_stale_completion_tween_cannot_dismiss_next_prompt() -> void:
	var coach := _new_coach()
	if coach == null:
		return
	coach.call("show_prompt", {"id": &"first", "action": "이동", "target_kind": &"none"})
	coach.call("complete")
	coach.call("show_prompt", {"id": &"second", "action": "공격", "target_kind": &"none"})
	coach.call("finish_motion_for_tests", &"first")
	_runner.assert_eq(coach.call("get_snapshot").get("id"), &"second")
	_runner.assert_true(bool(coach.call("get_snapshot").get("active")))

func _new_coach() -> Node:
	_runner.assert_true(ResourceLoader.exists(COACH_PATH), "coachmark script exists")
	if not ResourceLoader.exists(COACH_PATH):
		return null
	var coach := (load(COACH_PATH) as Script).new() as Node
	add_child(coach)
	return coach
```

- [ ] **Step 2: Extend Settings RED tests**

Add to `tests/unit/test_settings.gd`:

```gdscript
func test_reduced_motion_defaults_off_and_emits_changes() -> void:
	Settings.reset_defaults()
	_runner.assert_false(Settings.is_reduced_motion_enabled())
	var snapshots: Array[Dictionary] = []
	EventBus.settings_changed.connect(func(payload: Dictionary) -> void: snapshots.append(payload))
	Settings.set_reduced_motion_enabled(true)
	_runner.assert_true(Settings.is_reduced_motion_enabled())
	_runner.assert_true(bool(snapshots[-1].get(Settings.KEY_REDUCED_MOTION)))
```

Add `TEST_ID_REDUCED_MOTION_TOGGLE` and `ACTION_REDUCED_MOTION_TOGGLE` expectations to `tests/unit/test_settings_ui.gd`. Assert the visible label is `온보딩 모션 줄이기`, default text is `OFF`, one UAT press changes the setting to `true`, and the rendered state becomes `ON`. Assert `$Root/Panel.get_global_rect()` meets `MobileSafeArea.meets_landscape_minimum()` after four rows render.

- [ ] **Step 3: Run unit tests and confirm RED**

Run:

```bash
GODOT_BIN=/opt/homebrew/bin/godot bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: failures for missing token/coach scripts and missing reduced-motion key/UI action.

- [ ] **Step 4: Implement `OnboardingVisualTokens`**

Create the constants and helpers exactly:

```gdscript
class_name OnboardingVisualTokens
extends RefCounted

const MAX_LABEL_SIZE := Vector2(340.0, 72.0)
const MAX_RIBBON_SIZE := Vector2(320.0, 48.0)
const INK_SURFACE := Color(0.025, 0.04, 0.055, 0.74)
const INK_SURFACE_STRONG := Color(0.025, 0.04, 0.055, 0.88)
const PAPER_TEXT := Color(0.96, 0.91, 0.80, 1.0)
const GOLD_INFO := Color(0.93, 0.70, 0.25, 1.0)
const CYAN_TIMING := Color(0.38, 0.94, 0.89, 1.0)
const VERMILION_DANGER := Color(0.91, 0.29, 0.23, 1.0)

static func tone_color(tone: StringName) -> Color:
	match tone:
		&"timing": return CYAN_TIMING
		&"danger": return VERMILION_DANGER
	return GOLD_INFO

static func motion_duration(kind: StringName, reduced_motion: bool) -> float:
	if reduced_motion:
		return 0.0
	match kind:
		&"enter": return 0.18
		&"bracket": return 0.22
		&"complete": return 0.20
		&"dismiss": return 0.14
	return 0.0
```

`coach_style()` returns radius `4`, border width `1`, `INK_SURFACE`, and the tone color.

- [ ] **Step 5: Implement `OnboardingCoachMark`**

Build one root `Control`, a compact `PanelContainer`, key chip, action/detail labels, and four `ColorRect` corner brackets. Keep every child `MOUSE_FILTER_IGNORE`. Use `MobileSafeArea`, a world-to-screen helper, control target rects, opposite-side placement fallback, and a ribbon fallback.

Use a generation guard:

```gdscript
func show_prompt(model: Dictionary) -> void:
	_generation += 1
	_kill_motion()
	_model = model.duplicate(true)
	_active = true
	visible = true
	_refresh_layout()
	_play_enter(_generation)

func complete() -> void:
	if not _active:
		return
	var generation := _generation
	_play_exit(&"complete", generation)

func _finish_exit(generation: int) -> void:
	if generation != _generation:
		return
	_active = false
	visible = false
```

Expose `finish_motion_for_tests(prompt_id)` so tests can fire a stale callback deterministically without waiting for a Tween.

- [ ] **Step 6: Implement reduced-motion Settings and UI**

Add the fourth boolean to defaults and wrappers:

```gdscript
const KEY_REDUCED_MOTION := "reduced_motion"

func is_reduced_motion_enabled() -> bool:
	return bool(get_value(KEY_REDUCED_MOTION, false))

func set_reduced_motion_enabled(enabled: bool) -> void:
	set_value(KEY_REDUCED_MOTION, enabled)
```

Add the fourth settings row with stable `test_id` and `uat_action`, using direct semantics: `ON` means reduced motion enabled.

Increase `scenes/ui/settings_ui.tscn` panel height from `348px` to `440px` (`offset_top=-220`, `offset_bottom=220`). At the 960×540 reference this leaves `50px` above and below, satisfying the `24px/34px` safe-area minimum while fitting four `58px` rows, three `10px` row gaps, title, close action, stack gaps, and margins.

- [ ] **Step 7: Run unit and quick gates**

Run the unit runner, then the global quick gate. Expected: all prior tests plus the new coach/settings tests pass; import metadata includes both new `.gd.uid` files.

- [ ] **Step 8: Commit Task 1**

```bash
git add scripts/ui/onboarding_visual_tokens.gd scripts/ui/onboarding_visual_tokens.gd.uid scripts/ui/onboarding_coach_mark.gd scripts/ui/onboarding_coach_mark.gd.uid scripts/autoload/settings.gd scripts/ui/settings_ui.gd scenes/ui/settings_ui.tscn tests/unit/test_onboarding_coach_mark.gd tests/unit/test_onboarding_coach_mark.gd.uid tests/unit/test_settings.gd tests/unit/test_settings_ui.gd
git commit -m "[UI] 온보딩 코치마크 기반 추가"
```

---

### Task 2: First-Control Coachmarks

**Files:**
- Modify: `scripts/ui/ingame_control_onboarding.gd`
- Test: `tests/unit/test_touch_input.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Consumes: Task 1 `OnboardingCoachMark` and `OnboardingVisualTokens`.
- Preserves: `completed`, `skipped`, `gate_released`, `record_action()`, `record_player_position()`, `record_room_changed()`.
- Produces: `get_current_step_snapshot()` fields `action`, `key_label`, `detail`, `coach_rect`, `screen_coverage`, `reduced_motion` while retaining `step_id`, `active`, target names, gate/skip state.

- [ ] **Step 1: Replace old visual-contract expectations with RED coachmark expectations**

Update `tests/unit/test_touch_input.gd` so it asserts this matrix:

```gdscript
var desktop_expected := {
	&"move": ["WASD", "이동"],
	&"attack": ["LMB", "공격"],
	&"dash": ["SPACE", "회피"],
	&"power_attack": ["SPACE → LMB", "강공격"],
	&"minimap": ["미니맵 클릭", "지도 펼치기"],
	&"exit": ["", "열린 문 통과"],
}
```

Touch expectations use `스틱`, `공격 버튼`, `대시 버튼`, `대시 → 공격`, `미니맵 탭`, and no desktop key. Replace the centered-desktop-card assertion with:

```gdscript
_runner.assert_false(bool(contract.get("uses_fullscreen_dim")), "control coachmarks do not dim the playfield")
_runner.assert_true(float(snapshot.get("screen_coverage")) <= 0.25)
_runner.assert_true(MobileSafeArea.meets_landscape_minimum(snapshot.get("coach_rect")))
```

Keep every existing success-signal, skip, gate, modal-hide, and step-order test.

- [ ] **Step 2: Run unit and integration runners and confirm RED**

Expected failures: old `title/body` card model, `DIM_ALPHA`, centered label rect, and missing coach fields.

- [ ] **Step 3: Delegate rendering to `OnboardingCoachMark`**

Replace `TOUCH_STEPS` and `DESKTOP_STEPS` visual fields with `key_label`, `action`, `detail`, and target names. Instantiate/configure one coach in `_build_ui()` and feed it from `_refresh_step()`:

```gdscript
func _coach_model_for_current_step() -> Dictionary:
	var step := _current_step()
	return {
		"id": step.get("id", &""),
		"tone": &"info",
		"key_label": String(step.get("key_label", "")),
		"action": String(step.get("action", "")),
		"detail": String(step.get("detail", "")),
		"target_kind": &"control" if not _current_target_names().is_empty() else &"world",
		"target": _current_target_control_or_player(),
		"placement": &"auto",
		"persistent": true,
	}
```

On `_advance_step()`, call `complete()` before presenting the next model. Do not let its Tween advance the state machine. Keep the skip button and compact legend, but restyle them with Task 1 tokens and remove the four old dim rects, rounded spotlight, and large label panel.

- [ ] **Step 4: Preserve modal and reduced-motion behavior**

When touch controls temporarily hide behind reward/dialogue, use the latched guidance mode and the original target reference. Read `Settings.is_reduced_motion_enabled()` on each step transition so an in-session setting change affects the next prompt.

- [ ] **Step 5: Run targeted and quick gates**

Run unit and integration runners. Confirm 6-stage order, skip, actual room exit gate, PC/mob copy, safe area, and pointer pass-through all pass. Then run quick.

- [ ] **Step 6: Commit Task 2**

```bash
git add scripts/ui/ingame_control_onboarding.gd tests/unit/test_touch_input.gd tests/integration/test_session_contract.gd
git commit -m "[UI] 첫 조작 안내를 코치마크로 교체"
```

---

### Task 3: Contextual Objective and Reward Surfaces

**Files:**
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/ui/session_ui_root.gd`
- Test: `tests/unit/test_session_summary_ui.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Consumes: `OnboardingVisualTokens`.
- Preserves: night journey snapshot `phase`, `completed_phases`, `current_instruction`, `input_mode`.
- Produces: `get_onboarding_journey_hint_snapshot()` fields `variant=&"objective_ribbon"`, `action`, `detail`, `screen_coverage`.
- Produces: reward snapshot fields `onboarding_eyebrow_visible`, `onboarding_eyebrow_text="첫 강화 · 1장 선택"`.

- [ ] **Step 1: Write contextual/reward RED assertions**

In the existing night-journey integration test, keep the semantic `current_instruction` assertions and replace visual body assertions with:

```gdscript
_runner.assert_eq(hint_snapshot.get("variant"), &"objective_ribbon")
_runner.assert_eq(hint_snapshot.get("action"), "길 열기")
_runner.assert_eq(hint_snapshot.get("detail"), "적 처치")
_runner.assert_true(float(hint_snapshot.get("screen_coverage")) <= 0.25)
```

Friend approach expects `action="정화"`, `detail="기절 → 접근"`. Reward tests expect no separate hint card and the eyebrow text above the existing card choices.

- [ ] **Step 2: Run unit/integration and confirm RED**

Expected: snapshot lacks `variant`, `action`, `detail`, coverage, and reward eyebrow fields.

- [ ] **Step 3: Implement compact objective ribbon**

Keep `set_onboarding_journey_hint(title, body, enabled)` for call-site stability but map known journey titles to compact fields:

```gdscript
func _journey_visual_copy(title: String) -> Dictionary:
	match title:
		"첫 전투": return {"detail": "적 처치", "action": "길 열기"}
		"친구 조우": return {"detail": "기절 → 접근", "action": "정화"}
	return {"detail": "", "action": title}
```

Resize/reposition the panel to `MAX_RIBBON_SIZE`, remove the large title/body stack, use a small detail label and strong action label, apply radius `4`, and keep the ribbon inside the top safe area without covering health/minimap.

- [ ] **Step 4: Replace reward explanation card with eyebrow**

Keep reward choice pause and card selection behavior. Replace the separate onboarding panel with one non-interactive eyebrow label inside the reward title area. `set_reward_choice_onboarding_hint(true)` sets `첫 강화 · 1장 선택`; false hides it.

- [ ] **Step 5: Run targeted, quick, and visual rect tests**

Confirm mutual exclusion with dialogue/purify/reward still passes, and neither ribbon nor eyebrow captures input.

- [ ] **Step 6: Commit Task 3**

```bash
git add scripts/session/session_root.gd scripts/ui/session_ui_root.gd tests/unit/test_session_summary_ui.gd tests/integration/test_session_contract.gd
git commit -m "[UI] 첫 런 목표와 보상 안내 간결화"
```

---

### Task 4: Purify, Parry, and Intro Surfaces

**Files:**
- Modify: `scripts/ui/purify_onboarding_spotlight.gd`
- Modify: `scripts/ui/parry_onboarding.gd`
- Modify: `scripts/cutscene/night_intro_cutscene.gd`
- Test: `tests/unit/test_purify_onboarding_spotlight.gd`
- Test: `tests/unit/test_night_intro_cutscene.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Consumes: Task 1 tokens/coach and `Settings.is_reduced_motion_enabled()`.
- Preserves: `PurifyOnboardingSpotlight.show_step()`, `dismiss()`, activation-frame guard, target projection.
- Preserves: `ParryOnboarding.show_for_wolf()`, `dismiss()`, `dismiss_for_wolf()`, bounded lifetime.
- Preserves: Night intro bounded line scheduling and `_continue_hint()` platform policy.
- Produces: compact snapshots with `key_label`, `action`, `detail`, `bracket_style=&"corners"`, `reduced_motion`.

- [ ] **Step 1: Write purify RED tests**

Replace the old `DIM_ALPHA=0.66` and rounded frame expectations:

```gdscript
var contract: Dictionary = spotlight.get_visual_contract()
_runner.assert_true(float(contract.get("dim_alpha")) <= 0.28)
_runner.assert_eq(contract.get("bracket_style"), &"corners")
_runner.assert_eq(contract.get("intro_action"), "기절시키기")
_runner.assert_eq(contract.get("intro_detail"), "공격 · 가까이 가면 정화 시작")
_runner.assert_eq(contract.get("groggy_action"), "곁을 지켜 정화")
_runner.assert_eq(contract.get("continue_placement"), &"bottom_right_chip")
```

Retain tap/click pointer-source and activation-frame tests.

- [ ] **Step 2: Write parry and intro RED tests**

Parry surface expects PC `key_label="LMB"`, touch `key_label="공격 버튼"`, `action="받아치기"`, `detail="늑대가 달려들 때"`, no dim, label max `340×72`, cyan corner brackets, and screen coverage <=25%.

Night intro test expects the continue control rect in the bottom-right safe area, PC `LMB  계속`, touch `탭  계속`, alpha `0.78`, and no change to blocked/stuck auto-finish bounds.

- [ ] **Step 3: Run unit/integration and confirm RED**

Expected: old panel sizes/messages, old rounded frames, missing key/action/detail fields, and old intro hint layout.

- [ ] **Step 4: Restyle purify without changing flow**

Use four corner bracket controls and a compact strong-surface label. Keep root input blocking only because the existing intro/groggy flow requires explicit dismissal. Fade the dim from `0.28` after `0.45s`, but never auto-dismiss or advance the purification state. Put the continue chip at right `60px`, bottom `58px`.

- [ ] **Step 5: Rebuild parry as a thin coachmark wrapper**

Keep its public lifecycle and target-death behavior, but delegate rendering to `OnboardingCoachMark`:

```gdscript
func show_for_wolf(wolf: Node2D, input_mode: StringName) -> void:
	_wolf = wolf
	_coach.configure(_camera, Settings.is_reduced_motion_enabled())
	_coach.show_prompt({
		"id": &"parry", "tone": &"timing",
		"key_label": "공격 버튼" if input_mode == &"touch" else "LMB",
		"action": "받아치기", "detail": "늑대가 달려들 때",
		"target_kind": &"world", "target": wolf,
		"placement": &"auto", "persistent": false,
	})
```

Continue to auto-dismiss at `3.2s`; completion flag ownership remains in `SessionRoot`.

- [ ] **Step 6: Move intro continue chip**

Build the hint as a compact key/action pair at bottom-right, using `InputPromptPolicy` for platform copy and tokens for style. Do not alter narration timing, automatic fallback, skip button, plate alpha, or transition SFX.

- [ ] **Step 7: Run unit, integration, quick, and full gates**

Confirm every prior Task 1–4 functional regression remains green, then run quick and full.

- [ ] **Step 8: Commit Task 4**

```bash
git add scripts/ui/purify_onboarding_spotlight.gd scripts/ui/parry_onboarding.gd scripts/cutscene/night_intro_cutscene.gd tests/unit/test_purify_onboarding_spotlight.gd tests/unit/test_night_intro_cutscene.gd tests/integration/test_session_contract.gd
git commit -m "[UI] 정화 패링 인트로 안내 통일"
```

---

### Task 5: Release Web UAT, Coverage Ledger, and Merge

**Files:**
- Create: `tests/uat/onboarding_coachmark_web_fixture.gd`
- Create: `tests/uat/onboarding_coachmark_web_fixture.tscn`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Produces deterministic query modes: `controls_pc`, `controls_touch`, `objective`, `reward`, `purify_intro`, `purify_groggy`, `parry_pc`, `parry_touch`, `intro_pc`, `intro_touch`, `reduced_motion`.
- Produces markers: `UAT_COACHMARK_READY mode=<mode> surface=<surface> reduced_motion=<bool>`.

- [ ] **Step 1: Add deterministic release Web fixture**

Use actual production scenes and existing in-process actions. The fixture may set flags/config and call public test/UAT helpers, but production scenes must not reference it. Each mode waits two frames, validates its snapshot, and prints one marker only after the expected surface is active.

The fixture must include a guard:

```gdscript
func _emit_ready(surface: Node, expected_action: String) -> void:
	var snapshot: Dictionary = surface.call("get_snapshot")
	if not bool(snapshot.get("active")) or snapshot.get("action") != expected_action:
		push_error("UAT coachmark state mismatch")
		return
	print("UAT_COACHMARK_READY mode=%s surface=%s reduced_motion=%s" % [
		_mode, snapshot.get("id", &""), snapshot.get("reduced_motion", false)
	])
```

- [ ] **Step 2: Run final local gates**

Run `git diff --check`, quick, and full after staging all new UID/import metadata. Expected final counts must be copied from actual output into the PR body rather than predicted here.

- [ ] **Step 3: Export release Web fixture and run headed WebGL2 UAT**

Temporarily point `project.godot` main scene to the fixture using `apply_patch`, export the normal `Web` release preset to `build/web/coachmark-fixture/index.html`, and restore `project.godot` with `apply_patch` before any commit.

For every query mode:

- assert WebGL2 is available;
- assert the exact `UAT_COACHMARK_READY` marker;
- collect console errors, page errors, failed requests, and 4xx/5xx responses;
- capture PC/mobile 960×540 screenshots;
- capture reduced motion ON/OFF states;
- confirm `project.godot` has no diff afterward.

- [ ] **Step 4: Run independent Challenger**

Request review of the complete staged diff with special focus on screen coverage, modal precedence, input pass-through, platform copy, reduced motion, stale tween generation, and preservation of every success/gate/flag contract. Resolve all Critical/Important findings and rerun affected tests.

- [ ] **Step 5: Update documentation and commit**

Update the coverage ledger with #513, before/after score, actual test counts, UAT modes, and Task 4 merge `76301ed`. Commit:

```bash
git add tests/uat/onboarding_coachmark_web_fixture.gd tests/uat/onboarding_coachmark_web_fixture.gd.uid tests/uat/onboarding_coachmark_web_fixture.tscn tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[Docs] 온보딩 코치마크 검증 근거 추가"
```

- [ ] **Step 6: Push, open ready PR, and publish UI captures**

Push `feat/issue-513-onboarding-coachmark`. Create a ready Korean PR titled `[UI] 온보딩 코치마크 시각 언어 재설계`, with assignee, milestone, `P0`, `area:ui`, `area:player`, `Closes #513`, Web Preview artifact/URL, and before/after raw images under `ui-previews/pr-<PR>/`.

- [ ] **Step 7: Codex review and merge loop**

Comment `@codex review`. For every inline finding, verify technically, patch in the same worktree, reply with the change/rationale, resolve the thread, rerun gates, and re-request review. Merge with:

```bash
gh pr merge <PR_NUMBER> --repo 0xkkun/seoul-challenge --merge --delete-branch
```

only after current-head UI capture, Quick, Rooms, Web Preview are green and Codex has no outstanding changes.

- [ ] **Step 8: Resume Task 5**

Fetch the coachmark merge into a fresh issue-specific worktree for the already-open #512 contract. Do not copy files between worktrees. Re-run the hit-stop RED from #512 against the new main before continuing the approved program.
