extends Node
## 플레이어 근접 공격 — 부채꼴 판정(순수) + 실제 타격 단위 테스트.
## (기본 공격을 원거리→근접으로 변경. 원거리는 ranged_enabled 로 보존.)

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


class StubEnemy extends Node2D:
	var taken: int = 0
	var accepts_damage := true
	func take_damage(amount: int) -> int:
		if not accepts_damage:
			return 0
		taken += amount
		return amount


class StubResistantEnemy extends StubEnemy:
	var knockback_resistance: float = 0.8


class StubParryEnemy extends StubEnemy:
	var parry_count: int = 0
	var parried_dir: Vector2 = Vector2.ZERO
	var parry_result := true
	func parry_dash(direction: Vector2) -> bool:
		parry_count += 1
		parried_dir = direction
		return parry_result


class StubBoundedEnemy extends StubEnemy:
	var bounds := Rect2()
	var bounds_enabled := false
	var clamp_count := 0

	func set_movement_bounds(next_bounds: Rect2) -> void:
		bounds = next_bounds
		bounds_enabled = bounds.size.x > 0.0 and bounds.size.y > 0.0

	func clamp_to_movement_bounds() -> bool:
		clamp_count += 1
		if not bounds_enabled:
			return false
		var before := global_position
		global_position = Vector2(
			clampf(global_position.x, bounds.position.x, bounds.end.x),
			clampf(global_position.y, bounds.position.y, bounds.end.y)
		)
		return not before.is_equal_approx(global_position)


class StubBullet extends Node2D:
	var deflect_count: int = 0
	var deflected_dir: Vector2 = Vector2.ZERO
	func deflect(direction: Vector2) -> void:
		deflect_count += 1
		deflected_dir = direction


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	HitStopManager.restore()


func after_each() -> void:
	HitStopManager.restore()


func test_hit_stop_profile_matches_combat_result() -> void:
	_runner.assert_eq(PlayerScript.hit_stop_profile(false, false), {"duration": 0.03, "scale": 0.15}, "normal melee uses the light hit-stop profile")
	_runner.assert_eq(PlayerScript.hit_stop_profile(true, false), {"duration": 0.06, "scale": 0.08}, "dash power melee uses the stronger profile")
	_runner.assert_eq(PlayerScript.hit_stop_profile(false, true), {"duration": 0.05, "scale": 0.10}, "accepted player damage uses the hurt profile")


func test_general_hit_stop_requires_positive_applied_damage() -> void:
	var player := PlayerScript.new()
	add_child(player)
	player.position = Vector2.ZERO
	var rejected := StubEnemy.new()
	rejected.accepts_damage = false
	rejected.position = Vector2(25.0, 0.0)
	rejected.add_to_group(&"enemy")
	add_child(rejected)

	player._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(rejected.taken, 0, "rejected overlap applies no damage")
	_runner.assert_false(HitStopManager.is_active(), "rejected overlap cannot start hit stop")
	_runner.assert_eq(Engine.time_scale, 1.0, "rejected overlap keeps real-time play")
	rejected.free()
	player.free()


func test_general_hit_stop_uses_one_profile_for_mixed_targets() -> void:
	var payloads: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		payloads.append(payload)
	EventBus.combat_feedback.connect(callback)
	var player := PlayerScript.new()
	add_child(player)
	player.position = Vector2.ZERO
	var accepted := StubEnemy.new()
	accepted.position = Vector2(25.0, 0.0)
	accepted.add_to_group(&"enemy")
	add_child(accepted)
	var rejected := StubEnemy.new()
	rejected.accepts_damage = false
	rejected.position = Vector2(30.0, 0.0)
	rejected.add_to_group(&"enemy")
	add_child(rejected)

	player._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(accepted.taken, player.melee_damage, "accepted target receives damage once")
	_runner.assert_eq(rejected.taken, 0, "rejected target remains untouched")
	_runner.assert_true(is_equal_approx(HitStopManager.get_remaining_real_seconds(), 0.03), "mixed swing requests one normal hit-stop duration")
	_runner.assert_true(is_equal_approx(HitStopManager.get_active_scale(), 0.15), "mixed swing requests the normal hit-stop scale")
	_runner.assert_eq(payloads.size(), 1, "mixed swing emits one combat feedback payload")
	if payloads.size() == 1:
		_runner.assert_eq(int(payloads[0].get("hit_count", -1)), 1, "feedback counts only accepted targets")
	EventBus.combat_feedback.disconnect(callback)
	accepted.free()
	rejected.free()
	player.free()


func test_power_attack_hit_stop_uses_stronger_profile() -> void:
	var player := PlayerScript.new()
	add_child(player)
	player.position = Vector2.ZERO
	player.equip_bat()
	var enemy := StubEnemy.new()
	enemy.position = Vector2(50.0, 0.0)
	enemy.add_to_group(&"enemy")
	add_child(enemy)
	player.try_start_special_skill(Vector2.RIGHT)

	player._attack_melee(Vector2.RIGHT)

	_runner.assert_true(is_equal_approx(HitStopManager.get_remaining_real_seconds(), 0.06), "accepted power attack requests its longer duration")
	_runner.assert_true(is_equal_approx(HitStopManager.get_active_scale(), 0.08), "accepted power attack requests its stronger slow scale")
	enemy.free()
	player.free()


func test_in_melee_arc_front_is_hit() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.in_melee_arc(Vector2.RIGHT, Vector2(10.0, 0.0), 1.6), "정면은 부채꼴 안")
	p.free()


func test_in_melee_arc_back_is_miss() -> void:
	var p = PlayerScript.new()
	_runner.assert_false(p.in_melee_arc(Vector2.RIGHT, Vector2(-10.0, 0.0), 1.6), "뒤는 부채꼴 밖")
	_runner.assert_false(p.in_melee_arc(Vector2.RIGHT, Vector2(0.0, -10.0), 1.6), "90도는 부채꼴 밖")
	p.free()


func test_melee_hits_enemy_in_front() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, 1, "정면 사거리 안 적이 피해를 받음")
	e.free()
	p.free()


func test_barehand_reach_is_forgiving_for_mobile_combat() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.melee_range >= 44.0, "맨손 기본 사거리는 모바일에서 헛손질이 잦지 않게 넉넉해야 한다")
	p.free()


func test_bat_reach_is_comfortable_for_mobile_combat() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.bat_range >= 132.0, "배트 기본 사거리는 모바일에서 짧게 느껴지지 않게 충분히 길어야 한다")
	p.free()


func test_bat_hits_enemy_at_extended_mobile_reach() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubEnemy.new()
	e.position = Vector2(124.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.taken, p.bat_damage, "배트는 120px대 정면 적까지 닿아야 한다")
	e.free()
	p.free()


func test_bat_hits_enemy_above_at_mobile_reach() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubEnemy.new()
	e.position = Vector2(0.0, -96.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.UP)

	_runner.assert_eq(e.taken, p.bat_damage, "배트는 상단 96px 적까지 닿아야 한다")
	e.free()
	p.free()


func test_barehand_hit_applies_small_knockback() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(30.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_true(e.position.x > 30.0, "맨손도 적을 살짝 밀어내 타격 반응을 만든다")
	e.free()
	p.free()


func test_melee_knockback_clamps_enemy_to_room_bounds() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubBoundedEnemy.new()
	e.position = Vector2(90.0, 0.0)
	e.set_movement_bounds(Rect2(Vector2(0.0, -10.0), Vector2(100.0, 20.0)))
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.position.x, 100.0, "넉백 직후 적 위치는 방 경계 안으로 제한된다")
	_runner.assert_eq(e.clamp_count, 1, "넉백은 적의 이동 경계 clamp 계약을 즉시 호출한다")
	e.free()
	p.free()


func test_bat_knockback_respects_enemy_resistance() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubResistantEnemy.new()
	e.position = Vector2(50.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	var expected_x: float = 50.0 + p.bat_knockback * 0.2
	_runner.assert_true(is_equal_approx(e.position.x, expected_x), "넉백 저항 80% 적은 배트 넉백의 20%만 밀린다")
	_runner.assert_eq(e.taken, p.bat_damage, "넉백 저항은 피해량을 줄이지 않는다")
	e.free()
	p.free()


func test_knockback_after_resistance_scales_distance() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(is_equal_approx(p.knockback_after_resistance(64.0, 0.8), 12.8), "80% 넉백 저항은 거리의 20%만 남긴다")
	_runner.assert_true(is_equal_approx(p.knockback_after_resistance(64.0, -0.5), 64.0), "음수 저항은 0으로 클램프한다")
	_runner.assert_true(is_equal_approx(p.knockback_after_resistance(64.0, 1.5), 0.0), "100% 초과 저항은 완전 저항으로 클램프한다")
	p.free()


func test_melee_hit_emits_combat_feedback() -> void:
	_runner.assert_true(EventBus.has_signal("combat_feedback"), "전투 피드백 이벤트 표면이 존재한다")
	_runner.assert_true(EventBus.has_method("emit_combat_feedback"), "전투 피드백은 payload wrapper 로 발신한다")
	if not EventBus.has_signal("combat_feedback") or not EventBus.has_method("emit_combat_feedback"):
		return

	var payloads: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		payloads.append(payload)
	EventBus.combat_feedback.connect(callback)

	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(payloads.size(), 1, "근접 타격은 전투 피드백 이벤트를 1회 낸다")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0].get("kind", &""), &"melee_hit", "피드백 종류는 근접 히트")
		_runner.assert_true(float(payloads[0].get("intensity", 0.0)) > 0.0, "카메라/이펙트가 쓸 intensity 를 포함한다")

	EventBus.combat_feedback.disconnect(callback)
	e.free()
	p.free()


func test_bat_melee_hit_feedback_is_visible_enough_for_camera_kick() -> void:
	var payloads: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		payloads.append(payload)
	EventBus.combat_feedback.connect(callback)

	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubEnemy.new()
	e.position = Vector2(50.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(payloads.size(), 1, "배트 타격은 전투 피드백 이벤트를 1회 낸다")
	if payloads.size() == 1:
		_runner.assert_true(float(payloads[0].get("intensity", 0.0)) >= 5.0, "배트 타격 화면 흔들림은 실기기에서 보일 만큼 강해야 한다")

	EventBus.combat_feedback.disconnect(callback)
	e.free()
	p.free()


func test_bat_attack_plays_swing_sfx() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"bat_swing"], "bat melee attack plays the bat swing SFX once")
	p.free()
	AudioManager.reset()


func test_bat_attack_hit_plays_one_impact_sfx_per_swing() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var first_enemy := StubEnemy.new()
	first_enemy.position = Vector2(50.0, 0.0)
	first_enemy.add_to_group(&"enemy")
	add_child(first_enemy)
	var second_enemy := StubEnemy.new()
	second_enemy.position = Vector2(80.0, 0.0)
	second_enemy.add_to_group(&"enemy")
	add_child(second_enemy)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"bat_swing", &"bat_hit"], "배트가 여러 적을 맞춰도 스윙음 뒤 타격음은 1회만 재생된다")
	first_enemy.free()
	second_enemy.free()
	p.free()
	AudioManager.reset()


func test_barehand_hit_does_not_play_bat_impact_sfx() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"bare_hand_swing"], "맨손 타격은 전용 스윙음만 재생하고 배트 타격음은 재생하지 않는다")
	e.free()
	p.free()
	AudioManager.reset()


func test_barehand_attack_plays_only_its_dedicated_swing_sfx() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"bare_hand_swing"], "barehand melee attack plays only its dedicated swing SFX")
	p.free()
	AudioManager.reset()


func test_default_melee_attack_cooldown_is_slightly_slower() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(is_equal_approx(p.attack_cooldown, 0.48), "기본 근접 공격 간격은 애니메이션과 맞는 0.48초다")
	p.free()


func test_attack_animation_finishes_within_attack_cooldown() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "player scene has an animated sprite")
	_runner.assert_true(player.has_method("animation_duration_seconds"), "player exposes animation duration helper")
	_runner.assert_true(player.has_method("attack_animation_speed_scale"), "player exposes attack animation speed helper")
	if sprite == null or not player.has_method("animation_duration_seconds") or not player.has_method("attack_animation_speed_scale"):
		player.queue_free()
		return

	var base_duration := float(player.call("animation_duration_seconds", sprite.sprite_frames, &"attack"))
	var speed_scale := float(player.call("attack_animation_speed_scale", base_duration, player.attack_cooldown))
	var previous_speed_scale := float(player.call("attack_animation_speed_scale", base_duration, 0.35))

	_runner.assert_true(base_duration > player.attack_cooldown, "baseline attack sheet is longer than the gameplay cooldown")
	_runner.assert_true(speed_scale > 1.0, "attack animation speeds up to match gameplay cooldown")
	_runner.assert_true(speed_scale <= 1.20, "attack animation no longer rushes far ahead of the swing cooldown")
	_runner.assert_true(speed_scale < previous_speed_scale, "slower attack cooldown lowers the attack animation speed")
	_runner.assert_true(base_duration / speed_scale <= player.attack_cooldown + 0.001, "scaled attack animation ends before the next attack is ready")
	player.queue_free()


func test_play_attack_anim_applies_and_resets_speed_scale() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "player scene has an animated sprite")
	if sprite == null:
		player.queue_free()
		return

	var base_duration := float(player.call("animation_duration_seconds", sprite.sprite_frames, &"attack"))
	var expected_scale := float(player.call("attack_animation_speed_scale", base_duration, player.attack_cooldown))
	player._play_attack_anim(Vector2.RIGHT)

	_runner.assert_true(sprite.speed_scale > 1.0, "attack animation plays faster than the authored sheet")
	_runner.assert_true(is_equal_approx(sprite.speed_scale, expected_scale), "attack animation uses cooldown-derived speed scale")
	player._on_sprite_animation_finished()
	_runner.assert_true(is_equal_approx(sprite.speed_scale, 1.0), "attack animation speed resets after the motion")
	player.queue_free()


func test_dash_power_attack_hits_farther_and_deals_bonus_damage() -> void:
	var p = PlayerScript.new()
	add_child(p)
	_runner.assert_true(_has_property(p, "dash_power_attack_damage_bonus"), "player exposes dash power damage bonus")
	_runner.assert_true(p.has_method("get_dash_power_attack_remaining"), "player exposes dash power window state")
	if not _has_property(p, "dash_power_attack_damage_bonus") or not p.has_method("get_dash_power_attack_remaining"):
		p.free()
		return
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(38.0, 0.0)  # regular melee_range(34) misses, dash power range reaches
	e.add_to_group(&"enemy")
	add_child(e)
	p.try_start_special_skill(Vector2.RIGHT)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.taken, p.melee_damage + p.dash_power_attack_damage_bonus, "dash power attack deals bonus damage")
	_runner.assert_true(is_equal_approx(p.get_dash_power_attack_remaining(), 0.0), "power attack consumes the window")
	e.free()
	p.free()


func test_dash_power_attack_is_consumed_even_while_dodge_remains_active() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.try_start_special_skill(Vector2.RIGHT)
	var first_enemy := StubEnemy.new()
	first_enemy.position = Vector2(25.0, 0.0)
	first_enemy.add_to_group(&"enemy")
	add_child(first_enemy)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(first_enemy.taken, p.melee_damage + p.dash_power_attack_damage_bonus, "first dash attack is powered")
	first_enemy.free()

	var second_enemy := StubEnemy.new()
	second_enemy.position = Vector2(25.0, 0.0)
	second_enemy.add_to_group(&"enemy")
	add_child(second_enemy)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(second_enemy.taken, p.melee_damage, "second attack in the same dodge is not powered")
	second_enemy.free()
	p.free()


func test_player_collision_radius_stays_inside_melee_range() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var collision := player.get_node("Collision") as CollisionShape2D
	var shape := collision.shape as CircleShape2D

	_runner.assert_not_null(shape, "player collision uses a circle shape")
	if shape != null:
		_runner.assert_true(
			shape.radius <= player.melee_range,
			"melee-only player can move close enough to hit enemy centers"
		)


func test_melee_misses_enemy_behind() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(-25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, 0, "뒤의 적은 안 맞음")
	e.free()
	p.free()


func test_bat_deflects_enemy_projectile_in_arc() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	p.set_bat_awakened(true)
	var b := StubBullet.new()
	b.position = Vector2(40.0, 0.0)  # 정면, bat_range(56) 안
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 1, "배트 부채꼴 안 적탄을 되받아침")
	_runner.assert_eq(b.deflected_dir, Vector2.RIGHT, "스윙 방향으로 되받아침")
	b.free()
	p.free()


func test_bat_swing_parries_dash_enemy_in_arc() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubParryEnemy.new()
	e.position = Vector2(40.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.parry_count, 1, "배트 스윙은 정면 돌진 적을 패링한다")
	_runner.assert_eq(e.parried_dir, Vector2.RIGHT, "패링 방향은 배트 스윙 방향을 따른다")
	e.free()
	p.free()


func test_bat_emits_parry_success_only_when_dash_parry_returns_true() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2(12.0, 8.0)
	p.equip_bat()
	var payloads: Array[Dictionary] = []
	if p.has_signal("parry_succeeded"):
		p.connect(&"parry_succeeded", func(payload: Dictionary) -> void: payloads.append(payload))
	var e := StubParryEnemy.new()
	e.position = Vector2(52.0, 8.0)
	e.parry_result = false
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 0, "비돌진 늑대의 false 반환은 패링 성공을 발행하지 않는다")

	e.position = Vector2(52.0, 8.0)
	e.parry_result = true
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 1, "실제 dash parry 성공은 이벤트를 정확히 한 번 발행한다")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0].get("direction"), Vector2.RIGHT, "패링 성공 payload는 스윙 방향을 포함한다")
		_runner.assert_eq(payloads[0].get("player_position"), p.global_position, "패링 성공 payload는 플레이어 위치를 포함한다")
		_runner.assert_eq(payloads[0].get("enemy_position"), Vector2(52.0, 8.0), "패링 성공 payload는 넉백 전 충돌 위치를 포함한다")

	e.position = Vector2(52.0, 8.0)
	e.parry_result = false
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 1, "recovery에서 반복 호출된 false는 성공을 재발행하지 않는다")
	e.free()
	p.free()


func test_bat_parry_audio_orders_swing_success_then_hit() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	p.connect(&"parry_succeeded", func(_payload: Dictionary) -> void:
		AudioManager.play_sfx(AudioManager.PARRY_SUCCESS)
	)
	var e := StubParryEnemy.new()
	e.position = Vector2(40.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[AudioManager.BAT_SWING, AudioManager.PARRY_SUCCESS, AudioManager.BAT_HIT],
		"player emits parry success after swing audio and before impact audio"
	)
	e.free()
	p.free()
	AudioManager.reset()


func test_bare_hands_do_not_parry_dash_enemy() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubParryEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.parry_count, 0, "맨손은 늑대 돌진을 패링하지 못한다")
	e.free()
	p.free()


func test_bat_does_not_deflect_projectile_behind() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	p.set_bat_awakened(true)
	var b := StubBullet.new()
	b.position = Vector2(-40.0, 0.0)  # 뒤
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "뒤의 적탄은 안 튕김")
	b.free()
	p.free()


func test_unawakened_bat_clears_enemy_projectile_without_deflecting() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	p.set_bat_awakened(false)
	var b := StubBullet.new()
	b.position = Vector2(40.0, 0.0)
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "미각성 배트는 적탄을 되받아치지 않는다")
	_runner.assert_true(b.is_queued_for_deletion(), "미각성 배트는 방어 보상으로 적탄만 제거한다")
	p.free()


func test_bare_hands_do_not_deflect_projectiles() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var b := StubBullet.new()
	b.position = Vector2(20.0, 0.0)  # 정면, melee_range(34) 안이지만 배트 없음
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "맨손은 적탄을 못 튕김(배트 전용)")
	b.free()
	p.free()


func test_enemy_bullet_deflect_retargets_to_enemy_layer() -> void:
	var bullet := (load("res://scenes/enemies/enemy_bullet.tscn") as PackedScene).instantiate()
	add_child(bullet)
	bullet.launch(Vector2.ZERO, Vector2.LEFT)
	_runner.assert_true(bullet.is_in_group(&"enemy_projectile"), "발사 시 적탄 그룹")
	_runner.assert_eq(bullet.collision_mask, 2, "발사 시 플레이어(레이어2) 타격")
	bullet.deflect(Vector2.RIGHT)
	_runner.assert_eq(bullet.collision_mask, 1, "deflect 후 적(레이어1) 타격으로 전환")
	_runner.assert_false(bullet.is_in_group(&"enemy_projectile"), "deflect 후 적탄 그룹에서 빠짐")
	_runner.assert_eq(bullet.damage, bullet.deflect_damage, "deflect 후 반사 피해로 전환")
	bullet.free()


func test_bat_dash_power_attack_knocks_back_farther_than_normal_bat() -> void:
	var normal_player = PlayerScript.new()
	add_child(normal_player)
	normal_player.position = Vector2.ZERO
	normal_player.equip_bat()
	var normal_enemy := StubEnemy.new()
	normal_enemy.position = Vector2(50.0, 0.0)
	normal_enemy.add_to_group(&"enemy")
	add_child(normal_enemy)
	normal_player._attack_melee(Vector2.RIGHT)
	var normal_knockback_x := normal_enemy.position.x
	normal_enemy.free()
	normal_player.free()

	var power_player = PlayerScript.new()
	add_child(power_player)
	power_player.position = Vector2.ZERO
	power_player.equip_bat()
	var power_enemy := StubEnemy.new()
	power_enemy.position = Vector2(50.0, 0.0)
	power_enemy.add_to_group(&"enemy")
	add_child(power_enemy)
	power_player.try_start_special_skill(Vector2.RIGHT)
	power_player._attack_melee(Vector2.RIGHT)

	_runner.assert_true(power_enemy.position.x > normal_knockback_x, "dash power bat attack applies stronger knockback")
	power_enemy.free()
	power_player.free()


func test_player_scene_includes_hidden_bat_swing_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("BatSwingImpact") as Node2D

	_runner.assert_not_null(impact, "player scene includes bat swing slash effect root")
	if impact != null:
		_runner.assert_false(impact.visible, "bat swing effect starts hidden")
		var slash_sprite := impact.get_node_or_null("SlashSprite") as Sprite2D
		_runner.assert_not_null(slash_sprite, "bat swing uses the supplied pixel slash sprite")
		if slash_sprite != null:
			_runner.assert_false(slash_sprite.visible, "bat slash sprite starts hidden with the root")
			_runner.assert_eq(slash_sprite.hframes, 9, "bat slash sheet has nine animation frames")
			_runner.assert_eq(slash_sprite.texture.resource_path, "res://assets/effects/bat_slash.png", "bat slash uses the white pixel sheet")


func test_bat_swing_show_plays_pixel_slash_sheet() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("BatSwingImpact") as Node2D
	_runner.assert_not_null(impact, "player scene includes bat swing effect root")
	if impact == null:
		return

	player._show_bat_swing_effect(Vector2.RIGHT, 100.0, 2.2)

	var slash_sprite := impact.get_node_or_null("SlashSprite") as Sprite2D
	_runner.assert_true(impact.visible, "showing bat swing reveals the effect root")
	_runner.assert_not_null(slash_sprite, "bat swing uses a sprite sheet child")
	if slash_sprite != null:
		_runner.assert_true(slash_sprite.visible, "showing bat swing reveals the slash sprite")
		_runner.assert_eq(slash_sprite.frame, 0, "bat slash animation starts from the first frame")
		_runner.assert_eq(slash_sprite.texture.resource_path, "res://assets/effects/bat_slash.png", "bat swing uses the white slash sheet")
		_runner.assert_true(slash_sprite.scale.x > 1.0, "bat slash is scaled up for mobile readability")


func test_bat_attack_hides_debug_like_melee_range_wedge() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.equip_bat()

	player._attack_melee(Vector2.RIGHT)

	var melee_swing := player.get_node_or_null("MeleeSwing") as CanvasItem
	var bat_swing := player.get_node_or_null("BatSwingImpact") as CanvasItem
	_runner.assert_not_null(melee_swing, "player keeps melee swing node for bare hands")
	_runner.assert_not_null(bat_swing, "player keeps bat swing effect node")
	if melee_swing != null:
		_runner.assert_false(melee_swing.visible, "bat attack does not show the white range wedge")
	if bat_swing != null:
		_runner.assert_true(bat_swing.visible, "bat attack still shows the authored slash effect")


func test_dash_power_attack_uses_only_power_effect_not_blue_bat_slash() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.equip_bat()

	player.try_start_special_skill(Vector2.RIGHT)
	player._attack_melee(Vector2.RIGHT)

	var bat_swing := player.get_node_or_null("BatSwingImpact") as CanvasItem
	var power_impact := player.get_node_or_null("PowerImpact") as CanvasItem
	_runner.assert_not_null(bat_swing, "player keeps bat swing effect node")
	_runner.assert_not_null(power_impact, "player keeps power impact effect node")
	if bat_swing != null:
		_runner.assert_false(bat_swing.visible, "dash power attack skips the normal bat slash")
	if power_impact != null:
		_runner.assert_true(power_impact.visible, "dash power attack shows the fire slash effect")


func test_attack_dust_state_places_effect_behind_facing_at_feet() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("build_attack_dust_effect_state"), "player exposes pure attack dust placement helper")
	if not player.has_method("build_attack_dust_effect_state"):
		player.free()
		return

	var right_state: Dictionary = player.call(
		"build_attack_dust_effect_state",
		Vector2.RIGHT,
		Vector2(48.0, 72.0),
		72.0,
		36.0,
		52.0
	)
	var up_state: Dictionary = player.call(
		"build_attack_dust_effect_state",
		Vector2.UP,
		Vector2(48.0, 72.0),
		72.0,
		36.0,
		52.0
	)
	var down_state: Dictionary = player.call(
		"build_attack_dust_effect_state",
		Vector2.DOWN,
		Vector2(48.0, 72.0),
		72.0,
		36.0,
		52.0
	)

	_runner.assert_true((right_state["position"] as Vector2).x < 0.0, "right-facing attack places dust behind the player")
	_runner.assert_true(is_equal_approx((right_state["position"] as Vector2).y, 52.0), "dust keeps a foot-level downward offset")
	_runner.assert_true(is_equal_approx(float(right_state["rotation"]), Vector2.LEFT.angle()), "dust points toward the opposite direction")
	_runner.assert_true(is_equal_approx((right_state["scale"] as Vector2).x, 1.0), "dust uses a runtime-sized source frame without shrinking blocky source art")
	_runner.assert_true((up_state["position"] as Vector2).x < 0.0, "up-facing attack falls back to the left-side foot dust")
	_runner.assert_true(is_equal_approx((up_state["position"] as Vector2).y, 52.0), "up-facing attack keeps dust on the foot line")
	_runner.assert_true(is_equal_approx(float(up_state["rotation"]), Vector2.LEFT.angle()), "up-facing attack dust uses a horizontal rotation")
	_runner.assert_true((down_state["position"] as Vector2).x < 0.0, "down-facing attack falls back to the left-side foot dust")
	_runner.assert_true(is_equal_approx((down_state["position"] as Vector2).y, 52.0), "down-facing attack keeps dust on the foot line")
	player.free()


func test_attack_dust_diagonal_direction_uses_horizontal_axis_only() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("build_attack_dust_effect_state"), "player exposes pure attack dust placement helper")
	if not player.has_method("build_attack_dust_effect_state"):
		player.free()
		return

	var diagonal_state: Dictionary = player.call(
		"build_attack_dust_effect_state",
		Vector2(1.0, 1.0),
		Vector2(48.0, 72.0),
		72.0,
		36.0,
		52.0
	)
	var left_diagonal_state: Dictionary = player.call(
		"build_attack_dust_effect_state",
		Vector2(-1.0, 1.0),
		Vector2(48.0, 72.0),
		72.0,
		36.0,
		52.0
	)
	var position := diagonal_state["position"] as Vector2
	var rotation := float(diagonal_state["rotation"])
	var left_position := left_diagonal_state["position"] as Vector2
	var left_rotation := float(left_diagonal_state["rotation"])

	_runner.assert_true(position.x < 0.0, "right-leaning diagonal attack places dust on the left foot side")
	_runner.assert_true(is_equal_approx(position.y, 52.0), "right-leaning diagonal attack ignores vertical facing for dust placement")
	_runner.assert_true(is_equal_approx(rotation, Vector2.LEFT.angle()), "right-leaning diagonal attack dust uses left-facing rotation")
	_runner.assert_true(left_position.x > 0.0, "left-leaning diagonal attack places dust on the right foot side")
	_runner.assert_true(is_equal_approx(left_position.y, 52.0), "left-leaning diagonal attack ignores vertical facing for dust placement")
	_runner.assert_true(is_equal_approx(left_rotation, Vector2.RIGHT.angle()), "left-leaning diagonal attack dust uses right-facing rotation")
	player.free()


func test_attack_dust_only_triggers_while_moving() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("should_show_attack_dust"), "player exposes dust movement gate helper")
	if not player.has_method("should_show_attack_dust"):
		player.free()
		return

	_runner.assert_true(bool(player.call("should_show_attack_dust", Vector2.RIGHT)), "moving attack shows dust")
	_runner.assert_false(bool(player.call("should_show_attack_dust", Vector2.ZERO)), "standing attack does not show dust")
	player.free()


func test_player_scene_includes_hidden_attack_dust_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var player_sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	var dust_root := player.get_node_or_null("AttackDust") as Node2D
	var source_sheet := load("res://assets/effects/attack_reverse_dust.png") as Texture2D

	_runner.assert_not_null(player_sprite, "player scene includes the main sprite")
	_runner.assert_not_null(source_sheet, "attack dust keeps the rebuilt 17-frame runtime sheet")
	if source_sheet != null:
		_runner.assert_eq(source_sheet.get_width(), 816, "attack dust source sheet has seventeen 48px frames")
		_runner.assert_eq(source_sheet.get_height(), 72, "attack dust source sheet keeps the runtime VFX height")
	_runner.assert_not_null(dust_root, "player scene includes attack dust effect root")
	if dust_root != null:
		_runner.assert_false(dust_root.visible, "attack dust starts hidden")
		_runner.assert_true(dust_root.z_index > 0, "attack dust renders above floor/background layers")
		if player_sprite != null:
			_runner.assert_true(player_sprite.z_index > dust_root.z_index, "player sprite renders over foot dust without hiding it under the floor")
		var dust_sprite := dust_root.get_node_or_null("DustSprite") as AnimatedSprite2D
		_runner.assert_not_null(dust_sprite, "attack dust uses an animated sprite sheet")
		if dust_sprite != null:
			_runner.assert_false(dust_sprite.visible, "attack dust sprite starts hidden with the root")
			_runner.assert_not_null(dust_sprite.sprite_frames, "attack dust has SpriteFrames")
			if dust_sprite.sprite_frames != null:
				_runner.assert_eq(dust_sprite.sprite_frames.get_frame_count(&"burst"), 17, "attack dust sheet uses the 17 non-empty frames")
				var first_frame := dust_sprite.sprite_frames.get_frame_texture(&"burst", 0)
				_runner.assert_not_null(first_frame, "attack dust has a first texture frame")
				if first_frame != null:
					_runner.assert_eq(first_frame.resource_path, "res://assets/effects/attack_reverse_dust/frame_00.png", "attack dust uses individual runtime frames")
					_runner.assert_eq(first_frame.get_width(), 48, "attack dust frame matches the runtime VFX width")
					_runner.assert_eq(first_frame.get_height(), 72, "attack dust frame matches the runtime VFX height")
					var first_image := first_frame.get_image()
					_runner.assert_not_null(first_image, "attack dust texture exposes image data for validation")
					if first_image != null:
						_runner.assert_true(_count_visible_color_steps(first_image) >= 4, "attack dust first frame has enough pixel-color detail")
				var middle_frame := dust_sprite.sprite_frames.get_frame_texture(&"burst", 8)
				_runner.assert_not_null(middle_frame, "attack dust has a middle texture frame")
				if middle_frame != null:
					var middle_image := middle_frame.get_image()
					_runner.assert_not_null(middle_image, "attack dust middle texture exposes image data")
					if middle_image != null:
						var middle_rect := middle_image.get_used_rect()
						_runner.assert_true(_count_visible_color_steps(middle_image) >= 8, "attack dust middle frame preserves multiple color and alpha steps")
						_runner.assert_true(_count_visible_alpha_steps(middle_image) >= 4, "attack dust middle frame uses translucent fade steps")
						_runner.assert_true(middle_rect.size.x >= 24, "attack dust middle frame reads as a plume instead of a broken shard")
						_runner.assert_true(middle_rect.size.y >= 18, "attack dust middle frame keeps enough vertical body to read in motion")


func test_moving_attack_shows_dust_behind_facing() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	_runner.assert_true(player.has_method("_show_attack_dust"), "player exposes attack dust trigger")
	if not player.has_method("_show_attack_dust"):
		player.queue_free()
		return

	player.call("_show_attack_dust", Vector2.RIGHT, Vector2.RIGHT)

	var dust_root := player.get_node_or_null("AttackDust") as Node2D
	var dust_sprite := dust_root.get_node_or_null("DustSprite") as AnimatedSprite2D if dust_root != null else null
	_runner.assert_not_null(dust_root, "player scene includes attack dust effect root")
	_runner.assert_not_null(dust_sprite, "attack dust root has a sprite")
	if dust_root != null:
		_runner.assert_true(dust_root.visible, "moving attack reveals dust root")
		_runner.assert_true(dust_root.position.x < 0.0, "right-facing moving attack puts dust behind the player")
		_runner.assert_true(dust_root.position.y > 40.0, "moving attack places dust near the player's feet")
		_runner.assert_true(dust_root.scale.is_equal_approx(Vector2.ONE), "moving attack displays dust at native runtime scale")
	if dust_sprite != null:
		_runner.assert_true(dust_sprite.visible, "moving attack reveals dust sprite")
		_runner.assert_eq(dust_sprite.frame, 0, "dust animation starts from the first visible frame")


func test_player_scene_includes_fire_power_slash_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("PowerImpact") as Node2D

	_runner.assert_not_null(impact, "player scene includes dash power impact effect root")
	if impact != null:
		_runner.assert_false(impact.visible, "power impact starts hidden")
		var slash_sprite := impact.get_node_or_null("SlashSprite") as Sprite2D
		_runner.assert_not_null(slash_sprite, "power impact uses the supplied fire slash sprite")
		_runner.assert_eq(impact.get_node_or_null("ImpactRing"), null, "power impact no longer uses the old line ring")
		if slash_sprite != null:
			_runner.assert_false(slash_sprite.visible, "power slash sprite starts hidden with the root")
			_runner.assert_eq(slash_sprite.hframes, 9, "power slash sheet has nine animation frames")
			_runner.assert_eq(slash_sprite.texture.resource_path, "res://assets/effects/bat_slash_fire.png", "power slash uses the fire pixel sheet")


func test_power_impact_show_plays_fire_slash_sheet() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("PowerImpact") as Node2D
	_runner.assert_not_null(impact, "player scene includes power impact root")
	if impact == null:
		return

	player._show_power_impact(Vector2.RIGHT, 80.0, 1.6)

	var slash_sprite := impact.get_node_or_null("SlashSprite") as Sprite2D
	_runner.assert_true(impact.visible, "showing a power impact reveals the effect root")
	_runner.assert_not_null(slash_sprite, "showing power impact uses a fire sprite sheet child")
	if slash_sprite != null:
		_runner.assert_true(slash_sprite.visible, "showing power impact reveals the fire slash sprite")
		_runner.assert_eq(slash_sprite.frame, 0, "power slash animation starts from the first frame")
		_runner.assert_eq(slash_sprite.texture.resource_path, "res://assets/effects/bat_slash_fire.png", "power impact uses the fire slash sheet")


func test_slash_effect_state_places_sprite_in_attack_direction() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("build_slash_effect_state"), "player exposes pure slash sprite placement helper")
	if not player.has_method("build_slash_effect_state"):
		player.free()
		return
	var right_state: Dictionary = player.build_slash_effect_state(Vector2.RIGHT, 100.0, 64.0, 1.18)
	var down_state: Dictionary = player.build_slash_effect_state(Vector2.DOWN, 80.0, 64.0, 1.35)
	_runner.assert_true((right_state["position"] as Vector2).x > 0.0, "right-facing slash sits in front of the player")
	_runner.assert_true(is_equal_approx(float(right_state["rotation"]), 0.0), "right-facing slash uses the sheet's default orientation")
	_runner.assert_true((right_state["scale"] as Vector2).x > 1.0, "slash state scales the 64px sheet up")
	_runner.assert_true((down_state["position"] as Vector2).y > 0.0, "down-facing slash follows attack direction")
	_runner.assert_true(
		is_equal_approx((down_state["position"] as Vector2).y, 80.0 * player.swing_vertical_factor * 0.52),
		"down-facing slash uses the same vertical compression as melee hit checks"
	)
	_runner.assert_true(is_equal_approx(float(down_state["rotation"]), PI * 0.5), "down-facing slash rotates with attack direction")
	player.free()


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _count_visible_color_steps(image: Image) -> int:
	var visible_colors := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.01:
				visible_colors[pixel.to_html(true)] = true
	return visible_colors.size()


func _count_visible_alpha_steps(image: Image) -> int:
	var alpha_steps := {}
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.01:
				alpha_steps[snappedf(pixel.a, 0.01)] = true
	return alpha_steps.size()
