extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_lobby_title_scene_uses_title_assets_and_menu_contract() -> void:
	var packed := load("res://scenes/lobby/lobby.tscn") as PackedScene
	var lobby := packed.instantiate()
	add_child(lobby)

	var background := lobby.get_node("Background") as TextureRect
	var full_overlay := lobby.get_node("FullOverlay") as ColorRect
	var title_logo := lobby.get_node("LogoPane/TitleLogo") as TextureRect
	var start_button := lobby.get_node("%StartButton") as Button
	var settings_button := lobby.get_node("%SettingsButton") as Button
	var status_label := lobby.get_node("%StatusLabel") as Label

	_runner.assert_eq(background.texture.resource_path, "res://assets/backgrounds/lobby/title_lobby_bg.png", "lobby background uses title art")
	_runner.assert_eq(full_overlay.anchor_right, 1.0, "overlay spans full width")
	_runner.assert_eq(full_overlay.anchor_bottom, 1.0, "overlay spans full height")
	_runner.assert_eq(title_logo.texture.resource_path, "res://assets/branding/title_logo.png", "lobby uses official title logo")
	_runner.assert_eq(start_button.text, "게임 시작", "start button is localized")
	_runner.assert_eq(settings_button.text, "설정", "settings button is localized")
	_runner.assert_eq(start_button.get_meta("uat_action"), "lobby.start", "start uat action is stable")
	_runner.assert_true(settings_button.disabled, "settings stays visible but disabled until the settings flow exists")
	_runner.assert_false(settings_button.has_meta("uat_action"), "disabled settings button does not expose a dead UAT action")
	_runner.assert_true(_is_signal_connected_to_method(start_button.pressed, lobby, "_on_start_pressed"), "start button is wired to title start handler")
	_runner.assert_true(lobby.has_method("_go_to_day_lobby"), "start transition is deferred for touch input")
	_runner.assert_eq(SceneTransition.get_day_lobby_scene_path(), "res://scenes/dev/day_corridor_movement_test.tscn", "start destination is the day lobby")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_day_lobby_scene_path()), "day lobby scene resource exists")
	_runner.assert_eq(SceneTransition.get_locker_maintenance_scene_path(), "res://scenes/ui/locker_maintenance.tscn", "locker maintenance scene path is exposed")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_locker_maintenance_scene_path()), "locker maintenance scene resource exists")
	_runner.assert_eq(SceneTransition.get_night_map_select_scene_path(), "res://scenes/ui/night_map_select.tscn", "night map select scene path is exposed")
	_runner.assert_true(ResourceLoader.exists(SceneTransition.get_night_map_select_scene_path()), "night map select scene resource exists")
	_runner.assert_false(status_label.visible, "status copy is hidden on title screen")
	_runner.assert_false(lobby.has_node("LogoPane/TaglineLabel"), "tagline copy is removed")
	_runner.assert_false(lobby.has_node("MenuPane/FocusHint"), "input hint copy is removed")

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
