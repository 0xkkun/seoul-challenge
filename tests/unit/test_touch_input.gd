extends Node
## #52 모바일 터치 입력 — 조이스틱 값/플레이어 facing 순수 함수 단위 테스트.

const JoystickScript := preload("res://scripts/ui/virtual_joystick.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_joystick_value_within_radius() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(45.0, 0.0), 90.0, 0.18)
	_runner.assert_true(is_equal_approx(v.x, 0.5), "반경 절반 → 0.5")
	j.free()


func test_joystick_value_clamps_beyond_radius() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(180.0, 0.0), 90.0, 0.18)
	_runner.assert_true(is_equal_approx(v.length(), 1.0), "반경 초과 → 1.0 클램프")
	j.free()


func test_joystick_deadzone_returns_zero() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(5.0, 0.0), 90.0, 0.18)
	_runner.assert_true(v == Vector2.ZERO, "데드존 이하 → ZERO")
	j.free()


func test_facing_updates_with_move() -> void:
	var p = PlayerScript.new()
	var f: Vector2 = p.update_facing(Vector2.DOWN, Vector2(10.0, 0.0))
	_runner.assert_true(is_equal_approx(f.x, 1.0), "이동 방향으로 facing 갱신")
	p.free()


func test_facing_holds_when_idle() -> void:
	var p = PlayerScript.new()
	var f: Vector2 = p.update_facing(Vector2.UP, Vector2.ZERO)
	_runner.assert_true(f == Vector2.UP, "이동 없으면 facing 유지")
	p.free()


func test_touch_controls_exposes_skill_button() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	_runner.assert_true(touch.has_method("is_skill_pressed"), "touch controls expose skill input")
	var skill_button := touch.get_node_or_null("SkillButton")
	_runner.assert_not_null(skill_button, "touch controls mount third skill button")
	if not touch.has_method("is_skill_pressed") or skill_button == null:
		return
	skill_button.set("_active_index", 7)
	_runner.assert_true(touch.is_skill_pressed(), "held skill button is reported")
	_runner.assert_true(skill_button.has_method("set_skill_state"), "skill button accepts skill state")
	_runner.assert_true(skill_button.has_method("get_uses_label"), "skill button exposes uses label")
	_runner.assert_true(skill_button.has_method("get_cooldown_ratio"), "skill button exposes cooldown ratio")
	if not skill_button.has_method("set_skill_state") or not skill_button.has_method("get_uses_label") or not skill_button.has_method("get_cooldown_ratio"):
		return
	skill_button.set_skill_state({
		"uses_remaining": 2,
		"max_uses": 3,
		"cooldown_remaining": 0.5,
		"cooldown": 1.0,
	})
	_runner.assert_eq(skill_button.get_uses_label(), "2", "skill button renders remaining uses")
	_runner.assert_true(is_equal_approx(skill_button.get_cooldown_ratio(), 0.5), "skill button exposes cooldown progress")
