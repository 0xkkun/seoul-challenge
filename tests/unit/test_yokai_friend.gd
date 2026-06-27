extends Node
## #18 요괴화 친구 중간보스 — 추적/기절/정화 단위 테스트.

const FriendScene := preload("res://scenes/enemies/yokai_friend.tscn")
const TEST_PLAYER_GROUP := &"test_purify_player"

class PurifyTarget:
	extends Node2D

	var firing := false

	func is_firing() -> bool:
		return firing

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


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


func test_stun_reveals_purify_cue_without_text_prompt() -> void:
	var f = FriendScene.instantiate()
	add_child(f)

	f.take_damage(5)

	var cue := f.get_node_or_null("PurifyCue") as Node2D
	_runner.assert_not_null(cue, "기절하면 정화 링 노드를 만든다")
	var snapshot: Dictionary = f.call("get_purify_visual_snapshot")
	_runner.assert_true(bool(snapshot["visible"]), "기절 중 정화 링이 보인다")
	_runner.assert_eq(snapshot["state"], &"ready", "홀드 전에는 정화 가능 상태")
	_runner.assert_eq(snapshot["progress"], 0.0, "처음 정화 진행도는 0")
	_runner.assert_true(int(snapshot["range_point_count"]) >= 24, "정화 가능 범위를 링으로 보여준다")
	_runner.assert_false(bool(snapshot["has_text_prompt"]), "조작 설명 문구 대신 비주얼만 쓴다")


func test_purify_proximity_updates_progress_ring_and_beam_without_attack_input() -> void:
	var f = FriendScene.instantiate()
	f.target_group = TEST_PLAYER_GROUP
	var target := PurifyTarget.new()
	target.add_to_group(TEST_PLAYER_GROUP)
	add_child(f)
	add_child(target)
	f.global_position = Vector2.ZERO
	target.global_position = Vector2(30.0, 0.0)
	target.firing = false

	f.take_damage(5)
	f.call("_process_stun", 0.6)

	var snapshot: Dictionary = f.call("get_purify_visual_snapshot")
	_runner.assert_true(bool(snapshot["in_range"]), "정화 가능 거리 안에 있음을 표시한다")
	_runner.assert_true(bool(snapshot["channeling"]), "정화 범위 안에 머무르면 채널링 상태를 표시한다")
	_runner.assert_true(float(snapshot["progress"]) > 0.45, "근접 유지 진행도가 링에 반영된다")
	_runner.assert_true(int(snapshot["progress_point_count"]) > 4, "진행 링이 일부 채워진다")
	_runner.assert_true(bool(snapshot["progress_visible"]), "정화 중 진행 링이 실제로 표시된다")
	_runner.assert_true(bool(snapshot["beam_visible"]), "정화 중 친구와 플레이어 사이 빛줄기를 보여준다")
	_runner.assert_true(bool(snapshot["beam_glow_visible"]), "정화 중 빛줄기 글로우를 함께 보여준다")


func test_leaving_purify_range_resets_progress_and_hides_beam() -> void:
	var f = FriendScene.instantiate()
	f.target_group = TEST_PLAYER_GROUP
	var target := PurifyTarget.new()
	target.add_to_group(TEST_PLAYER_GROUP)
	add_child(f)
	add_child(target)
	target.global_position = Vector2(30.0, 0.0)
	target.firing = false

	f.take_damage(5)
	f.call("_process_stun", 0.5)
	target.global_position = Vector2(120.0, 0.0)
	f.call("_process_stun", 0.1)

	var snapshot: Dictionary = f.call("get_purify_visual_snapshot")
	_runner.assert_eq(snapshot["state"], &"ready", "정화 범위 밖으로 나가면 다시 정화 가능 상태")
	_runner.assert_eq(snapshot["progress"], 0.0, "정화 범위 밖으로 나가면 진행도가 리셋된다")
	_runner.assert_false(bool(snapshot["beam_visible"]), "정화 범위 밖에서는 빛줄기를 숨긴다")


func test_purify_completion_spawns_detached_burst_before_friend_is_removed() -> void:
	var f = FriendScene.instantiate()
	f.target_group = TEST_PLAYER_GROUP
	var target := PurifyTarget.new()
	target.add_to_group(TEST_PLAYER_GROUP)
	add_child(f)
	add_child(target)
	target.global_position = Vector2(30.0, 0.0)
	target.firing = false

	f.take_damage(5)
	f.call("_process_stun", f.purify_time + 0.05)

	var burst := get_node_or_null("PurifyCompletionBurst") as Node2D
	_runner.assert_not_null(burst, "정화 완료 순간 친구와 분리된 완료 파동을 만든다")
