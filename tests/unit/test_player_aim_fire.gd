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
