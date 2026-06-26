extends Node
## #18 요괴화 친구 중간보스 — 추적/기절/정화 단위 테스트.

const FriendScene := preload("res://scenes/enemies/yokai_friend.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_chase_points_toward_target() -> void:
	var f = FriendScene.instantiate()
	var v: Vector2 = f.chase_velocity(Vector2.ZERO, Vector2(0.0, 10.0), 40.0)
	_runner.assert_true(v.y > 0.0, "타겟 향해 추적(+y)")
	_runner.assert_true(is_equal_approx(v.length(), 40.0), "추적 속도 = move_speed")
	f.free()


func test_damage_accumulates_to_stun() -> void:
	var f = FriendScene.instantiate()
	f.take_damage(2)
	f.take_damage(2)
	_runner.assert_false(f.is_stunned(), "4 피해론 기절 안 함")
	f.take_damage(1)
	_runner.assert_true(f.is_stunned(), "max_stun(5) 누적 시 기절")
	f.free()


func test_damage_ignored_while_stunned() -> void:
	var f = FriendScene.instantiate()
	f.take_damage(5)
	_runner.assert_true(f.is_stunned(), "기절 진입")
	f.take_damage(10)
	_runner.assert_true(f.is_stunned(), "기절 중 피해 무시 — 여전히 기절(처치 아님)")
	f.free()


func test_purify_completes_after_hold_time() -> void:
	var f = FriendScene.instantiate()
	_runner.assert_false(f.apply_purify(0.5), "0.5초론 정화 미완(purify_time 1.2)")
	_runner.assert_true(f.apply_purify(0.8), "누적 1.3 ≥ 1.2 → 정화 완료")
	f.free()
