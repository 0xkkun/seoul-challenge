extends Node
## UI 자동화 하네스 — 화면 좌표 없이 test_id / uat_action으로 버튼을 찾고 누른다.

const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_harness_finds_and_presses_button_by_stable_metadata() -> void:
	var root := Node.new()
	var button := Button.new()
	var pressed := [false]
	add_child(root)
	root.add_child(button)
	button.set_meta("test_id", "sample.primary_button")
	button.set_meta("uat_action", "sample.primary")
	button.pressed.connect(func() -> void: pressed[0] = true)

	_runner.assert_eq(UiTestHarness.find_by_test_id(root, "sample.primary_button"), button, "test id로 버튼을 찾는다")
	_runner.assert_true(UiTestHarness.press_by_uat_action(root, "sample.primary"), "uat action으로 버튼을 누른다")
	_runner.assert_true(pressed[0], "하네스 누름은 버튼 pressed 신호를 발생시킨다")


func test_harness_returns_false_for_missing_or_non_button_targets() -> void:
	var root := Node.new()
	var label := Label.new()
	add_child(root)
	root.add_child(label)
	label.set_meta("test_id", "sample.label")

	_runner.assert_false(UiTestHarness.press_by_test_id(root, "missing.button"), "없는 test id는 누르지 않는다")
	_runner.assert_false(UiTestHarness.press_by_test_id(root, "sample.label"), "버튼이 아닌 노드는 누르지 않는다")
