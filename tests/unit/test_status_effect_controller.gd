extends Node
## #51 공용 상태이상 컨트롤러 — 시간형 디버프/버프의 최소 전투 계약.

const STATUS_SCRIPT_PATH := "res://scripts/combat/status_effect_controller.gd"

var _runner: Node


class DamageSink:
	extends Node

	var total_damage := 0

	func take_damage(amount: int) -> void:
		total_damage += amount


func _set_runner(runner: Node) -> void:
	_runner = runner


func _new_controller() -> Node:
	var script := load(STATUS_SCRIPT_PATH) as GDScript
	_runner.assert_not_null(script, "상태이상 컨트롤러 스크립트가 존재해야 한다")
	if script == null:
		return null
	var controller := script.new() as Node
	add_child(controller)
	return controller


func test_slow_uses_strongest_multiplier_and_expires() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	controller.call("apply_effect", &"slow", 1.0, {"speed_multiplier": 0.5})
	controller.call("apply_effect", &"slow", 1.0, {"speed_multiplier": 0.8})
	_runner.assert_true(controller.call("has_effect", &"slow"), "둔화가 활성화된다")
	_runner.assert_true(is_equal_approx(controller.call("get_speed_multiplier"), 0.5), "가장 강한 둔화 배속을 사용한다")
	controller.call("tick", 1.1)
	_runner.assert_false(controller.call("has_effect", &"slow"), "지속시간이 지나면 둔화가 사라진다")
	_runner.assert_true(is_equal_approx(controller.call("get_speed_multiplier"), 1.0), "둔화가 없으면 기본 배속")
	controller.queue_free()


func test_stun_blocks_actions_and_root_only_blocks_movement() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	controller.call("apply_effect", &"stun", 1.0)
	_runner.assert_true(controller.call("blocks_movement"), "기절은 이동을 막는다")
	_runner.assert_true(controller.call("blocks_actions"), "기절은 행동을 막는다")
	controller.call("clear_effect", &"stun")
	controller.call("apply_effect", &"root", 1.0)
	_runner.assert_true(controller.call("blocks_movement"), "속박은 이동을 막는다")
	_runner.assert_false(controller.call("blocks_actions"), "속박은 행동은 허용한다")
	controller.queue_free()


func test_poison_ticks_damage_on_interval() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	var target := DamageSink.new()
	add_child(target)
	controller.call("apply_effect", &"poison", 2.0, {"damage": 2, "tick_interval": 0.5})
	controller.call("tick", 0.49, target)
	_runner.assert_eq(target.total_damage, 0, "틱 간격 전에는 독 피해가 없다")
	controller.call("tick", 0.01, target)
	_runner.assert_eq(target.total_damage, 2, "틱 간격 도달 시 독 피해")
	controller.call("tick", 0.5, target)
	_runner.assert_eq(target.total_damage, 4, "독은 지속 중 반복 피해를 준다")
	target.queue_free()
	controller.queue_free()


func test_cleanse_removes_negative_effects_and_tracks_short_buff() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	controller.call("apply_effect", &"slow", 5.0, {"speed_multiplier": 0.5})
	controller.call("apply_effect", &"root", 5.0)
	controller.call("apply_effect", &"cleanse", 0.25)
	_runner.assert_false(controller.call("has_effect", &"slow"), "정화는 둔화를 제거한다")
	_runner.assert_false(controller.call("has_effect", &"root"), "정화는 속박을 제거한다")
	_runner.assert_true(controller.call("has_effect", &"cleanse"), "정화 직후 짧은 버프 상태가 남는다")
	controller.call("tick", 0.3)
	_runner.assert_false(controller.call("has_effect", &"cleanse"), "정화 버프도 시간 경과로 만료된다")
	controller.queue_free()
