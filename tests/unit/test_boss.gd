extends Node
## #17 최종 보스 — 패턴 선택/돌진/탄막 방향 + 처치 단위 테스트.

const BossScene := preload("res://scenes/enemies/boss.tscn")

var _runner: Node


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
	_runner.assert_eq(b.pick_next_pattern(0), 1, "0→1(돌진→탄막)")
	_runner.assert_eq(b.pick_next_pattern(1), 0, "1→0(탄막→돌진)")
	b.free()


func test_burst_directions_fan_around_aim() -> void:
	var b = BossScene.instantiate()
	var dirs: Array = b.burst_directions(Vector2.RIGHT, 3, PI / 2.0)
	_runner.assert_eq(dirs.size(), 3, "3발 부채꼴")
	_runner.assert_true(is_equal_approx(dirs[1].x, 1.0), "가운데는 조준 방향")
	_runner.assert_true(abs(dirs[0].length() - 1.0) < 0.001, "단위벡터")
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
	var visual := b.get_node("Placeholder") as CanvasItem
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
