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
	e.take_damage(1)
	_runner.assert_false(hit["defeated"], "2대로는 안 죽음")
	e.take_damage(1)
	_runner.assert_true(hit["defeated"], "max_hp(3)만큼 맞으면 defeated 방출")
