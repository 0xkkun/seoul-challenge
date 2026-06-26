extends Node
## UAT command bridge — device checks press Godot UI by test_id instead of coordinates.

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
	var cleanup := FileAccess.open("user://test_uat_commands.jsonl", FileAccess.WRITE)
	if cleanup != null:
		cleanup.store_string("")
		cleanup.close()


func test_bridge_presses_button_by_test_id_from_command_file() -> void:
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
	bridge.command_file_path = "user://test_uat_commands.jsonl"

	var file := FileAccess.open("user://test_uat_commands.jsonl", FileAccess.WRITE)
	file.store_line(JSON.stringify({"action": "press", "test_id": "dialogue.next_button"}))
	file.close()
	bridge.call("_consume_commands")

	_runner.assert_true(pressed[0], "command file can press a button by test id")


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
