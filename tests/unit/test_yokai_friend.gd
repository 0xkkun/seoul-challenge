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
	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
	f.take_damage(2)
	_runner.assert_false(f.is_stunned(), "4 피해론 기절 안 함")
	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
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


func test_hit_reaction_blocks_repeat_stun_accumulation_and_restores_visual() -> void:
	var f = FriendScene.instantiate()
	f.max_stun = 2
	add_child(f)
	var visual := f.get_node("Placeholder") as CanvasItem
	var base_modulate := visual.modulate
	f.take_damage(1)
	_runner.assert_true(f.has_method("is_hit_invulnerable"), "요괴 친구는 피격 무적 질의 API를 노출한다")
	_runner.assert_true(f.call("is_hit_invulnerable"), "피격 직후 짧은 무적 상태")
	_runner.assert_true(visual.modulate != base_modulate, "요괴 친구 피격 플래시")
	f.take_damage(1)
	_runner.assert_false(f.is_stunned(), "무적 중 피해는 기절 게이지에 중복 누적되지 않는다")
	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
	_runner.assert_eq(visual.modulate, base_modulate, "무적 종료 후 시각 효과 복구")
	f.take_damage(1)
	_runner.assert_true(f.is_stunned(), "무적 종료 후 피해는 기절 게이지에 반영된다")


func test_purify_completes_after_hold_time() -> void:
	var f = FriendScene.instantiate()
	_runner.assert_false(f.apply_purify(0.5), "0.5초론 정화 미완(purify_time 1.2)")
	_runner.assert_true(f.apply_purify(0.8), "누적 1.3 ≥ 1.2 → 정화 완료")
	f.free()
