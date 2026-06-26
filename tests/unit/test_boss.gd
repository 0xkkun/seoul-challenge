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
