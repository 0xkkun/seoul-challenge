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
	var yes_button := UiTestHarness.find_by_test_id(_modal, ConfirmModal.TEST_ID_YES) as Button
	var no_button := UiTestHarness.find_by_test_id(_modal, ConfirmModal.TEST_ID_NO) as Button
	_runner.assert_not_null(yes_button, "yes exposes test id")
	_runner.assert_not_null(no_button, "no exposes test id")
	_assert_pixel_button_style(yes_button, "yes")
	_assert_pixel_button_style(no_button, "no")

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


func _assert_pixel_button_style(button: Button, label: String) -> void:
	_assert_pixel_button_texture(button.get_theme_stylebox("normal"), PixelButtonStyle.NORMAL_TEXTURE_PATH, "%s normal" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("hover"), PixelButtonStyle.NORMAL_TEXTURE_PATH, "%s hover" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("pressed"), PixelButtonStyle.PRESSED_TEXTURE_PATH, "%s pressed" % label)


func _assert_pixel_button_texture(style: StyleBox, texture_path: String, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses pixel button texture style" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, texture_path, message)
	_runner.assert_eq(texture_style.texture_margin_left, 60.0, "%s left 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_top, 12.0, "%s top 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_right, 60.0, "%s right 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_bottom, 12.0, "%s bottom 9-slice margin" % message)
