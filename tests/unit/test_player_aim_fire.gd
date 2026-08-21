extends Node
## #9 트윈스틱 조준·사격 — 순수 조준/쿨다운 수학 단위 테스트.

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_aim_points_toward_target() -> void:
	var p = PlayerScript.new()
	var dir: Vector2 = p.aim_direction_to(Vector2.ZERO, Vector2(10.0, 0.0))
	_runner.assert_true(is_equal_approx(dir.x, 1.0), "오른쪽 타겟이면 +x")
	_runner.assert_true(is_equal_approx(dir.y, 0.0), "오른쪽 타겟이면 y=0")
	p.free()


func test_aim_is_unit_length() -> void:
	var p = PlayerScript.new()
	var dir: Vector2 = p.aim_direction_to(Vector2.ZERO, Vector2(3.0, 4.0))
	_runner.assert_true(abs(dir.length() - 1.0) < 0.001, "조준 방향은 단위벡터")
	p.free()


func test_aim_zero_when_on_target() -> void:
	var p = PlayerScript.new()
	var dir: Vector2 = p.aim_direction_to(Vector2(5.0, 5.0), Vector2(5.0, 5.0))
	_runner.assert_true(dir == Vector2.ZERO, "같은 위치면 조준 ZERO")
	p.free()


func test_fire_cooldown_decrements_and_clamps() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(is_equal_approx(p.step_fire_cooldown(0.5, 0.2), 0.3), "쿨다운은 delta만큼 감소")
	_runner.assert_true(is_equal_approx(p.step_fire_cooldown(0.1, 0.2), 0.0), "0 미만으로 내려가지 않음")
	p.free()


func test_desktop_left_mouse_is_an_attack_input() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_true(bool(p.call("resolve_fire_input", false, false, 0.0, true, false, false)), "데스크톱 좌클릭은 기본공격이다")
	p.free()


func test_mobile_mouse_emulation_does_not_attack_outside_touch_button() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_false(bool(p.call("resolve_fire_input", false, false, 0.0, true, true, false)), "모바일의 일반 터치 mouse 에뮬레이션은 공격이 아니다")
		_runner.assert_true(bool(p.call("resolve_fire_input", true, false, 0.0, true, true, false)), "모바일은 기존 공격 버튼 터치로 공격한다")
	p.free()


func test_space_and_controller_attack_inputs_remain_available() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_true(bool(p.call("resolve_fire_input", false, true, 0.0, false, false, false)), "SPACE는 계속 기본공격이다")
		_runner.assert_true(bool(p.call("resolve_fire_input", false, false, 0.31, false, false, false)), "우트리거는 계속 기본공격이다")
		_runner.assert_false(bool(p.call("resolve_fire_input", false, false, 0.3, false, false, false)), "우트리거 데드존 경계는 공격하지 않는다")
	p.free()


func test_desktop_left_mouse_over_hud_does_not_attack() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_false(bool(p.call("resolve_fire_input", false, false, 0.0, true, false, true)), "HUD 위 좌클릭은 공격으로 새지 않는다")
		_runner.assert_true(bool(p.call("resolve_fire_input", false, true, 0.0, true, false, true)), "HUD hover는 명시적인 SPACE 공격까지 막지 않는다")
	p.free()


func test_only_interactive_controls_block_desktop_attack_clicks() -> void:
	var p = PlayerScript.new()
	var presentation_root := Control.new()
	var button := Button.new()
	var button_label := Label.new()
	presentation_root.add_child(button)
	button.add_child(button_label)

	_runner.assert_false(p.is_interactive_mouse_control(presentation_root), "전체 화면 표시 Root는 게임 영역 좌클릭을 막지 않는다")
	_runner.assert_true(p.is_interactive_mouse_control(button), "HUD 버튼은 좌클릭 공격을 막는다")
	_runner.assert_true(p.is_interactive_mouse_control(button_label), "HUD 버튼의 자식 위 클릭도 공격으로 새지 않는다")

	presentation_root.free()
	p.free()
