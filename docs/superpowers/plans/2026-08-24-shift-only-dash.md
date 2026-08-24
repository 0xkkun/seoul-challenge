# Shift-Only Dash Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PC 키보드 대시를 Shift 하나로 제한하고 첫 조작 안내·강공격 순서를 실제 입력과 일치시킨다.

**Architecture:** `Player.resolve_special_input()`에서 플랫폼 독립 touch/gamepad와 PC Shift를 명시적으로 합성하고 Space 경로를 제거한다. `IngameControlOnboarding`은 #546의 `InputPromptStrip` action ids를 그대로 사용하므로 copy와 판정이 분리되지 않는다.

**Tech Stack:** Godot 4.6.3, GDScript, custom unit/integration runner, headed Chromium WebGL2

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- GitHub issue `#547`, branch `fix/issue-547-shift-only-dash`, worktree `../seoul-challenge-547`를 #546 merge 이후 최신 `origin/main`에서 생성한다.
- PC keyboard는 Shift만 대시를 시작한다. touch skill button과 gamepad left trigger는 유지한다.
- Space는 전투 action을 시작하지 않는다.
- Shift→좌클릭 강공격 grace window, charge consumption, signals를 유지한다.
- #546의 `InputPromptStrip`과 action id `dash`, `attack`을 재사용한다.
- PR은 ready, assignee, milestone, `P1`, `area:player`, `area:ui`, inline UI capture를 갖는다.

---

### Task 1: 입력 판정을 RED→GREEN으로 전환

**Files:**
- Modify: `tests/unit/test_player_aim_fire.gd:75-125`
- Modify: `scripts/player/player.gd:630-740`

**Interfaces:**
- Consumes: touch pressed, Shift pressed, gamepad left trigger
- Produces: `resolve_special_input(touch_skill_pressed: bool, shift_pressed: bool, left_trigger_value: float) -> bool`

- [ ] **Step 1: Shift-only truth table 실패 테스트 작성**

```gdscript
func test_shift_is_the_only_pc_keyboard_dash_input() -> void:
	_runner.assert_true(PlayerScript.resolve_special_input(false, true, 0.0), "Shift starts PC dash")
	_runner.assert_false(PlayerScript.resolve_special_input(false, false, 0.0), "no input stays idle")
	var source := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	var start := source.find("func is_special_pressed")
	var finish := source.find("func resolve_special_input", start)
	var runtime_block := source.substr(start, finish - start)
	_runner.assert_false(runtime_block.contains("KEY_SPACE"), "Space is absent from runtime dash input")


func test_touch_and_gamepad_dash_inputs_remain_supported() -> void:
	_runner.assert_true(PlayerScript.resolve_special_input(true, false, 0.0), "touch skill starts dash")
	_runner.assert_true(PlayerScript.resolve_special_input(false, false, 0.31), "left trigger starts dash")
	_runner.assert_false(PlayerScript.resolve_special_input(false, false, 0.30), "trigger threshold stays strict")
```

- [ ] **Step 2: unit runner에서 기존 5-argument signature/Space path가 FAIL인지 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: signature mismatch 또는 Space rejection test FAIL.

- [ ] **Step 3: runtime 입력과 pure resolver 최소 변경**

```gdscript
func is_special_pressed() -> bool:
	var touch_skill_pressed := (
		_touch != null
		and _touch.has_method("is_skill_pressed")
		and bool(_touch.call("is_skill_pressed"))
	)
	return resolve_special_input(
		touch_skill_pressed,
		Input.is_physical_key_pressed(KEY_SHIFT),
		Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	)


static func resolve_special_input(touch_skill_pressed: bool, shift_pressed: bool, left_trigger_value: float) -> bool:
	return touch_skill_pressed or shift_pressed or left_trigger_value > 0.3
```

기존 `_interact_pressed` 인자는 사용되지 않으므로 제거한다. E 상호작용은 day corridor 경로에 남고 Player dash resolver에 넣지 않는다.

- [ ] **Step 4: unit runner PASS 확인**

Run: Step 2와 동일.

Expected: 모든 unit 0 failed.

- [ ] **Step 5: Shift-only 입력 커밋**

```bash
git add scripts/player/player.gd tests/unit/test_player_aim_fire.gd
git commit -m "[Player] PC 대시 입력을 Shift로 단일화"
```

### Task 2: 첫 조작 안내와 실제 성공 순서 정렬

**Files:**
- Modify: `tests/unit/test_touch_input.gd`
- Modify: `tests/integration/test_session_contract.gd`
- Modify: `scripts/ui/ingame_control_onboarding.gd:70-115`

**Interfaces:**
- Consumes: `dash_started`, `power_attack_executed`, `input_actions=[&"dash"]`
- Produces: PC onboarding snapshot의 Shift keycap과 Shift→attack sequence

- [ ] **Step 1: onboarding snapshot과 성공 event 실패 테스트 작성**

```gdscript
func test_ingame_control_onboarding_desktop_actions_match_pc_control_scheme() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var player := StubIntegratedInputPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)
	onboarding.call("configure", null, null, player)
	onboarding.call("start")
	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	onboarding.call("record_action", &"attack_executed")
	var dash_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(dash_snapshot["input_actions"], [&"dash"])
	_runner.assert_eq(dash_snapshot["input_keycaps"], ["SHIFT"])
	_runner.assert_false(String(dash_snapshot).contains("SPACE"))
	onboarding.call("record_action", &"dash_started")
	var power_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(power_snapshot["input_actions"], [&"dash", &"attack"])
	player.queue_free()
	onboarding.queue_free()
```

Integration에는 real Player의 `dash_started` 뒤 `power_attack_executed`가 한 번씩 발생하고 Space-only synthetic state가 두 signal을 발생시키지 않는 단정을 추가한다.

- [ ] **Step 2: unit/integration runner에서 기존 SPACE copy가 FAIL인지 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
```

Expected: old desktop step model 또는 Space path 때문에 새 단정 FAIL.

- [ ] **Step 3: desktop step model과 compact legend copy 갱신**

```gdscript
{
	"id": &"dash",
	"input_actions": [&"dash"],
	"action": "회피",
	"detail": "공격을 피해",
},
{
	"id": &"power_attack",
	"input_actions": [&"dash", &"attack"],
	"action": "강하게 타격",
	"detail": "회피 직후 타격",
},
```

mobile step models와 target names는 수정하지 않는다.

- [ ] **Step 4: unit/integration/quick PASS 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
```

Expected: 0 failed, UI automation contract PASS.

- [ ] **Step 5: 안내 정렬 커밋**

```bash
git add scripts/ui/ingame_control_onboarding.gd tests/unit/test_touch_input.gd tests/integration/test_session_contract.gd
git commit -m "[UI] 첫 조작 대시 안내를 Shift 기준으로 정렬"
```

### Task 3: 실제 Web 입력 UAT와 merge

**Files:**
- Modify: `tests/uat/onboarding_coachmark_web_fixture.gd`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Consumes: production Player keyboard events and onboarding snapshots
- Produces: `UAT_SHIFT_DASH_READY` marker와 PC capture

- [ ] **Step 1: production-like fixture mode와 marker 추가**

`uat_coachmark_mode=shift_dash_input`는 real Player와 IngameControlOnboarding을 마운트한다. fixture는 실제 browser key event를 기다리고 다음 snapshot을 기록한다.

```gdscript
print("UAT_SHIFT_DASH_READY space_dash=%s shift_dash=%s power_attack=%s dash_count=%d power_count=%d valid=%s" % [
	str(_space_started_dash).to_lower(),
	str(_shift_started_dash).to_lower(),
	str(_shift_attack_started_power).to_lower(),
	_dash_count,
	_power_count,
	str(valid).to_lower(),
])
```

- [ ] **Step 2: full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

- [ ] **Step 3: headed Chromium에서 실제 key sequence 검증**

1. canvas focus 후 Space keydown/up → `space_dash=false`.
2. Shift keydown/up → `shift_dash=true`, `dash_count=1`.
3. recharge 후 Shift, grace 안에 실제 left mouse press → `power_attack=true`, `power_count=1`.

Expected: marker `valid=true`, console/page/request error 0.

- [ ] **Step 4: 960×540 Shift keycap·강공격 안내 캡처**

```text
shift-dash-coachmark-960x540.png
shift-attack-sequence-960x540.png
```

- [ ] **Step 5: UAT evidence 커밋**

```bash
git add tests/uat/onboarding_coachmark_web_fixture.gd tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] Shift 전용 대시 Web 증거 추가"
```

- [ ] **Step 6: ready PR과 merge loop 완료**

PR title: `[Player] PC 대시를 Shift 전용으로 전환`

PR body에 exact test counts, Space/Shift/강공격 marker, inline screenshots, `Closes #547`를 넣는다. current-head Codex와 CI가 green이고 unresolved 0이면 즉시 merge한다.
