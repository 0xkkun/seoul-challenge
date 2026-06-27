extends Node
## #11 잡몹(체이서) — 추적 수학 + 피격/처치 단위 테스트.

const ChaserScene := preload("res://scenes/enemies/chaser.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_chase_points_toward_target() -> void:
	var e = ChaserScene.instantiate()
	var v: Vector2 = e.chase_velocity(Vector2.ZERO, Vector2(10.0, 0.0), 50.0)
	_runner.assert_true(v.x > 0.0, "타겟 향해 추적(+x)")
	_runner.assert_true(is_equal_approx(v.length(), 50.0), "추적 속도 = move_speed")
	e.free()


func test_chase_zero_on_same_position() -> void:
	var e = ChaserScene.instantiate()
	var v: Vector2 = e.chase_velocity(Vector2(5.0, 5.0), Vector2(5.0, 5.0), 50.0)
	_runner.assert_true(v == Vector2.ZERO, "같은 위치면 정지")
	e.free()


func test_dies_after_max_hp_damage() -> void:
	var e = ChaserScene.instantiate()
	add_child(e)  # _ready → _hp = max_hp(3)
	var hit := {"defeated": false}
	e.defeated.connect(func(_enemy): hit["defeated"] = true)
	e.take_damage(1)
	e.call("tick_hit_reaction", e.hit_invuln_time + 0.05)
	e.take_damage(1)
	_runner.assert_false(hit["defeated"], "2대로는 안 죽음")
	e.call("tick_hit_reaction", e.hit_invuln_time + 0.05)
	e.take_damage(1)
	_runner.assert_true(hit["defeated"], "max_hp(3)만큼 맞으면 defeated 방출")


func test_death_is_idempotent() -> void:
	var e = ChaserScene.instantiate()
	add_child(e)  # _ready → _hp = max_hp
	var count := {"n": 0}
	e.defeated.connect(func(_enemy): count["n"] += 1)
	e.take_damage(e.max_hp)   # 즉사
	e.take_damage(e.max_hp)   # 사망 후 같은 프레임 추가 피격 시나리오
	_runner.assert_eq(count["n"], 1, "사망 후 추가 피격해도 defeated 는 한 번만")


func test_hit_reaction_blocks_repeat_damage_and_restores_visual() -> void:
	var e = ChaserScene.instantiate()
	e.max_hp = 2
	add_child(e)  # _ready → _hp = max_hp
	var visual := e.get_node("Placeholder") as CanvasItem
	var base_modulate := visual.modulate
	var defeated := {"count": 0}
	e.defeated.connect(func(_enemy): defeated["count"] += 1)
	e.take_damage(1)
	_runner.assert_true(e.has_method("is_hit_invulnerable"), "체이서는 피격 무적 질의 API를 노출한다")
	_runner.assert_true(e.call("is_hit_invulnerable"), "피격 직후 짧은 무적 상태")
	_runner.assert_true(visual.modulate != base_modulate, "피격 직후 플레이스홀더 플래시")
	e.take_damage(1)
	_runner.assert_eq(defeated["count"], 0, "무적 중 추가 피해는 처치로 이어지지 않는다")
	e.call("tick_hit_reaction", e.hit_invuln_time + 0.05)
	_runner.assert_false(e.call("is_hit_invulnerable"), "피격 무적 종료")
	_runner.assert_eq(visual.modulate, base_modulate, "무적 종료 후 시각 효과 복구")
	e.take_damage(1)
	_runner.assert_eq(defeated["count"], 1, "무적 종료 후 피해는 적용된다")
