extends Node
## UAT dispatcher — in-process tests press Godot UI by test_id instead of coordinates.

const UatCommandBridge := preload("res://scripts/dev/uat_command_bridge.gd")

class ActionRoot:
	extends Node

	var actions: Array[String] = []

	func perform_uat_action(action_name: String) -> bool:
		actions.append(action_name)
		return true


var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_dispatcher_presses_button_by_test_id() -> void:
	var root := Node.new()
	var button := Button.new()
	var bridge := UatCommandBridge.new()
	var pressed := [false]
	add_child(root)
	root.add_child(button)
	root.add_child(bridge)
	button.set_meta("test_id", "dialogue.next_button")
	button.set_meta("uat_action", "dialogue.next")
	button.pressed.connect(func() -> void: pressed[0] = true)

	_runner.assert_true(bridge.press_by_test_id("dialogue.next_button"), "dispatcher can press a button by test id")
	_runner.assert_true(pressed[0], "test id press emits the button signal")


func test_dispatcher_rejects_hidden_or_disabled_button_targets() -> void:
	var root := Control.new()
	var panel := Control.new()
	var layer := CanvasLayer.new()
	var hidden_button := Button.new()
	var hidden_layer_button := Button.new()
	var disabled_button := Button.new()
	var bridge := UatCommandBridge.new()
	add_child(root)
	root.add_child(panel)
	panel.add_child(hidden_button)
	root.add_child(layer)
	layer.add_child(hidden_layer_button)
	root.add_child(disabled_button)
	root.add_child(bridge)
	hidden_button.set_meta("test_id", "dialogue.hidden_next")
	hidden_layer_button.set_meta("test_id", "dialogue.hidden_layer_next")
	disabled_button.set_meta("test_id", "dialogue.disabled_next")
	panel.visible = false
	layer.visible = false
	disabled_button.disabled = true

	_runner.assert_false(bridge.press_by_test_id("dialogue.hidden_next"), "숨겨진 UI 계층의 버튼은 누르지 않는다")
	_runner.assert_false(bridge.press_by_test_id("dialogue.hidden_layer_next"), "숨겨진 CanvasLayer의 버튼은 누르지 않는다")
	_runner.assert_false(bridge.press_by_test_id("dialogue.disabled_next"), "disabled 버튼은 누르지 않는다")


func test_bridge_falls_back_to_root_uat_action_for_non_button_targets() -> void:
	var root := ActionRoot.new()
	var target := Control.new()
	var bridge := UatCommandBridge.new()
	add_child(root)
	root.add_child(target)
	root.add_child(bridge)
	target.set_meta("test_id", "day_corridor.dialogue.open_button")
	target.set_meta("uat_action", "day_corridor.dialogue.open")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.open_button"), "non-button target can route through root action")
	_runner.assert_eq(root.actions, ["day_corridor.dialogue.open"], "root receives the uat action")


func test_bridge_rejects_hidden_non_button_action_targets() -> void:
	var root := ActionRoot.new()
	var hidden_panel := Control.new()
	var target := Control.new()
	var bridge := UatCommandBridge.new()
	add_child(root)
	root.add_child(hidden_panel)
	hidden_panel.add_child(target)
	root.add_child(bridge)
	target.set_meta("test_id", "day_corridor.dialogue.hidden_open")
	target.set_meta("uat_action", "day_corridor.dialogue.open")
	hidden_panel.visible = false

	_runner.assert_false(bridge.press_by_test_id("day_corridor.dialogue.hidden_open"), "숨겨진 uat action 대상은 실행하지 않는다")
	_runner.assert_eq(root.actions, [], "숨겨진 대상은 root action으로도 전달되지 않는다")
