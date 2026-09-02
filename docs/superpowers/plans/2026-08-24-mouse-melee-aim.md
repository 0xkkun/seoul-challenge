# Mouse Melee Aim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PC 사용자가 우클릭을 누른 채 이동하면서 사거리·부채꼴을 확인하고 좌클릭으로 커서 방향 근접 공격을 실행한다.

**Architecture:** `Player`가 입력과 순수 조준 수학을 소유하고 `MeleeAimIndicator`는 계산된 origin/target/reach/arc만 그린다. 판정 수학과 시각 노드를 분리해 indicator가 공격 범위를 바꾸지 못하게 한다.

**Tech Stack:** Godot 4.6.3, GDScript, CanvasItem immediate drawing, custom unit/integration runner, headed Chromium WebGL2

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- GitHub issue `#548`, branch `feat/issue-548-mouse-melee-aim`, worktree `../seoul-challenge-548`를 #546 merge 이후 최신 `origin/main`에서 생성한다.
- RMB hold는 이동을 막거나 느리게 하지 않는다. RMB release는 공격을 만들지 않는다.
- LMB 단독은 기존 facing 공격을 유지하고 RMB+LMB만 cursor direction을 사용한다.
- target ring과 arc는 `current_melee_reach()`·`current_melee_arc()`의 실제 다음 공격 수치를 사용한다.
- UI hover, pause, modal, death, retry, finish, scene exit에서 indicator를 숨긴다.
- mobile/touch aim이 PC mouse aim보다 우선하며 mobile feature에서는 indicator를 만들지 않는다.
- PR은 ready, assignee, milestone, `P1`, `area:player`, `area:combat`, `area:ui`, inline UI capture를 갖는다.

---

### Task 1: 조준 수학과 다음 공격 reach를 RED→GREEN으로 추가

**Files:**
- Modify: `tests/unit/test_player_aim_fire.gd`
- Modify: `tests/unit/test_player_melee.gd`
- Modify: `scripts/player/player.gd:285-390`
- Modify: `scripts/player/player.gd:1095-1145`

**Interfaces:**
- Consumes: origin, cursor world position, current weapon/power window, fallback facing
- Produces: `clamped_aim_target()`, `resolve_aim_direction()`, `current_melee_reach()`, `current_melee_arc()` using `swing_vertical_factor`

- [ ] **Step 1: clamp·fallback·power reach 실패 테스트 작성**

```gdscript
func test_clamped_aim_target_keeps_inside_cursor_and_clamps_far_cursor() -> void:
	_runner.assert_eq(
		PlayerScript.clamped_aim_target(Vector2.ZERO, Vector2(30.0, 30.0), 100.0, Vector2.RIGHT, 0.75),
		Vector2(30.0, 30.0),
	)
	_runner.assert_eq(
		PlayerScript.clamped_aim_target(Vector2.ZERO, Vector2(300.0, 0.0), 100.0, Vector2.RIGHT, 0.75),
		Vector2(100.0, 0.0),
	)
	_runner.assert_eq(
		PlayerScript.clamped_aim_target(Vector2.ZERO, Vector2(0.0, 400.0), 100.0, Vector2.DOWN, 0.75),
		Vector2(0.0, 75.0),
		"vertical reach uses the same 0.75 world compression as melee collision",
	)


func test_clamped_aim_target_uses_fallback_for_zero_or_invalid_input() -> void:
	_runner.assert_eq(
		PlayerScript.clamped_aim_target(Vector2.ZERO, Vector2.ZERO, 80.0, Vector2.LEFT, 0.75),
		Vector2.LEFT * 80.0,
	)
	_runner.assert_eq(
		PlayerScript.clamped_aim_target(Vector2.ZERO, Vector2(INF, 0.0), 80.0, Vector2.DOWN, 0.75),
		Vector2.DOWN * 60.0,
	)


func test_current_melee_reach_matches_next_attack_profile() -> void:
	var player := PlayerScript.new()
	add_child(player)
	player.call("equip_bat")
	_runner.assert_eq(player.call("current_melee_reach"), player.get("bat_range"))
	player.set("_dash_power_attack_timer", 0.1)
	_runner.assert_eq(
		player.call("current_melee_reach"),
		float(player.get("bat_range")) * float(player.get("dash_power_attack_range_multiplier")),
	)
```

- [ ] **Step 2: unit runner에서 method missing FAIL 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

- [ ] **Step 3: 순수 helper와 current profile 구현**

```gdscript
static func clamped_aim_target(origin: Vector2, cursor: Vector2, reach: float, fallback: Vector2, vertical_factor: float) -> Vector2:
	var safe_reach := reach if is_finite(reach) and reach > 0.0 else 0.0
	var safe_vertical := vertical_factor if is_finite(vertical_factor) and vertical_factor > 0.001 else 1.0
	var world_delta := cursor - origin
	var combat_delta := Vector2(world_delta.x, world_delta.y / safe_vertical)
	var has_cursor_direction := combat_delta.is_finite() and combat_delta.length() > 0.001
	var direction := combat_delta.normalized() if has_cursor_direction else fallback.normalized()
	if direction == Vector2.ZERO or not direction.is_finite():
		direction = Vector2.RIGHT
	if safe_reach <= 0.0:
		return origin
	var target_distance := minf(combat_delta.length(), safe_reach) if has_cursor_direction else safe_reach
	var combat_target := direction * target_distance
	return origin + Vector2(combat_target.x, combat_target.y * safe_vertical)


func current_melee_reach() -> float:
	var reach := bat_range if _has_bat else melee_range
	if not _dash_power_attack_consumed and is_dash_power_attack_window_active(_dodge_timer, _dash_power_attack_timer):
		reach *= dash_power_attack_range_multiplier
	return maxf(0.0, reach)


func current_melee_arc() -> float:
	return bat_arc if _has_bat else melee_arc
```

`Vector2.is_finite()`가 Godot 4.6 API에 없으면 `is_finite(v.x) and is_finite(v.y)`인 private helper `_is_finite_vector()`를 사용한다.

- [ ] **Step 4: unit runner PASS 확인**

Run: Step 2와 동일.

- [ ] **Step 5: 조준 수학 커밋**

```bash
git add scripts/player/player.gd tests/unit/test_player_aim_fire.gd tests/unit/test_player_melee.gd
git commit -m "[Player] 근접 조준점과 실제 사거리 계산 추가"
```

### Task 2: `MeleeAimIndicator` 시각 deep module 구현

**Files:**
- Create: `scripts/ui/melee_aim_indicator.gd`
- Create: `scripts/ui/melee_aim_indicator.gd.uid`
- Create: `tests/unit/test_melee_aim_indicator.gd`
- Modify: `scenes/player/player.tscn`

**Interfaces:**
- Consumes: `show_aim(origin: Vector2, target: Vector2, reach: float, arc: float, vertical_factor: float)`
- Produces: `hide_aim()`, `get_snapshot()`, non-interactive world drawing

- [ ] **Step 1: indicator geometry/cleanup 실패 테스트 작성**

```gdscript
const IndicatorScript := preload("res://scripts/ui/melee_aim_indicator.gd")


func test_indicator_snapshot_matches_real_attack_geometry() -> void:
	var indicator := IndicatorScript.new()
	add_child(indicator)
	_runner.assert_false(indicator.visible, "fresh indicator never draws a ring at player origin")
	indicator.show_aim(Vector2(100.0, 100.0), Vector2(160.0, 100.0), 90.0, 1.6, 0.75)
	var snapshot: Dictionary = indicator.get_snapshot()
	_runner.assert_true(snapshot["visible"])
	_runner.assert_eq(snapshot["origin"], Vector2(100.0, 100.0))
	_runner.assert_eq(snapshot["target"], Vector2(160.0, 100.0))
	_runner.assert_eq(snapshot["reach"], 90.0)
	_runner.assert_eq(snapshot["arc"], 1.6)
	_runner.assert_eq(snapshot["vertical_factor"], 0.75)
	_runner.assert_eq(snapshot["collision_enabled"], false)


func test_hide_clears_indicator_state() -> void:
	var indicator := IndicatorScript.new()
	add_child(indicator)
	indicator.show_aim(Vector2.ZERO, Vector2.RIGHT * 40.0, 40.0, 1.0, 0.75)
	indicator.hide_aim()
	_runner.assert_false(indicator.get_snapshot()["visible"])
```

- [ ] **Step 2: unit runner에서 preload FAIL 확인**

Run: Task 1 Step 2.

- [ ] **Step 3: immediate drawing indicator 구현**

```gdscript
class_name MeleeAimIndicator
extends Node2D

const OnboardingVisualTokens := preload("res://scripts/ui/onboarding_visual_tokens.gd")
const LINE_COLOR := Color(OnboardingVisualTokens.PAPER_TEXT, 0.72)
const ARC_COLOR := Color(OnboardingVisualTokens.GOLD_INFO, 0.16)
const ARC_EDGE_COLOR := Color(OnboardingVisualTokens.GOLD_INFO, 0.52)
const TARGET_COLOR := Color(OnboardingVisualTokens.GOLD_INFO, 0.92)

var _target_local := Vector2.ZERO
var _reach := 0.0
var _arc := 0.0
var _vertical_factor := 1.0


func _ready() -> void:
	visible = false


func show_aim(origin: Vector2, target: Vector2, reach: float, arc: float, vertical_factor: float) -> void:
	global_position = origin
	_target_local = target - origin
	_reach = maxf(0.0, reach)
	_arc = maxf(0.0, arc)
	_vertical_factor = maxf(0.001, vertical_factor)
	visible = _reach > 0.0 and _target_local.length() > 0.001
	queue_redraw()


func hide_aim() -> void:
	visible = false
	_target_local = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var combat_target := Vector2(_target_local.x, _target_local.y / _vertical_factor)
	var direction := combat_target.normalized()
	var angle := direction.angle()
	var sector := PackedVector2Array([Vector2.ZERO])
	var curve := PackedVector2Array()
	for index: int in range(25):
		var sample := lerpf(angle - _arc * 0.5, angle + _arc * 0.5, float(index) / 24.0)
		var combat_point := Vector2.from_angle(sample) * _reach
		var world_point := Vector2(combat_point.x, combat_point.y * _vertical_factor)
		sector.append(world_point)
		curve.append(world_point)
	draw_colored_polygon(sector, ARC_COLOR)
	draw_polyline(curve, ARC_EDGE_COLOR, 2.0)
	draw_line(Vector2.ZERO, _target_local, LINE_COLOR, 2.0)
	draw_arc(_target_local, 8.0, 0.0, TAU, 16, TARGET_COLOR, 2.0)
```

scene의 Player 자식 `%MeleeAimIndicator`로 추가하고 `visible=false`로 저장하며 collision node를 만들지 않는다. `_ready()`도 hidden을 강제해 code-created instance까지 보호한다. `z_index`는 actor 위, HUD 아래인 local combat layer로 둔다.

- [ ] **Step 4: unit runner와 required scene instantiate PASS 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
```

- [ ] **Step 5: indicator 커밋**

```bash
git add scripts/ui/melee_aim_indicator.gd scripts/ui/melee_aim_indicator.gd.uid scenes/player/player.tscn tests/unit/test_melee_aim_indicator.gd
git commit -m "[UI] 실제 근접 판정을 보여주는 조준 표시 추가"
```

### Task 3: RMB hold 상태와 공격 방향 연결

**Files:**
- Modify: `scripts/player/player.gd:145-205`
- Modify: `scripts/player/player.gd:598-690`
- Modify: `tests/unit/test_player_aim_fire.gd`
- Modify: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Consumes: desktop RMB state, global mouse position, UI hover, current reach/arc
- Produces: `is_mouse_aiming()`, `get_mouse_aim_snapshot()`, RMB+LMB attack direction

- [ ] **Step 1: aim priority·movement·cleanup 실패 테스트 작성**

```gdscript
func test_mouse_aim_direction_overrides_facing_only_while_active() -> void:
	_runner.assert_eq(
		PlayerScript.resolve_aim_direction(Vector2.ZERO, true, Vector2(10.0, 0.0), Vector2.LEFT, 0.75),
		Vector2.RIGHT,
	)
	_runner.assert_eq(
		PlayerScript.resolve_aim_direction(Vector2.ZERO, false, Vector2(10.0, 0.0), Vector2.LEFT, 0.75),
		Vector2.LEFT,
	)
	_runner.assert_true(
		PlayerScript.resolve_aim_direction(Vector2.ZERO, true, Vector2(30.0, 30.0), Vector2.LEFT, 0.75).is_equal_approx(Vector2(0.6, 0.8)),
		"mouse aim direction uses the same vertically scaled combat space as hit detection",
	)


func test_touch_aim_keeps_priority_over_mouse_aim() -> void:
	_runner.assert_eq(
		PlayerScript.resolve_aim_direction(Vector2.UP, true, Vector2.RIGHT, Vector2.LEFT, 0.75),
		Vector2.UP,
	)


func test_desktop_mouse_aim_is_not_blocked_by_mounted_touch_controls() -> void:
	_runner.assert_true(PlayerScript.mouse_aim_allowed(false, false, false), "desktop platform permits mouse aim")
	_runner.assert_false(PlayerScript.mouse_aim_allowed(true, false, false), "mobile platform keeps touch aim")
	_runner.assert_false(PlayerScript.mouse_aim_allowed(false, true, false), "interactive UI hover blocks aim")
	_runner.assert_false(PlayerScript.mouse_aim_allowed(false, false, true), "paused gameplay blocks aim")
```

Integration test는 real desktop session에 hidden `%TouchControls`가 실제로 존재하는 상태에서도 mouse aim policy가 허용되고, aim active 중 `read_input_vector()`가 변하지 않으며, `_show_death_summary()`와 `_exit_tree()` 뒤 indicator snapshot이 hidden인지 단정한다.

- [ ] **Step 2: unit/integration runner에서 mouse aim method missing FAIL 확인**

Run: Task 2 Step 4.

- [ ] **Step 3: desktop mouse aim update와 indicator 연결**

```gdscript
func _update_mouse_aim() -> void:
	var mobile_runtime := OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	if not mouse_aim_allowed(mobile_runtime, _is_pointer_over_interactive_ui(), get_tree().paused):
		_clear_mouse_aim()
		return
	var active := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not active:
		_clear_mouse_aim()
		return
	_mouse_aim_active = true
	_mouse_aim_target = clamped_aim_target(global_position, get_global_mouse_position(), current_melee_reach(), _facing, swing_vertical_factor)
	_melee_aim_indicator.show_aim(global_position, _mouse_aim_target, current_melee_reach(), current_melee_arc(), swing_vertical_factor)


func aim_direction() -> Vector2:
	var touch_aim := Vector2.ZERO
	if _touch != null and _touch.has_method("get_aim"):
		touch_aim = _touch.get_aim()
	return resolve_aim_direction(touch_aim, _mouse_aim_active, _mouse_aim_target - global_position, _facing, swing_vertical_factor)


static func mouse_aim_allowed(mobile_runtime: bool, pointer_over_ui: bool, paused: bool) -> bool:
	return not mobile_runtime and not pointer_over_ui and not paused


static func resolve_aim_direction(touch_aim: Vector2, mouse_active: bool, mouse_world_delta: Vector2, facing: Vector2, vertical_factor: float) -> Vector2:
	if touch_aim.length() > 0.01:
		return touch_aim.normalized()
	if mouse_active:
		var safe_vertical := maxf(0.001, vertical_factor)
		return Vector2(mouse_world_delta.x, mouse_world_delta.y / safe_vertical).normalized()
	return facing
```

`_physics_process()`는 movement read 후 attack 전에 `_update_mouse_aim()`을 호출한다. `reset_transient_state()`, session finish handler, tree exit에서도 `_clear_mouse_aim()`을 호출한다.

- [ ] **Step 4: unit/integration/quick PASS 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
```

- [ ] **Step 5: mouse aim 연결 커밋**

```bash
git add scripts/player/player.gd tests/unit/test_player_aim_fire.gd tests/integration/test_session_contract.gd
git commit -m "[Player] 우클릭 홀드 조준과 좌클릭 타격 연결"
```

### Task 4: Release Web 실제 입력 UAT와 merge

**Files:**
- Create: `tests/uat/mouse_melee_aim_web_fixture.gd`
- Create: `tests/uat/mouse_melee_aim_web_fixture.gd.uid`
- Create: `tests/uat/mouse_melee_aim_web_fixture.tscn`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Consumes: real browser RMB/LMB/WASD events
- Produces: `UAT_MOUSE_AIM_READY` modes `inside`, `clamped`, `moving`, `release`, `ui_hover`

- [ ] **Step 1: test-only fixture와 mode markers 작성**

```gdscript
print("UAT_MOUSE_AIM_READY mode=%s active=%s moved=%.1f target_distance=%.1f reach=%.1f attack_direction=%s indicator=%s valid=%s" % [
	_mode,
	str(snapshot["active"]).to_lower(),
	_moved_distance,
	float(snapshot["target_distance"]),
	float(snapshot["reach"]),
	str(_last_attack_direction),
	str(snapshot["indicator_visible"]).to_lower(),
	str(valid).to_lower(),
])
```

`inside`: cursor inside reach. `clamped`: cursor beyond reach and target_distance==reach. `moving`: RMB+W held until movement >=96px, then LMB. `release`: RMB up hides indicator without attack. `ui_hover`: real Button hover blocks aim.

- [ ] **Step 2: full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

- [ ] **Step 3: headed Chromium에서 5-mode 실제 pointer/keyboard UAT**

각 mode는 Playwright의 실제 `mouse.down(button="right")`, `keyboard.down("w")`, `mouse.down(button="left")` 경로로 실행한다. synthetic DOM event는 사용하지 않는다. 모든 marker는 `valid=true`, console/page/request error 0이어야 한다.

- [ ] **Step 4: 960×540 inside/clamped/moving 캡처**

```text
mouse-aim-inside-960x540.png
mouse-aim-clamped-960x540.png
mouse-aim-moving-attack-960x540.png
```

- [ ] **Step 5: fixture·장부 커밋**

```bash
git add tests/uat/mouse_melee_aim_web_fixture.gd tests/uat/mouse_melee_aim_web_fixture.gd.uid tests/uat/mouse_melee_aim_web_fixture.tscn tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] 우클릭 근접 조준 Web 증거 추가"
```

- [ ] **Step 6: ready PR과 merge loop 완료**

PR title: `[Player] 우클릭 홀드 근접 조준 추가`

PR body에 5-mode markers, exact tests, three inline screenshots, `Closes #548`를 넣는다. current-head Codex·CI green·unresolved 0이면 즉시 merge한다.
