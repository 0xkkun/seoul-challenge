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

	_runner.assert_eq(target.damage_taken, b.contact_damage, "보스 약공격은 전방 근접 스윙으로 피해를 준다")
	_runner.assert_eq(get_child_count(), child_count_before, "보스 약공격은 원거리 투사체를 생성하지 않는다")
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
	_runner.assert_true(target.damage_taken >= b.contact_damage, "보스 강공격은 몸통 접촉 전 스윙 범위에서 피해를 준다")
	_runner.assert_true(target.global_position.distance_to(b.global_position) > b.contact_range, "테스트 대상은 기존 접촉 판정보다 멀리 있다")
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
