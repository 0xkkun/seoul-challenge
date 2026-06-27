extends Node
## #8 플레이어 이동 — 순수 이동 수학 단위 테스트.
## 물리/입력 없이 step_velocity / desired_velocity 만 검증한다.
## player.gd 는 전역 class_name 을 두지 않으므로(병렬 개발 충돌 방지) 동적 호출 + 결과 명시 타입을 쓴다.

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_input_moves_velocity_toward_direction() -> void:
	var p = PlayerScript.new()
	var v: Vector2 = p.step_velocity(Vector2.ZERO, Vector2.RIGHT, 1.0)
	_runner.assert_true(v.x > 0.0, "오른쪽 입력은 +x 속도를 만든다")
	_runner.assert_true(is_equal_approx(v.y, 0.0), "수평 입력은 y 속도에 영향이 없다")
	p.free()


func test_default_move_speed_is_snappier() -> void:
	var p = PlayerScript.new()
	_runner.assert_eq(p.move_speed, 260.0, "기본 이동 속도를 답답하지 않게 올린다")
	p.free()


func test_vertical_movement_keeps_topdown_evasion_responsive() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.vertical_speed_factor >= 0.78, "상하 이동이 전투 회피를 답답하게 만들지 않는다")
	p.free()


func test_attack_animation_keeps_movement_control() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(_has_property(p, "attack_move_speed_multiplier"), "공격 중 이동 배율을 명시적으로 노출한다")
	_runner.assert_true(p.has_method("movement_speed_multiplier"), "공격 중 이동 배율 계산은 순수 함수로 제공한다")
	if not _has_property(p, "attack_move_speed_multiplier") or not p.has_method("movement_speed_multiplier"):
		p.free()
		return

	var multiplier: float = p.call("movement_speed_multiplier", true, 1.0)
	_runner.assert_true(multiplier >= 0.3, "공격 후딜 중에도 약한 위치 조정은 가능하다")
	_runner.assert_true(multiplier <= 0.4, "공격 후딜 이동은 무빙샷처럼 보이지 않을 만큼 제한한다")
	p.free()


func test_attack_start_has_short_movement_commit() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(_has_property(p, "attack_movement_commit_time"), "공격 시작 이동 커밋 시간을 노출한다")
	_runner.assert_true(p.has_method("movement_speed_multiplier"), "공격 중 이동 배율 계산은 순수 함수로 제공한다")
	if not _has_property(p, "attack_movement_commit_time") or not p.has_method("movement_speed_multiplier"):
		p.free()
		return

	var commit_time := float(p.get("attack_movement_commit_time"))
	_runner.assert_true(commit_time >= 0.10, "공격 시작에는 최소 0.10초의 무게감 있는 커밋이 있다")
	_runner.assert_true(commit_time <= 0.12, "커밋은 모바일 조작이 답답하지 않도록 짧게 유지한다")

	var multiplier: float = p.call("movement_speed_multiplier", true, 1.0, commit_time)
	_runner.assert_eq(multiplier, 0.0, "공격 시작 커밋 중에는 이동하지 않는다")
	p.free()


func test_diagonal_speed_is_normalized() -> void:
	var p = PlayerScript.new()
	var speed: float = p.move_speed
	var target: Vector2 = p.desired_velocity(Vector2(1.0, 1.0))
	_runner.assert_true(abs(target.length() - speed) < 0.01, "대각선 입력도 최고 속도를 넘지 않는다")
	p.free()


func test_no_input_decelerates() -> void:
	var p = PlayerScript.new()
	var speed: float = p.move_speed
	var moving := Vector2(speed, 0.0)
	var stopped: Vector2 = p.step_velocity(moving, Vector2.ZERO, 1.0)
	_runner.assert_true(stopped.length() < moving.length(), "입력이 없으면 감속한다")
	p.free()


func test_room_bounds_clamps_horizontal_exit() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.has_method("clamp_position_to_bounds"), "플레이어는 방 경계 클램프 수학을 제공한다")
	if not p.has_method("clamp_position_to_bounds"):
		p.free()
		return

	var bounds := Rect2(Vector2(-960.0, -320.0), Vector2(1920.0, 640.0))
	var clamped: Vector2 = p.call("clamp_position_to_bounds", Vector2(1220.0, 12.0), bounds)
	_runner.assert_eq(clamped, Vector2(960.0, 12.0), "오른쪽 방 경계 밖 위치는 바닥 끝으로 제한된다")
	p.free()


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
