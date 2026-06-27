class_name UatCommandBridge
extends Node
## In-process UAT dispatcher for Godot tests.
##
## Android cannot see Godot node metadata through the native view tree. Real
## device UAT must enter Godot through an explicit debug IPC bridge, not app
## private user:// command files or screen-coordinate taps.

const TEST_ID_META := &"test_id"
const UAT_ACTION_META := &"uat_action"

@export var target_root_path := NodePath("..")


func press_by_test_id(test_id: String) -> bool:
	return _press_by_meta(TEST_ID_META, test_id)


func press_by_uat_action(uat_action: String) -> bool:
	return _press_by_meta(UAT_ACTION_META, uat_action)


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
	if not _is_node_usable(node):
		return false
	var action_name := String(node.get_meta(UAT_ACTION_META, ""))
	var target := _target_root()
	var button := node as BaseButton
	if button != null:
		if button.disabled:
			return false
		if action_name != "" and target != null and target.has_method("perform_uat_action"):
			return bool(target.call("perform_uat_action", action_name))
		button.emit_signal("pressed")
		return true

	if action_name != "" and target != null and target.has_method("perform_uat_action"):
		return bool(target.call("perform_uat_action", action_name))
	return false


func _is_node_usable(node: Node) -> bool:
	var current := node
	while current != null:
		var canvas_layer := current as CanvasLayer
		if canvas_layer != null and not canvas_layer.visible:
			return false
		var canvas_item := current as CanvasItem
		if canvas_item != null and not canvas_item.visible:
			return false
		var control := current as Control
		if control != null and not control.is_visible_in_tree():
			return false
		current = current.get_parent()
	return true
