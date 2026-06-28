extends Node
## #17 최종 보스 — 패턴 선택/돌진/스윙 판정 + 처치 단위 테스트.

const BossScene := preload("res://scenes/enemies/boss.tscn")

var _runner: Node


class DamageTarget extends Node2D:
	var damage_taken := 0

	func take_damage(amount: int) -> void:
		damage_taken += amount


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	AudioManager.reset()


func after_each() -> void:
	AudioManager.reset()


func test_charge_points_toward_target() -> void:
	var b = BossScene.instantiate()
	var v: Vector2 = b.charge_velocity(Vector2.ZERO, Vector2(10.0, 0.0), 100.0)
	_runner.assert_true(v.x > 0.0, "타겟 향해 돌진(+x)")
	_runner.assert_true(is_equal_approx(v.length(), 100.0), "돌진 속도 적용")
	b.free()


func test_pattern_alternates() -> void:
	var b = BossScene.instantiate()
	_runner.assert_eq(b.pick_next_pattern(0), 1, "0→1(돌진→약공격)")
	_runner.assert_eq(b.pick_next_pattern(1), 0, "1→0(약공격→돌진)")
	b.free()


func test_swing_arc_hits_forward_target_only() -> void:
	var b = BossScene.instantiate()
	_runner.assert_true(b.has_method("in_swing_arc"), "보스 스윙 판정은 테스트 가능한 순수 함수로 노출된다")
	if not b.has_method("in_swing_arc"):
		b.free()
		return
	_runner.assert_true(b.in_swing_arc(Vector2.RIGHT, Vector2(80.0, 0.0), 120.0, 1.6), "정면 목표는 스윙에 맞는다")
	_runner.assert_false(b.in_swing_arc(Vector2.RIGHT, Vector2(-20.0, 0.0), 120.0, 1.6), "뒤쪽 목표는 스윙에 맞지 않는다")
	_runner.assert_false(b.in_swing_arc(Vector2.RIGHT, Vector2(140.0, 0.0), 120.0, 1.6), "사거리 밖 목표는 스윙에 맞지 않는다")
	b.free()


func test_strong_attack_hit_ready_waits_for_animation_contact_frame() -> void:
	var b = BossScene.instantiate()
	_runner.assert_true(b.has_method("strong_attack_hit_ready"), "강공격 타격 타이밍은 테스트 가능한 순수 함수로 노출된다")
	if not b.has_method("strong_attack_hit_ready"):
		b.free()
		return
	var fps: float = b.strong_attack_animation_fps
	var hit_frame: int = b.strong_attack_hit_frame
	var hit_time := float(hit_frame) / fps
	_runner.assert_false(b.strong_attack_hit_ready(0.0, hit_frame, fps), "강공격 시작 프레임은 아직 피해 판정 전이다")
	_runner.assert_false(b.strong_attack_hit_ready(hit_time - 0.01, hit_frame, fps), "타격 프레임 직전까지는 피해 판정 전이다")
	_runner.assert_true(b.strong_attack_hit_ready(hit_time, hit_frame, fps), "타격 프레임부터 강공격 피해 판정이 열린다")
	b.free()


func test_boss_pattern_damage_defaults_make_slow_attacks_threatening() -> void:
	var b = BossScene.instantiate()
	_runner.assert_eq(b.contact_damage, 1, "보스 몸통 접촉 피해는 잡몹 수준으로 유지한다")
	_runner.assert_eq(b.weak_attack_damage, 2, "보스 약공격은 잡몹 접촉보다 아프다")
	_runner.assert_eq(b.weak_ground_damage, 2, "보스 약공격 대지 이펙트 피해는 약공격과 같은 2다")
	_runner.assert_eq(b.strong_attack_damage, 3, "보스 강공격은 약공격보다 아프다")
	_runner.assert_eq(b.knockback_resistance, 0.8, "보스는 플레이어 배트 넉백의 80%를 저항한다")
	_runner.assert_true(b.recover_time <= 0.85, "보스 회복 시간은 느슨한 기존 1초보다 짧다")
	_runner.assert_eq(b.telegraph_time, 0.6, "보스 텔레그래프 시간은 읽을 수 있게 유지한다")
	b.free()


func test_dies_at_zero_hp() -> void:
	var b = BossScene.instantiate()
	add_child(b)  # _ready → _hp = max_hp
	var hit := {"d": false}
	b.defeated.connect(func(_x): hit["d"] = true)
	b.take_damage(b.max_hp)
	_runner.assert_true(hit["d"], "max_hp 피해 → defeated(=탈출)")


func test_hit_reaction_blocks_repeat_damage_and_restores_visual() -> void:
	var b = BossScene.instantiate()
	b.max_hp = 2
	add_child(b)
	var visual := b.get_node_or_null("Sprite") as CanvasItem
	_runner.assert_not_null(visual, "보스 피격 플래시는 실제 보스 스프라이트에 적용된다")
	if visual == null:
		return
	var base_modulate := visual.modulate
	var defeated := {"count": 0}
	b.defeated.connect(func(_boss): defeated["count"] += 1)
	b.take_damage(1)
	_runner.assert_true(b.has_method("is_hit_invulnerable"), "보스는 피격 무적 질의 API를 노출한다")
	_runner.assert_true(b.call("is_hit_invulnerable"), "보스도 피격 직후 짧은 무적 상태")
	_runner.assert_true(visual.modulate != base_modulate, "보스 피격 플래시")
	b.take_damage(1)
	_runner.assert_eq(defeated["count"], 0, "무적 중 보스 추가 피해는 무시된다")
	b.call("tick_hit_reaction", b.hit_invuln_time + 0.05)
	_runner.assert_eq(visual.modulate, base_modulate, "무적 종료 후 보스 시각 효과 복구")
	b.take_damage(1)
	_runner.assert_eq(defeated["count"], 1, "무적 종료 후 보스 피해는 적용된다")


func test_weak_attack_is_melee_swing_not_projectile_burst() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0
	var child_count_before := get_child_count()

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)

	_runner.assert_eq(target.damage_taken, b.weak_attack_damage, "보스 약공격은 전방 근접 스윙 피해를 준다")
	_runner.assert_eq(get_child_count(), child_count_before, "보스 약공격은 원거리 투사체를 생성하지 않는다")
	b.queue_free()
	target.queue_free()


func test_boss_contact_damage_stays_lighter_than_pattern_hits() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 12.0

	b.call("_try_contact", target)

	_runner.assert_eq(target.damage_taken, b.contact_damage, "보스 몸통 접촉은 패턴 피해와 분리된 낮은 피해를 유지한다")
	_runner.assert_true(b.contact_damage < b.weak_attack_damage, "약공격은 몸통 접촉보다 더 위협적이다")
	b.queue_free()
	target.queue_free()


func test_weak_attack_emits_boss_hit_camera_feedback() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	var events: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		events.append(payload)
	EventBus.combat_feedback.connect(callback)
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)

	EventBus.combat_feedback.disconnect(callback)
	_runner.assert_eq(events.size(), 1, "보스 약공격 피격은 카메라 피드백 이벤트를 발신한다")
	if events.size() == 1:
		var payload := events[0]
		_runner.assert_eq(payload.get("kind", &""), &"boss_hit", "보스 피격 피드백 kind를 사용한다")
		_runner.assert_eq(payload.get("attack", &""), &"weak_attack", "약공격 피드백 종류를 구분한다")
		_runner.assert_eq(int(payload.get("damage", 0)), b.weak_attack_damage, "피드백 payload에 약공격 피해량을 싣는다")
		_runner.assert_eq(float(payload.get("intensity", 0.0)), b.weak_attack_feedback_intensity, "약공격 카메라 피드백 강도를 싣는다")
		_runner.assert_eq(payload.get("direction", Vector2.ZERO), Vector2.RIGHT, "약공격 피드백은 피격 방향을 싣는다")
	b.queue_free()
	target.queue_free()


func test_weak_attack_plays_slam_then_ground_spike_sfx() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"boss_weak_slam"], "보스 약공격 시작 시에는 내려찍기 준비 SFX만 재생한다")
	b.call("_tick_weak_attack_ground_effects", float(b.weak_attack_ground_effect_frame) / b.weak_attack_animation_fps)
	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[&"boss_weak_slam", &"boss_weak_ground_spike"],
		"첫 대지 이펙트가 솟는 프레임에 지면 솟음 SFX를 재생한다"
	)
	b.call("_tick_weak_attack_ground_effects", b.weak_attack_ground_followup_delay)
	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[&"boss_weak_slam", &"boss_weak_ground_spike", &"boss_weak_ground_spike"],
		"두 번째 대지 이펙트도 이어서 지면 솟음 SFX를 재생한다"
	)
	b.queue_free()
	target.queue_free()


func test_weak_attack_plays_ground_effect_without_wound_effect() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 80.0
	var ground := b.get_node_or_null("GroundImpactEffect") as AnimatedSprite2D
	var ground_followup := b.get_node_or_null("GroundImpactEffectFollowup") as AnimatedSprite2D
	var wound := b.get_node_or_null("WoundSlashEffect") as AnimatedSprite2D
	_runner.assert_not_null(ground, "보스 약공격은 대지 이펙트 노드를 가진다")
	_runner.assert_not_null(ground_followup, "보스 약공격은 두 번째 대지 이펙트 노드를 가진다")
	_runner.assert_not_null(wound, "보스 강공격은 상처 이펙트 노드를 가진다")
	if ground == null or ground_followup == null or wound == null:
		b.queue_free()
		target.queue_free()
		return

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)

	_runner.assert_false(ground.visible, "보스 약공격은 방망이를 드는 프레임에 대지 이펙트를 먼저 재생하지 않는다")
	_runner.assert_false(ground_followup.visible, "두 번째 대지 이펙트도 약공격 시작 프레임에는 숨긴다")

	b.call("_tick_weak_attack_ground_effects", (float(b.weak_attack_ground_effect_frame) / b.weak_attack_animation_fps) - 0.01)
	_runner.assert_false(ground.visible, "보스 약공격은 방망이가 내려오기 전까지 대지 이펙트를 재생하지 않는다")

	b.call("_tick_weak_attack_ground_effects", 0.02)
	_runner.assert_true(ground.visible, "보스 약공격은 방망이를 내려치는 프레임에 첫 대지 이펙트를 재생한다")
	_runner.assert_eq(ground.animation, &"impact", "대지 이펙트는 임팩트 애니메이션을 사용한다")
	_runner.assert_true(ground.is_playing(), "대지 이펙트 애니메이션이 재생 중이다")
	_runner.assert_eq(ground.frame, 0, "대지 이펙트는 첫 프레임부터 재생한다")
	_runner.assert_true(ground.scale.x >= 4.5, "대지 이펙트는 보스 확대 비율을 반영해 충분히 크게 재생한다")
	_assert_vector2_approx(ground.scale, Vector2(4.59, 4.59), 0.01, "대지 이펙트 스케일은 보스 visual scale 기반이다")
	_assert_vector2_approx(ground.position, Vector2(102.6, 56.7), 0.01, "대지 이펙트는 오른쪽 약공격 전방 발밑에 놓인다")
	_runner.assert_false(ground_followup.visible, "두 번째 대지 이펙트는 첫 대지보다 늦게 솟아난다")

	b.call("_tick_weak_attack_ground_effects", b.weak_attack_ground_followup_delay)
	_runner.assert_true(ground_followup.visible, "첫 대지 뒤에 두 번째 대지 이펙트가 이어서 솟아난다")
	_runner.assert_eq(ground_followup.animation, &"impact", "두 번째 대지 이펙트도 임팩트 애니메이션을 사용한다")
	_runner.assert_true(ground_followup.is_playing(), "두 번째 대지 이펙트 애니메이션이 재생 중이다")
	_runner.assert_eq(ground_followup.frame, 0, "두 번째 대지 이펙트도 첫 프레임부터 재생한다")
	_assert_vector2_approx(ground_followup.scale, Vector2(4.59, 4.59), 0.01, "두 번째 대지 이펙트 스케일도 보스 visual scale 기반이다")
	_assert_vector2_approx(ground_followup.position, Vector2(286.2, 56.7), 0.01, "두 번째 대지 이펙트는 투명 여백을 고려해 첫 대지 쪽으로 붙는다")
	_runner.assert_true(
		absf(ground_followup.position.x - ground.position.x) < 48.0 * ground.scale.x,
		"두 대지 이펙트 중심 간격은 확대된 대지 폭보다 작아 시각적 빈틈을 없앤다"
	)
	_runner.assert_false(wound.visible, "보스 약공격은 강공격 상처 이펙트를 섞지 않는다")
	b.queue_free()
	target.queue_free()


func test_ground_effect_hitbox_checks_effect_footprint() -> void:
	var b = BossScene.instantiate()
	_runner.assert_true(
		b.ground_effect_hits(Vector2(100.0, 50.0), Vector2(205.0, 96.0), Vector2(110.0, 50.0)),
		"대지 피해 판정은 이펙트 가로 폭과 높이 안 목표를 맞춘다"
	)
	_runner.assert_false(
		b.ground_effect_hits(Vector2(100.0, 50.0), Vector2(222.0, 50.0), Vector2(110.0, 50.0)),
		"대지 피해 판정은 이펙트 가로 폭 밖 목표를 제외한다"
	)
	_runner.assert_false(
		b.ground_effect_hits(Vector2(100.0, 50.0), Vector2(100.0, 108.0), Vector2(110.0, 50.0)),
		"대지 피해 판정은 이펙트 높이 밖 목표를 제외한다"
	)
	b.free()


func test_weak_ground_effects_damage_once_across_two_spikes() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 240.0

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)
	_runner.assert_eq(target.damage_taken, 0, "대지 판정 테스트는 기존 근접 스윙 사거리 밖에서 시작한다")

	target.global_position = Vector2(102.6, 56.7)
	b.call("_tick_weak_attack_ground_effects", float(b.weak_attack_ground_effect_frame) / b.weak_attack_animation_fps)
	_runner.assert_eq(target.damage_taken, b.weak_ground_damage, "첫 대지 이펙트 위치에 서 있으면 첫 대지 피해를 받는다")

	target.global_position = Vector2(286.2, 56.7)
	b.call("_tick_weak_attack_ground_effects", b.weak_attack_ground_followup_delay)
	_runner.assert_eq(target.damage_taken, b.weak_ground_damage, "한 번 대지 피해를 받았으면 두 번째 대지는 추가 피해를 주지 않는다")
	b.queue_free()
	target.queue_free()


func test_weak_ground_followup_can_hit_once_if_first_spike_misses() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 240.0

	b.set("_pattern_index", 1)
	b.call("_begin_pattern", target)
	target.global_position = Vector2(0.0, -220.0)
	b.call("_tick_weak_attack_ground_effects", float(b.weak_attack_ground_effect_frame) / b.weak_attack_animation_fps)
	_runner.assert_eq(target.damage_taken, 0, "첫 대지 이펙트 반경 밖에 있으면 아직 피해를 받지 않는다")

	target.global_position = Vector2(286.2, 56.7)
	b.call("_tick_weak_attack_ground_effects", b.weak_attack_ground_followup_delay)

	_runner.assert_eq(target.damage_taken, b.weak_ground_damage, "첫 대지를 피했으면 두 번째 대지 이펙트 위치에서 한 번 피해를 받는다")
	b.queue_free()
	target.queue_free()


func test_strong_attack_hits_before_body_overlap() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.target_group = &"boss_timing_test_player"
	target.add_to_group(&"boss_timing_test_player")
	b.charge_speed = 0.0
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 120.0

	b.set("_pattern_index", 0)
	b.call("_begin_pattern", target)

	_runner.assert_eq(target.damage_taken, 0, "보스 강공격은 애니메이션 시작 즉시 피해를 주지 않는다")
	b.call("_tick_strong_attack_hit", target, (float(b.strong_attack_hit_frame) / b.strong_attack_animation_fps) - 0.01)
	_runner.assert_eq(target.damage_taken, 0, "보스 강공격은 방망이가 내려오기 전까지 피해를 주지 않는다")
	b.call("_tick_strong_attack_hit", target, 0.02)
	_runner.assert_eq(target.damage_taken, b.strong_attack_damage, "보스 강공격은 몸통 접촉 전 강공격 피해를 준다")
	_runner.assert_true(target.global_position.distance_to(b.global_position) > b.contact_range, "테스트 대상은 기존 접촉 판정보다 멀리 있다")
	b.queue_free()
	target.queue_free()


func test_strong_attack_emits_stronger_boss_hit_camera_feedback_on_contact_frame() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	var events: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		events.append(payload)
	EventBus.combat_feedback.connect(callback)
	add_child(b)
	add_child(target)
	b.target_group = &"boss_timing_test_player"
	target.add_to_group(&"boss_timing_test_player")
	b.charge_speed = 0.0
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 120.0

	b.set("_pattern_index", 0)
	b.call("_begin_pattern", target)
	b.call("_tick_strong_attack_hit", target, float(b.strong_attack_hit_frame) / b.strong_attack_animation_fps)

	EventBus.combat_feedback.disconnect(callback)
	_runner.assert_eq(target.damage_taken, b.strong_attack_damage, "강공격 임팩트 프레임은 강공격 피해를 준다")
	_runner.assert_eq(events.size(), 1, "보스 강공격 피격은 카메라 피드백 이벤트를 발신한다")
	if events.size() == 1:
		var payload := events[0]
		_runner.assert_eq(payload.get("kind", &""), &"boss_hit", "보스 피격 피드백 kind를 사용한다")
		_runner.assert_eq(payload.get("attack", &""), &"strong_attack", "강공격 피드백 종류를 구분한다")
		_runner.assert_eq(int(payload.get("damage", 0)), b.strong_attack_damage, "피드백 payload에 강공격 피해량을 싣는다")
		_runner.assert_eq(float(payload.get("intensity", 0.0)), b.strong_attack_feedback_intensity, "강공격 카메라 피드백 강도를 싣는다")
		_runner.assert_true(
			float(payload.get("intensity", 0.0)) > b.weak_attack_feedback_intensity,
			"강공격 카메라 피드백은 약공격보다 강하다"
		)
		_runner.assert_eq(payload.get("direction", Vector2.ZERO), Vector2.RIGHT, "강공격 피드백은 돌진 방향을 싣는다")
	b.queue_free()
	target.queue_free()


func test_strong_attack_plays_wound_effect_on_contact_frame_only() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.target_group = &"boss_timing_test_player"
	target.add_to_group(&"boss_timing_test_player")
	b.charge_speed = 0.0
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 120.0
	var ground := b.get_node_or_null("GroundImpactEffect") as AnimatedSprite2D
	var wound := b.get_node_or_null("WoundSlashEffect") as AnimatedSprite2D
	_runner.assert_not_null(ground, "보스 약공격은 대지 이펙트 노드를 가진다")
	_runner.assert_not_null(wound, "보스 강공격은 상처 이펙트 노드를 가진다")
	if ground == null or wound == null:
		b.queue_free()
		target.queue_free()
		return

	b.set("_pattern_index", 0)
	b.call("_begin_pattern", target)
	_runner.assert_false(wound.visible, "보스 강공격 시작 프레임에는 상처 이펙트를 아직 재생하지 않는다")
	_runner.assert_false(ground.visible, "보스 강공격은 약공격 대지 이펙트를 섞지 않는다")

	b.call("_tick_strong_attack_hit", target, (float(b.strong_attack_hit_frame) / b.strong_attack_animation_fps) - 0.01)
	_runner.assert_false(wound.visible, "보스 강공격은 방망이가 닿기 전 상처 이펙트를 재생하지 않는다")

	b.call("_tick_strong_attack_hit", target, 0.02)
	_runner.assert_true(wound.visible, "보스 강공격 임팩트 프레임에 상처 이펙트를 재생한다")
	_runner.assert_eq(wound.animation, &"impact", "상처 이펙트는 임팩트 애니메이션을 사용한다")
	_runner.assert_true(wound.is_playing(), "상처 이펙트 애니메이션이 재생 중이다")
	_runner.assert_eq(wound.frame, 0, "상처 이펙트는 첫 프레임부터 재생한다")
	_assert_vector2_approx(wound.scale, Vector2(1.6875, 1.6875), 0.01, "상처 이펙트 스케일은 보스 visual scale 기반이다")
	_assert_vector2_approx(wound.position, Vector2(116.1, 0.0), 0.01, "상처 이펙트는 오른쪽 강공격 타격 중심 앞에 놓인다")
	b.queue_free()
	target.queue_free()


func test_strong_attack_plays_strong_attack_sfx_before_hit_frame() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.target_group = &"boss_timing_test_player"
	target.add_to_group(&"boss_timing_test_player")
	b.charge_speed = 0.0
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 120.0

	b.set("_pattern_index", 0)
	b.call("_begin_pattern", target)

	_runner.assert_eq(AudioManager.get_played_sfx(), [&"boss_strong_attack"], "보스 강공격 시작 시 강공격 SFX를 1회 재생한다")
	_runner.assert_eq(target.damage_taken, 0, "강공격 사운드는 임팩트 프레임 전 피해 판정을 앞당기지 않는다")
	b.queue_free()
	target.queue_free()


func test_strong_attack_hit_window_closes_after_contact_frame() -> void:
	var b = BossScene.instantiate()
	var target := DamageTarget.new()
	add_child(b)
	add_child(target)
	b.target_group = &"boss_timing_test_player"
	target.add_to_group(&"boss_timing_test_player")
	b.charge_speed = 0.0
	b.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 220.0

	b.set("_pattern_index", 0)
	b.call("_begin_pattern", target)
	b.call("_tick_strong_attack_hit", target, float(b.strong_attack_hit_frame) / b.strong_attack_animation_fps)
	_runner.assert_eq(target.damage_taken, 0, "강공격 임팩트 프레임에 범위 밖이면 피해를 받지 않는다")

	target.global_position = Vector2.RIGHT * 120.0
	b.call("_tick_strong_attack_hit", target, 0.2)
	_runner.assert_eq(target.damage_taken, 0, "강공격 임팩트 프레임을 놓친 뒤 늦게 들어와도 피해 판정은 다시 열리지 않는다")
	b.queue_free()
	target.queue_free()


func _assert_vector2_approx(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	_runner.assert_true(actual.distance_to(expected) <= tolerance, "%s: expected %s, got %s" % [message, expected, actual])
