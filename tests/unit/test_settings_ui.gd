extends Node

const SettingsUIScene := preload("res://scenes/ui/settings_ui.tscn")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node
var _settings_ui: SettingsUI


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Settings.reset_defaults()
	_settings_ui = SettingsUIScene.instantiate() as SettingsUI
	add_child(_settings_ui)


func after_each() -> void:
	if is_instance_valid(_settings_ui):
		_settings_ui.free()
	_settings_ui = null
	Settings.reset_defaults()


func test_settings_ui_starts_hidden_and_opens_with_four_safe_toggles() -> void:
	_runner.assert_false(_settings_ui.is_open(), "settings popup starts closed")

	_settings_ui.open()

	_runner.assert_true(_settings_ui.is_open(), "settings popup opens")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_BGM_TOGGLE), "BGM toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_SFX_TOGGLE), "SFX toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_HAPTIC_TOGGLE), "haptic toggle exists")
	var motion_toggle := UiTestHarness.find_by_test_id(_settings_ui, "settings.reduced_motion_toggle")
	_runner.assert_not_null(motion_toggle, "reduced motion toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_CLOSE), "close button exists")
	if motion_toggle == null:
		return
	var panel := _settings_ui.get_node("Root/Panel") as Control
	var reference_size := MobileSafeArea.DESIGN_VIEWPORT
	var panel_rect := Rect2(
		Vector2(
			reference_size.x * panel.anchor_left + panel.offset_left,
			reference_size.y * panel.anchor_top + panel.offset_top
		),
		Vector2(
			reference_size.x * (panel.anchor_right - panel.anchor_left) + panel.offset_right - panel.offset_left,
			reference_size.y * (panel.anchor_bottom - panel.anchor_top) + panel.offset_bottom - panel.offset_top
		)
	)
	_runner.assert_true(MobileSafeArea.meets_landscape_minimum(panel_rect), "four-row settings panel stays inside 960x540 safe area: %s" % panel_rect)
	var motion_row := _settings_ui.get_node_or_null("Root/Panel/Margin/Stack/Rows/ReducedMotionRow") as Control
	_runner.assert_not_null(motion_row, "reduced motion row is named predictably")
	if motion_row == null:
		return
	var labels := motion_row.find_children("*", "Label", true, false)
	_runner.assert_true(not labels.is_empty(), "reduced motion row has a visible label")
	if not labels.is_empty():
		_runner.assert_eq((labels[0] as Label).text, "온보딩 모션 줄이기", "reduced motion label uses direct language")


func test_settings_ui_toggles_bgm_sfx_and_haptic() -> void:
	_settings_ui.open()

	_runner.assert_eq(
		_settings_ui.get_toggle_icon_path(Settings.KEY_BGM_ENABLED),
		"res://assets/ui/icons/settings/sound.png",
		"BGM starts with the sound-on icon"
	)
	_runner.assert_true(UiTestHarness.press_by_uat_action(_settings_ui, SettingsUI.ACTION_BGM_TOGGLE), "BGM toggle is pressable")
	_runner.assert_false(Settings.is_bgm_enabled(), "BGM toggle updates setting")
	_runner.assert_eq(_settings_ui.get_toggle_text(Settings.KEY_BGM_ENABLED), "OFF", "BGM toggle label updates")
	_runner.assert_eq(
		_settings_ui.get_toggle_icon_path(Settings.KEY_BGM_ENABLED),
		"res://assets/ui/icons/settings/sound_off.png",
		"BGM off switches to the sound-off icon"
	)

	_runner.assert_true(UiTestHarness.press_by_uat_action(_settings_ui, SettingsUI.ACTION_SFX_TOGGLE), "SFX toggle is pressable")
	_runner.assert_false(Settings.is_sfx_enabled(), "SFX toggle updates setting")
	_runner.assert_eq(_settings_ui.get_toggle_text(Settings.KEY_SFX_ENABLED), "OFF", "SFX toggle label updates")
	_runner.assert_eq(
		_settings_ui.get_toggle_icon_path(Settings.KEY_SFX_ENABLED),
		"res://assets/ui/icons/settings/sound_off.png",
		"SFX off switches to the shared sound-off icon"
	)

	_runner.assert_true(UiTestHarness.press_by_uat_action(_settings_ui, SettingsUI.ACTION_HAPTIC_TOGGLE), "haptic toggle is pressable")
	_runner.assert_false(Settings.is_haptic_enabled(), "haptic toggle updates setting")
	_runner.assert_eq(_settings_ui.get_toggle_text(Settings.KEY_HAPTIC_ENABLED), "OFF", "haptic toggle label updates")
	_runner.assert_eq(
		_settings_ui.get_toggle_icon_path(Settings.KEY_HAPTIC_ENABLED),
		"res://assets/ui/icons/settings/haptic_off.png",
		"haptic off switches to the haptic-off icon"
	)

	_runner.assert_eq(_settings_ui.get_toggle_text("reduced_motion"), "OFF", "reduced motion starts disabled")
	var pressed := UiTestHarness.press_by_uat_action(_settings_ui, "settings.reduced_motion.toggle")
	_runner.assert_true(pressed, "reduced motion action is pressable")
	if not pressed or not Settings.has_method("is_reduced_motion_enabled"):
		return
	_runner.assert_true(bool(Settings.call("is_reduced_motion_enabled")), "reduced motion toggle updates setting")
	_runner.assert_eq(_settings_ui.get_toggle_text("reduced_motion"), "ON", "reduced motion row renders enabled state")


func test_settings_ui_close_button_starts_close_animation() -> void:
	_settings_ui.open()

	_runner.assert_true(UiTestHarness.press_by_uat_action(_settings_ui, SettingsUI.ACTION_CLOSE), "close action is pressable")

	_runner.assert_true(_settings_ui.is_closing(), "close button starts the close animation")


func test_settings_ui_can_close_immediately_for_contract_checks() -> void:
	_settings_ui.open()

	_settings_ui.close(true)

	_runner.assert_false(_settings_ui.is_open(), "immediate close hides popup")
