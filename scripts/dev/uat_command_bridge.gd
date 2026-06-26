class_name UatCommandBridge
extends Node
## Debug UAT bridge. Polls user:// commands so device checks can press UI by test_id.

const TEST_ID_META := &"test_id"
const UAT_ACTION_META := &"uat_action"

@export var enabled := true
@export var target_root_path := NodePath("..")
@export var command_file_path := "user://uat_commands.jsonl"
@export var poll_interval := 0.1

var _poll_elapsed := 0.0


func _ready() -> void:
	print("[uat] command_file=%s" % ProjectSettings.globalize_path(command_file_path))


func _process(delta: float) -> void:
	if not enabled:
		return
	_poll_elapsed += delta
	if _poll_elapsed < poll_interval:
		return
	_poll_elapsed = 0.0
	_consume_commands()


func press_by_test_id(test_id: String) -> bool:
	return _press_by_meta(TEST_ID_META, test_id)


func press_by_uat_action(uat_action: String) -> bool:
	return _press_by_meta(UAT_ACTION_META, uat_action)


func _consume_commands() -> void:
	if not FileAccess.file_exists(command_file_path):
		return
	var file := FileAccess.open(command_file_path, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()

	var clear_file := FileAccess.open(command_file_path, FileAccess.WRITE)
	if clear_file != null:
		clear_file.store_string("")
		clear_file.close()

	for line: String in content.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			print("[uat] ignored invalid command")
			continue
		_run_command(parsed as Dictionary)


func _run_command(command: Dictionary) -> void:
	if String(command.get("action", "press")) != "press":
		print("[uat] ignored action=%s" % String(command.get("action", "")))
		return

	var ok := false
	var label := ""
	if command.has("test_id"):
		label = "test_id=%s" % String(command["test_id"])
		ok = press_by_test_id(String(command["test_id"]))
	elif command.has("uat_action"):
		label = "uat_action=%s" % String(command["uat_action"])
		ok = press_by_uat_action(String(command["uat_action"]))
	else:
		label = "missing target"
	print("[uat] press %s ok=%s" % [label, str(ok)])


func _press_by_meta(meta_key: StringName, value: String) -> bool:
	var target := _target_root()
	if target == null:
		return false
	return _press_node(_find_by_meta(target, meta_key, value))


func _target_root() -> Node:
	if target_root_path.is_empty():
		return get_tree().current_scene
	var target := get_node_or_null(target_root_path)
	if target != null:
		return target
	return get_tree().current_scene


func _find_by_meta(node: Node, meta_key: StringName, expected_value: String) -> Node:
	if node.get_meta(meta_key, "") == expected_value:
		return node
	for child: Node in node.get_children():
		var found := _find_by_meta(child, meta_key, expected_value)
		if found != null:
			return found
	return null


func _press_node(node: Node) -> bool:
	if node == null:
		return false
	var button := node as BaseButton
	if button != null:
		button.emit_signal("pressed")
		return true

	var action_name := String(node.get_meta(UAT_ACTION_META, ""))
	var target := _target_root()
	if action_name != "" and target != null and target.has_method("perform_uat_action"):
		return bool(target.call("perform_uat_action", action_name))
	return false
