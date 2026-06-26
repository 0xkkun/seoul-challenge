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
