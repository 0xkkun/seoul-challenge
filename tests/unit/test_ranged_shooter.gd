extends Node
## #16 잡몹 2종째(원거리) — 카이팅 / 조준 / 발사 간격 / 피격 단위 테스트.

const RangedShooterScene := preload("res://scenes/enemies/ranged_shooter.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_kite_approaches_when_too_far() -> void:
	var e = RangedShooterScene.instantiate()
	# 선호 200, 데드존 20 → 거리 300이면 접근(타겟 방향 +x)
	var v: Vector2 = e.kite_velocity(Vector2.ZERO, Vector2(300.0, 0.0), 200.0, 20.0, 60.0)
	_runner.assert_true(v.x > 0.0, "너무 멀면 타겟 향해 접근")
	_runner.assert_true(is_equal_approx(v.length(), 60.0), "이동 속도 = move_speed")
	e.free()


func test_kite_retreats_when_too_close() -> void:
	var e = RangedShooterScene.instantiate()
	# 거리 100 < 200-20 → 후퇴(타겟 반대 -x)
	var v: Vector2 = e.kite_velocity(Vector2.ZERO, Vector2(100.0, 0.0), 200.0, 20.0, 60.0)
	_runner.assert_true(v.x < 0.0, "너무 가까우면 후퇴")
	e.free()


func test_kite_holds_in_deadzone() -> void:
	var e = RangedShooterScene.instantiate()
	# 거리 205, 밴드 [180,220] 안 → 정지
	var v: Vector2 = e.kite_velocity(Vector2.ZERO, Vector2(205.0, 0.0), 200.0, 20.0, 60.0)
	_runner.assert_true(v == Vector2.ZERO, "선호 사거리 안이면 정지")
	e.free()


func test_aim_points_toward_target() -> void:
	var e = RangedShooterScene.instantiate()
	var d: Vector2 = e.aim_direction(Vector2.ZERO, Vector2(0.0, 10.0))
	_runner.assert_true(is_equal_approx(d.y, 1.0) and is_equal_approx(d.x, 0.0), "타겟 향한 단위 방향")
	e.free()


func test_fires_on_interval() -> void:
	var e = RangedShooterScene.instantiate()
	add_child(e)  # _ready → _fire_timer = fire_interval
	var shots: Array[Vector2] = []
	e.fired.connect(func(_origin, dir): shots.append(dir))

	var fired_early: bool = e.tick_fire(0.1, Vector2.ZERO, Vector2(0.0, 100.0))
	_runner.assert_false(fired_early, "간격 전엔 발사 안 함")
	_runner.assert_eq(shots.size(), 0, "조기 발사 없음")

	var fired_now: bool = e.tick_fire(e.fire_interval, Vector2.ZERO, Vector2(0.0, 100.0))
	_runner.assert_true(fired_now, "간격 경과 시 발사")
	_runner.assert_eq(shots.size(), 1, "fired 1회 방출")
	_runner.assert_true(shots[0].y > 0.0, "발사 방향이 타겟 향함")
	e.free()


func test_dies_after_max_hp_damage() -> void:
	var e = RangedShooterScene.instantiate()
	add_child(e)  # _ready → _hp = max_hp(2)
	var hit := {"defeated": false}
	e.defeated.connect(func(_enemy): hit["defeated"] = true)
	e.take_damage(1)
	_runner.assert_false(hit["defeated"], "1대로는 안 죽음")
	e.call("tick_hit_reaction", e.hit_invuln_time + 0.05)
	e.take_damage(1)
	_runner.assert_true(hit["defeated"], "max_hp(2)만큼 맞으면 defeated 방출")


func test_hit_reaction_blocks_repeat_damage_and_restores_visual() -> void:
	var e = RangedShooterScene.instantiate()
	e.max_hp = 2
	add_child(e)  # _ready → _hp = max_hp
	var visual := e.get_node("Placeholder") as CanvasItem
	var base_modulate := visual.modulate
	var defeated := {"count": 0}
	e.defeated.connect(func(_enemy): defeated["count"] += 1)
	e.take_damage(1)
	_runner.assert_true(e.call("is_hit_invulnerable"), "피격 직후 짧은 무적 상태")
	_runner.assert_true(visual.modulate != base_modulate, "피격 직후 원거리 적 플래시")
	e.take_damage(1)
	_runner.assert_eq(defeated["count"], 0, "무적 중 추가 피해는 무시된다")
	e.call("tick_hit_reaction", e.hit_invuln_time + 0.05)
	_runner.assert_eq(visual.modulate, base_modulate, "무적 종료 후 시각 효과 복구")
	e.take_damage(1)
	_runner.assert_eq(defeated["count"], 1, "무적 종료 후 피해는 적용된다")
