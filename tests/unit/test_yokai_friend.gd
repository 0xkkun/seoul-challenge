extends Node
## #18 요괴화 친구 중간보스 — 추적/기절/정화 단위 테스트.

const FriendScene := preload("res://scenes/enemies/yokai_friend.tscn")
const TEST_PLAYER_GROUP := &"test_purify_player"
const YOKAI_FRAMES_PATH := "res://assets/sprites/enemies/yokai_friend/yokai_friend_frames.tres"
const YOKAI_MOVE_SHEET_PATH := "res://assets/sprites/enemies/yokai_friend/yokai_friend_move.png"
const YOKAI_ATTACK_SHEET_PATH := "res://assets/sprites/enemies/yokai_friend/yokai_friend_attack.png"
const YOKAI_MOVE_SHEET_SHA256 := "872da21e9272d7ca735012c03f383bede9190819a611a0f411178473556cf996"
const YOKAI_ATTACK_SHEET_SHA256 := "16671ae53a00c5d4d45e107d15ef41316b656d6f59f6f4fe0fa47f52128ecedf"

class PurifyTarget:
	extends Node2D

	var firing := false

	func is_firing() -> bool:
		return firing


class DamageTarget:
	extends Node2D

	var damage_taken := 0

	func take_damage(amount: int) -> void:
		damage_taken += amount

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
	f.take_damage(3)
	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
	f.take_damage(3)
	_runner.assert_false(f.is_stunned(), "6 피해론 기절 안 함")
	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
	f.take_damage(2)
	_runner.assert_true(f.is_stunned(), "max_stun(8) 누적 시 기절")
	f.free()


func test_take_damage_returns_only_accepted_clamped_stun_delta() -> void:
	var friend = FriendScene.instantiate()
	friend.max_stun = 3
	add_child(friend)
	_runner.assert_eq(friend.take_damage(1), 1, "yokai friend returns accepted stun delta")
	_runner.assert_eq(friend.take_damage(1), 0, "yokai friend returns zero while hit-invulnerable")
	friend.call("tick_hit_reaction", friend.hit_invuln_time + 0.05)
	_runner.assert_eq(friend.take_damage(5), 2, "yokai friend overkill clamps to remaining stun threshold")
	_runner.assert_true(friend.is_stunned(), "clamped accepted damage still enters stunned state")
	_runner.assert_eq(friend.take_damage(1), 0, "yokai friend returns zero while stunned")


func test_damage_ignored_while_stunned() -> void:
	var f = FriendScene.instantiate()
	f.take_damage(8)
	_runner.assert_true(f.is_stunned(), "기절 진입")
	f.take_damage(10)
	_runner.assert_true(f.is_stunned(), "기절 중 피해 무시 — 여전히 기절(처치 아님)")
	f.free()


func test_yokai_friend_hit_sfx_plays_only_when_stun_damage_is_accepted() -> void:
	AudioManager.reset()
	var f = FriendScene.instantiate()
	add_child(f)
	f.take_damage(1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"enemy_hit"], "accepted stun accumulation plays enemy hit")

	AudioManager.reset()
	f.take_damage(1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [], "hit-invulnerable rejection stays silent")

	f.call("tick_hit_reaction", f.hit_invuln_time + 0.05)
	AudioManager.reset()
	f.take_damage(1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"enemy_hit"], "later accepted stun accumulation plays again")
	AudioManager.reset()


func test_yokai_friend_stunned_rejection_does_not_play_hit_sfx() -> void:
	AudioManager.reset()
	var f = FriendScene.instantiate()
	f.max_stun = 1
	add_child(f)
	f.take_damage(1)
	_runner.assert_true(f.is_stunned(), "fixture enters stunned state")
	AudioManager.reset()
	f.take_damage(1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [], "stunned rejection stays silent")
	AudioManager.reset()


func test_yokai_friend_defaults_are_midboss_tuned() -> void:
	var f = FriendScene.instantiate()
	var player = preload("res://scripts/player/player.gd").new()
	_runner.assert_true(f.max_stun > player.bat_damage * 3, "유령 주장은 기본 배트 세 방보다 오래 버틴다")
	_runner.assert_true(f.max_stun <= player.bat_damage * 4, "유령 주장은 기본 배트 네 방 안에는 기절한다")
	_runner.assert_eq(f.attack_damage, 2, "유령 주장 패턴 공격은 잡몹 접촉보다 아프다")
	_runner.assert_true(f.attack_trigger_range > f.contact_range, "공격은 몸통 접촉 전부터 시작된다")
	_runner.assert_true(f.attack_trigger_range <= f.attack_range, "공격 시작 거리는 실제 판정 사거리 안쪽이다")
	_runner.assert_true(f.attack_range >= 90.0, "공격 판정은 새 공격 시트 체급에 맞게 넓다")
	_runner.assert_true(f.attack_cooldown <= 0.8, "공격 쿨다운은 걷기만 하는 인상을 주지 않을 만큼 짧다")
	player.free()
	f.free()


func test_yokai_friend_png_sources_match_latest_download_assets() -> void:
	_runner.assert_eq(
		FileAccess.get_sha256(YOKAI_MOVE_SHEET_PATH),
		YOKAI_MOVE_SHEET_SHA256,
		"yokai friend move source sheet matches the provided asset"
	)
	_runner.assert_eq(
		FileAccess.get_sha256(YOKAI_ATTACK_SHEET_PATH),
		YOKAI_ATTACK_SHEET_SHA256,
		"yokai friend attack source sheet matches the provided asset"
	)


func test_visual_uses_yokai_sprite_frames_instead_of_human_portrait() -> void:
	var f = FriendScene.instantiate()
	add_child(f)
	var snapshot: Dictionary = f.call("get_visual_snapshot")
	_runner.assert_true(bool(snapshot["has_sprite"]), "요괴 친구는 실제 요괴 상태 스프라이트를 가진다")
	_runner.assert_eq(snapshot["sprite_type"], "AnimatedSprite2D", "요괴 친구는 기존 적들과 같은 AnimatedSprite2D visual을 쓴다")
	_runner.assert_eq(snapshot["sprite_frames_path"], YOKAI_FRAMES_PATH, "온보딩 정화 대상은 요괴 상태 SpriteFrames를 사용한다")
	_runner.assert_eq(snapshot["texture_path"], YOKAI_MOVE_SHEET_PATH, "move animation은 요괴 상태 이동 시트를 사용한다")
	_runner.assert_eq(snapshot["move_frame_count"], 6, "요괴 상태 이동 시트는 6프레임으로 분할된다")
	_runner.assert_eq(snapshot["attack_frame_count"], 8, "요괴 상태 공격 시트는 8프레임으로 분할된다")
	_runner.assert_true(bool(snapshot["move_loops"]), "이동 애니메이션은 루프한다")
	_runner.assert_false(bool(snapshot["attack_loops"]), "공격 애니메이션은 루프하지 않는다")
	_runner.assert_eq(snapshot["sprite_scale"], Vector2(1.18, 1.18), "유령 주장은 새 에셋 체급에 맞춰 잡몹보다 크게 보인다")
	_runner.assert_true(bool(snapshot["sprite_visible"]), "정화 대상 스프라이트는 보인다")
	_runner.assert_false(bool(snapshot["placeholder_visible"]), "임시 네모 placeholder는 숨긴다")

	var sprite := f.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "요괴 친구는 AnimatedSprite2D 노드를 유지한다")
	if sprite == null or sprite.sprite_frames == null:
		return
	var frames := sprite.sprite_frames
	var last_move := frames.get_frame_texture(&"move", 5) as AtlasTexture
	var last_attack := frames.get_frame_texture(&"attack", 7) as AtlasTexture
	_runner.assert_not_null(last_move, "마지막 이동 프레임은 AtlasTexture다")
	_runner.assert_not_null(last_attack, "마지막 공격 프레임은 AtlasTexture다")
	if last_move != null:
		_runner.assert_eq(last_move.atlas.resource_path, YOKAI_MOVE_SHEET_PATH, "마지막 이동 프레임은 이동 시트를 참조한다")
		_runner.assert_eq(last_move.region, Rect2(640, 0, 128, 128), "이동 시트 마지막 프레임 region이 맞다")
	if last_attack != null:
		_runner.assert_eq(last_attack.atlas.resource_path, YOKAI_ATTACK_SHEET_PATH, "마지막 공격 프레임은 공격 시트를 참조한다")
		_runner.assert_eq(last_attack.region, Rect2(896, 0, 128, 128), "공격 시트 마지막 프레임 region이 맞다")


func test_contact_damage_plays_attack_animation() -> void:
	var f = FriendScene.instantiate()
	var target := DamageTarget.new()
	add_child(f)
	add_child(target)
	f.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT

	f.call("_try_contact", target)

	_runner.assert_eq(target.damage_taken, f.contact_damage, "요괴 친구 접촉 피해가 유지된다")
	var sprite := f.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "요괴 친구 sprite remains mounted after contact")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"attack", "요괴 친구는 접촉 피해 때 공격 애니메이션을 재생한다")


func test_attack_pattern_winds_up_and_hits_before_body_overlap() -> void:
	var f = FriendScene.instantiate()
	f.target_group = TEST_PLAYER_GROUP
	var target := DamageTarget.new()
	target.add_to_group(TEST_PLAYER_GROUP)
	add_child(f)
	add_child(target)
	f.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 88.0

	f.call("_process_chase", 0.1)

	_runner.assert_true(f.is_attacking(), "사거리 안에 들어오면 접촉 전에 공격 상태로 전환한다")
	_runner.assert_eq(target.damage_taken, 0, "공격 시작 즉시는 아직 피해를 주지 않는다")
	var sprite := f.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "공격 패턴은 요괴 친구 sprite를 사용한다")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"attack", "공격 패턴은 공격 애니메이션을 재생한다")

	f.call("_process_attack", f.attack_windup_time - 0.01)
	_runner.assert_eq(target.damage_taken, 0, "윈드업 중에는 피해 판정 전이다")
	f.call("_process_attack", 0.02)
	_runner.assert_eq(target.damage_taken, f.attack_damage, "윈드업 후 전방 공격 피해를 준다")
	_runner.assert_true(target.global_position.distance_to(f.global_position) > f.contact_range, "테스트 대상은 몸통 접촉보다 멀리 있다")

	f.call("_process_attack", f.attack_recover_time + 0.1)
	_runner.assert_false(f.is_attacking(), "공격 회복이 끝나면 추적으로 돌아간다")


func test_attack_arc_misses_behind_target() -> void:
	var f = FriendScene.instantiate()
	_runner.assert_true(f.in_attack_arc(Vector2.RIGHT, Vector2(80.0, 0.0), f.attack_range, f.attack_arc), "정면 목표는 공격에 맞는다")
	_runner.assert_false(f.in_attack_arc(Vector2.RIGHT, Vector2(-40.0, 0.0), f.attack_range, f.attack_arc), "뒤쪽 목표는 공격에 맞지 않는다")
	_runner.assert_false(f.in_attack_arc(Vector2.RIGHT, Vector2(140.0, 0.0), f.attack_range, f.attack_arc), "사거리 밖 목표는 공격에 맞지 않는다")
	f.free()


func test_yokai_friend_sprite_flips_with_horizontal_movement_and_attack_direction() -> void:
	var f = FriendScene.instantiate()
	add_child(f)
	var sprite := f.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "요괴 친구는 AnimatedSprite2D visual을 가진다")
	if sprite == null:
		return

	f.velocity = Vector2.LEFT
	f.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "왼쪽 이동 중에는 왼쪽을 본다")

	f.velocity = Vector2.DOWN
	f.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "수직 이동 중에는 마지막 수평 방향을 유지한다")

	f.call("_play_attack_animation", Vector2.RIGHT)
	_runner.assert_false(sprite.flip_h, "오른쪽 대상 공격 시 오른쪽을 본다")


func test_hit_reaction_blocks_repeat_stun_accumulation_and_restores_visual() -> void:
	var f = FriendScene.instantiate()
	f.max_stun = 2
	add_child(f)
	var visual := f.get_node("Sprite") as CanvasItem
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

	f.take_damage(8)

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

	f.take_damage(8)
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

	f.take_damage(8)
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

	f.take_damage(8)
	f.call("_process_stun", f.purify_time + 0.05)

	var burst := get_node_or_null("PurifyCompletionBurst") as Node2D
	_runner.assert_not_null(burst, "정화 완료 순간 친구와 분리된 완료 파동을 만든다")
