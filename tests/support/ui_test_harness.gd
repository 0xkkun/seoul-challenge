class_name UiTestHarness
extends RefCounted
## UI 자동화 하네스. 화면 좌표 대신 안정적인 test_id / uat_action 메타로 노드를 찾는다.

const TEST_ID_META := &"test_id"
const UAT_ACTION_META := &"uat_action"


static func find_by_test_id(root: Node, test_id: String) -> Node:
	return _find_by_meta(root, TEST_ID_META, test_id)


static func find_by_uat_action(root: Node, uat_action: String) -> Node:
	return _find_by_meta(root, UAT_ACTION_META, uat_action)


static func press_by_test_id(root: Node, test_id: String) -> bool:
	return _press_node(find_by_test_id(root, test_id))


static func press_by_uat_action(root: Node, uat_action: String) -> bool:
	return _press_node(find_by_uat_action(root, uat_action))


static func _find_by_meta(node: Node, meta_key: StringName, expected_value: String) -> Node:
	if node.get_meta(meta_key, "") == expected_value:
		return node
	for child: Node in node.get_children():
		var found := _find_by_meta(child, meta_key, expected_value)
		if found != null:
			return found
	return null


static func _press_node(node: Node) -> bool:
	if node == null:
		return false
	var button := node as BaseButton
	if button == null:
		return false
	button.emit_signal("pressed")
	return true
