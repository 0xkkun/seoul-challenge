extends Node

const ConfirmModalScene := preload("res://scenes/ui/confirm_modal.tscn")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node
var _modal: ConfirmModal


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	_modal = ConfirmModalScene.instantiate()
	add_child(_modal)


func after_each() -> void:
	if is_instance_valid(_modal):
		_modal.free()
	_modal = null


func test_open_renders_message_and_yes_callback() -> void:
	var counts := {"yes": 0, "no": 0}
	_modal.open(
		"로비로 돌아갈까요? 진행은 자동 저장됩니다",
		func() -> void: counts["yes"] += 1,
		func() -> void: counts["no"] += 1
	)

	_runner.assert_true(_modal.is_open(), "modal opens")
	_runner.assert_false(_modal.is_danger_mode(), "default modal is not danger")
	_runner.assert_eq(_modal.get_message_text(), "로비로 돌아갈까요? 진행은 자동 저장됩니다", "message is rendered")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_modal, ConfirmModal.TEST_ID_YES), "yes exposes test id")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_modal, ConfirmModal.TEST_ID_NO), "no exposes test id")

	_runner.assert_true(UiTestHarness.press_by_uat_action(_modal, ConfirmModal.ACTION_YES), "yes button is pressable by action")
	_runner.assert_false(_modal.is_open(), "yes closes modal")
	_runner.assert_eq(counts["yes"], 1, "yes callback runs once")
	_runner.assert_eq(counts["no"], 0, "no callback does not run")


func test_no_callback_closes_danger_modal() -> void:
	var counts := {"yes": 0, "no": 0}
	_modal.open(
		"런을 포기할까요? 이번 밤 보상은 사라지고 영구 재화는 유지됩니다",
		func() -> void: counts["yes"] += 1,
		func() -> void: counts["no"] += 1,
		true
	)

	_runner.assert_true(_modal.is_danger_mode(), "danger mode is recorded")
	_runner.assert_true(UiTestHarness.press_by_test_id(_modal, ConfirmModal.TEST_ID_NO), "no button is pressable by test id")
	_runner.assert_false(_modal.is_open(), "no closes modal")
	_runner.assert_eq(counts["yes"], 0, "yes callback does not run")
	_runner.assert_eq(counts["no"], 1, "no callback runs once")
