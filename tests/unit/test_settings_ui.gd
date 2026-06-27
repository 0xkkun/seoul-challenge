extends Node

const SettingsUIScene := preload("res://scenes/ui/settings_ui.tscn")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

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


func test_settings_ui_starts_hidden_and_opens_with_three_toggles() -> void:
	_runner.assert_false(_settings_ui.is_open(), "settings popup starts closed")

	_settings_ui.open()

	_runner.assert_true(_settings_ui.is_open(), "settings popup opens")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_BGM_TOGGLE), "BGM toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_SFX_TOGGLE), "SFX toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_HAPTIC_TOGGLE), "haptic toggle exists")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(_settings_ui, SettingsUI.TEST_ID_CLOSE), "close button exists")


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


func test_settings_ui_close_button_starts_close_animation() -> void:
	_settings_ui.open()

	_runner.assert_true(UiTestHarness.press_by_uat_action(_settings_ui, SettingsUI.ACTION_CLOSE), "close action is pressable")

	_runner.assert_true(_settings_ui.is_closing(), "close button starts the close animation")


func test_settings_ui_can_close_immediately_for_contract_checks() -> void:
	_settings_ui.open()

	_settings_ui.close(true)

	_runner.assert_false(_settings_ui.is_open(), "immediate close hides popup")
