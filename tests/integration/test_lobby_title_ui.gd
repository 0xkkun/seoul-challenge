extends Node

const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	AudioManager.reset()


func after_each() -> void:
	AudioManager.reset()


func test_lobby_title_scene_uses_title_assets_and_menu_contract() -> void:
	var packed := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := packed.instantiate()
	add_child(lobby)

	var background := lobby.get_node("Background") as TextureRect
	var full_overlay := lobby.get_node("FullOverlay") as ColorRect
	var title_logo := lobby.get_node("LogoPane/TitleLogo") as TextureRect
	var tagline_label := lobby.get_node("LogoPane/TaglineLabel") as Label
	var start_button := lobby.get_node("%StartButton") as Button
	var settings_button := lobby.get_node("%SettingsButton") as Button
	var settings_ui := lobby.get_node("%SettingsUI") as SettingsUI
	var status_label := lobby.get_node("%StatusLabel") as Label

	_runner.assert_eq(background.texture.resource_path, "res://assets/backgrounds/lobby/title_lobby_bg.png", "lobby background uses title art")
	_runner.assert_eq(full_overlay.anchor_right, 1.0, "overlay spans full width")
	_runner.assert_eq(full_overlay.anchor_bottom, 1.0, "overlay spans full height")
	_runner.assert_eq(title_logo.texture.resource_path, "res://assets/branding/title_logo.png", "lobby uses official title logo")
	_runner.assert_eq(start_button.text, "게임 시작", "start button is localized")
	_runner.assert_eq(settings_button.text, "설정", "settings button is localized")
	_runner.assert_eq(tagline_label.text, "낮에 모은 기억으로 밤의 궁에 들어간다.", "title screen states the core loop")
	_runner.assert_eq(start_button.focus_mode, Control.FOCUS_NONE, "mobile lobby start button does not render focus chrome")
	_runner.assert_eq(settings_button.focus_mode, Control.FOCUS_NONE, "mobile lobby settings button does not render focus chrome")
	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.LOBBY_BGM_DEFAULT, "lobby starts the default BGM")
	_runner.assert_eq(AudioManager.get_current_bgm_path(), "res://assets/audio/bgm/lobby_bgm_default.ogg", "lobby default BGM path is stable")
	_runner.assert_true(AudioManager.has_bgm(AudioManager.LOBBY_BGM_ALTERNATE), "alternate lobby BGM is registered")
	_runner.assert_true(ResourceLoader.exists(AudioManager.get_bgm_stream_path(AudioManager.LOBBY_BGM_DEFAULT)), "default lobby BGM resource exists")
	_runner.assert_true(ResourceLoader.exists(AudioManager.get_bgm_stream_path(AudioManager.LOBBY_BGM_ALTERNATE)), "alternate lobby BGM resource exists")
	_assert_lobby_button_style(start_button, "start")
	_assert_lobby_button_style(settings_button, "settings")
	_assert_lobby_button_texture(start_button.get_theme_stylebox("disabled"), "res://assets/ui/buttons/lobby/lobby_button_pressed.png", "start disabled button holds pressed texture during transition")
	_runner.assert_eq(start_button.get_theme_color("font_disabled_color"), start_button.get_theme_color("font_pressed_color"), "start disabled text keeps pressed color during transition")
	_assert_lobby_button_texture(settings_button.get_theme_stylebox("disabled"), "res://assets/ui/buttons/lobby/lobby_button_normal.png", "settings disabled button keeps lobby button texture")
	_runner.assert_eq(start_button.get_meta("uat_action"), "lobby.start", "start uat action is stable")
	_runner.assert_false(settings_button.disabled, "settings is available from the lobby")
	_runner.assert_eq(settings_button.get_meta("uat_action"), "lobby.settings", "settings exposes a stable action")
	_runner.assert_false(settings_ui.is_open(), "settings popup starts closed")
	_runner.assert_true(_is_signal_connected_to_method(settings_button.pressed, lobby, "_on_settings_pressed"), "settings button is wired to popup handler")
	_runner.assert_true(_is_signal_connected_to_method(start_button.pressed, lobby, "_on_start_pressed"), "start button is wired to title start handler")
	_runner.assert_true(lobby.has_method("_go_to_day_lobby"), "start transition is deferred for touch input")
	_runner.assert_eq(SceneTransition.get_day_lobby_scene_path(), "res://scenes/dev/day_corridor_movement_test.tscn", "start destination is the day lobby")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_day_lobby_scene_path()), "day lobby scene resource exists")
	_runner.assert_eq(SceneTransition.get_locker_maintenance_scene_path(), "res://scenes/ui/locker_maintenance.tscn", "locker maintenance scene path is exposed")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_locker_maintenance_scene_path()), "locker maintenance scene resource exists")
	_runner.assert_eq(SceneTransition.get_night_map_select_scene_path(), "res://scenes/ui/night_map_select.tscn", "night map select scene path is exposed")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_night_map_select_scene_path()), "night map select scene resource exists")
	_runner.assert_false(status_label.visible, "status copy is hidden on title screen")
	_runner.assert_true(lobby.has_node("LogoPane/TaglineLabel"), "tagline copy frames the title screen")
	_runner.assert_false(lobby.has_node("MenuPane/FocusHint"), "input hint copy is removed")

	lobby.queue_free()


func test_first_night_config_starts_baseball_onboarding_without_bat() -> void:
	var packed := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := packed.instantiate()
	add_child(lobby)

	var config: Dictionary = lobby.call("_first_night_config")
	_runner.assert_eq(config.get("source", ""), "intro", "first launch still starts from the intro handoff")
	_runner.assert_eq(config.get("stage_id", &""), &"gyeongbokgung", "onboarding uses the MVP palace stage")
	_runner.assert_eq(config.get("stage_name", ""), "경복궁", "onboarding map label stays player-facing")
	_runner.assert_eq(
		config.get(SceneTransition.RUN_CONFIG_ONBOARDING_KIND, &""),
		SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
		"first launch starts the baseball captain onboarding run"
	)
	_runner.assert_false(config.has(SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID), "bat is awarded after onboarding, not before it")

	lobby.queue_free()


func test_lobby_settings_button_opens_settings_popup() -> void:
	var packed := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := packed.instantiate()
	add_child(lobby)

	var settings_ui := lobby.get_node("%SettingsUI") as SettingsUI

	_runner.assert_true(UiTestHarness.press_by_uat_action(lobby, "lobby.settings"), "settings action opens popup")
	_runner.assert_true(lobby.is_settings_open(), "lobby reports settings popup open")
	_runner.assert_true(settings_ui.is_open(), "settings popup is visible")

	lobby.queue_free()


func test_lobby_background_cover_crops_from_bottom() -> void:
	var packed := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := packed.instantiate()
	add_child(lobby)

	var cover_rect: Rect2 = lobby.get_background_cover_rect(Vector2(2670.0, 1200.0), Vector2(1680.0, 945.0))

	_runner.assert_eq(cover_rect.position.y, 0.0, "background cover pins the top edge")
	_runner.assert_true(cover_rect.size.y > 1200.0, "background cover crops extra height")
	_runner.assert_true(cover_rect.end.y > 1200.0, "extra background height is cropped below the viewport")

	lobby.queue_free()


func test_mobile_touch_events_press_gui_buttons() -> void:
	_runner.assert_true(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "mobile touch input is mapped to GUI button clicks")


func test_project_app_icon_uses_title_logo_variant() -> void:
	_runner.assert_eq(ProjectSettings.get_setting("application/config/icon"), "res://icon.png", "project icon uses generated title icon")
	_runner.assert_true(ResourceLoader.exists("res://icon.png"), "project icon resource exists")
	_runner.assert_true(FileAccess.file_exists("res://assets/branding/app_icon_192.png"), "android launcher icon exists")
	_runner.assert_true(FileAccess.file_exists("res://assets/branding/app_icon_512.png"), "web launcher icon exists")


func _is_signal_connected_to_method(signal_ref: Signal, target: Object, method_name: StringName) -> bool:
	for connection: Dictionary in signal_ref.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == target and callable.get_method() == method_name:
			return true
	return false


func _assert_lobby_button_style(button: Button, label: String) -> void:
	_assert_lobby_button_texture(button.get_theme_stylebox("normal"), "res://assets/ui/buttons/lobby/lobby_button_normal.png", "%s normal button texture" % label)
	_assert_lobby_button_texture(button.get_theme_stylebox("hover"), "res://assets/ui/buttons/lobby/lobby_button_normal.png", "%s hover button texture" % label)
	_assert_lobby_button_texture(button.get_theme_stylebox("pressed"), "res://assets/ui/buttons/lobby/lobby_button_pressed.png", "%s pressed button texture" % label)


func _assert_lobby_button_texture(style: StyleBox, texture_path: String, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses a texture stylebox" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, texture_path, message)
	_runner.assert_eq(texture_style.texture_margin_left, 60.0, "%s left 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_right, 60.0, "%s right 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_top, 12.0, "%s top 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_bottom, 12.0, "%s bottom 9-slice margin" % message)
