extends Node
## #9 트윈스틱 조준·사격 — 순수 조준/쿨다운 수학 단위 테스트.

const PlayerScript := preload("res://scripts/player/player.gd")


class SuccessfulAttackPlayer:
	extends PlayerScript

	var attack_input := true

	func is_firing() -> bool:
		return attack_input

	func aim_direction() -> Vector2:
		return Vector2.RIGHT

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


func test_successful_attack_exposes_and_emits_onboarding_signal() -> void:
	var player := SuccessfulAttackPlayer.new()
	add_child(player)
	_runner.assert_true(player.has_signal("attack_executed"), "attack start has an explicit success signal")
	if not player.has_signal("attack_executed"):
		player.queue_free()
		return
	var payloads: Array[Dictionary] = []
	player.attack_executed.connect(func(payload: Dictionary) -> void: payloads.append(payload.duplicate(true)))

	player._process_attack(0.0, Vector2.RIGHT)

	_runner.assert_eq(payloads.size(), 1, "committed attack emits exactly one success event")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0].get("direction"), Vector2.RIGHT, "attack success records direction")
		_runner.assert_eq(payloads[0].get("position"), player.global_position, "attack success records position")
		_runner.assert_eq(payloads[0].get("attack_id"), &"melee", "attack success names the committed action")

	player._process_attack(0.0, Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 1, "cooldown-blocked attack does not emit success")
	player.queue_free()


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


func test_space_is_dash_and_no_longer_attacks_on_desktop() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_false(bool(p.call("resolve_fire_input", false, true, 0.0, false, false, false)), "SPACE는 기본공격으로 중복 실행되지 않는다")
		_runner.assert_true(bool(p.call("resolve_fire_input", false, false, 0.31, false, false, false)), "우트리거는 계속 기본공격이다")
		_runner.assert_false(bool(p.call("resolve_fire_input", false, false, 0.3, false, false, false)), "우트리거 데드존 경계는 공격하지 않는다")
	_runner.assert_true(p.has_method("resolve_special_input"), "플레이어는 대시 입력 정책을 테스트 가능하게 노출한다")
	if p.has_method("resolve_special_input"):
		_runner.assert_true(bool(p.call("resolve_special_input", false, true, false, false, 0.0)), "SPACE는 PC 기본 대시다")
		_runner.assert_true(bool(p.call("resolve_special_input", false, false, true, false, 0.0)), "SHIFT는 기존 대시 보조키로 유지한다")
		_runner.assert_false(bool(p.call("resolve_special_input", false, false, false, true, 0.0)), "E는 말 걸기 전용이며 대시하지 않는다")
		_runner.assert_true(bool(p.call("resolve_special_input", true, false, false, false, 0.0)), "모바일 스킬 버튼은 계속 대시한다")
		_runner.assert_true(bool(p.call("resolve_special_input", false, false, false, false, 0.31)), "좌트리거는 계속 대시한다")
	p.free()


func test_desktop_left_mouse_over_hud_does_not_attack() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("resolve_fire_input"), "플레이어는 플랫폼별 공격 입력 정책을 노출한다")
	if p.has_method("resolve_fire_input"):
		_runner.assert_false(bool(p.call("resolve_fire_input", false, false, 0.0, true, false, true)), "HUD 위 좌클릭은 공격으로 새지 않는다")
		_runner.assert_false(bool(p.call("resolve_fire_input", false, true, 0.0, true, false, true)), "HUD 위 SPACE와 좌클릭은 공격으로 새지 않는다")
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


func test_minimap_interaction_marker_blocks_desktop_attack_click() -> void:
	var player = PlayerScript.new()
	var minimap := Control.new()
	minimap.set_meta("blocks_gameplay_attack", true)

	_runner.assert_true(player.is_interactive_mouse_control(minimap), "미니맵 클릭은 동시에 기본공격으로 새지 않는다")

	minimap.free()
	player.free()
