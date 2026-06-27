extends Node
## #136 공용 피격 반응 — 플래시/깜빡임/복구 타이머 단위 테스트.

const HIT_REACTION_SCRIPT_PATH := "res://scripts/combat/hit_reaction_controller.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func _new_controller() -> Node:
	var script := load(HIT_REACTION_SCRIPT_PATH) as GDScript
	_runner.assert_not_null(script, "피격 반응 컨트롤러 스크립트가 존재해야 한다")
	if script == null:
		return null
	var controller := script.new() as Node
	add_child(controller)
	return controller


func test_trigger_flashes_visual_then_restores_base_modulate() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	var visual := ColorRect.new()
	visual.modulate = Color(0.7, 0.8, 0.9, 1.0)
	add_child(visual)
	controller.call("bind_visual", visual)
	controller.call("trigger", 0.3)
	_runner.assert_true(controller.call("is_active"), "trigger 직후 피격 반응이 활성화된다")
	_runner.assert_true(visual.modulate != Color(0.7, 0.8, 0.9, 1.0), "trigger 직후 시각 상태가 바뀐다")
	controller.call("tick", 0.35)
	_runner.assert_false(controller.call("is_active"), "지속시간이 지나면 비활성화된다")
	_runner.assert_eq(visual.modulate, Color(0.7, 0.8, 0.9, 1.0), "완료 후 원래 modulate 로 복구된다")
	visual.queue_free()
	controller.queue_free()


func test_blink_alpha_uses_tailbound_style_pulse_during_invuln() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	_runner.assert_true(
		is_equal_approx(controller.call("blink_alpha", 0.20, 0.08, 0.45), 0.45),
		"무적 중 일부 프레임은 반투명으로 깜빡인다"
	)
	_runner.assert_true(
		is_equal_approx(controller.call("blink_alpha", 0.15, 0.08, 0.45), 1.0),
		"무적 중 일부 프레임은 원래 alpha 로 돌아온다"
	)
	controller.queue_free()
