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
	_runner.assert_eq(settings_button.get_meta("uat_action"), "lobby.settings", "settings uat action is stable")
	_runner.assert_false(status_label.visible, "status copy is hidden on title screen")
	_runner.assert_false(lobby.has_node("LogoPane/TaglineLabel"), "tagline copy is removed")
	_runner.assert_false(lobby.has_node("MenuPane/FocusHint"), "input hint copy is removed")

	lobby.queue_free()


func test_project_app_icon_uses_title_logo_variant() -> void:
	_runner.assert_eq(ProjectSettings.get_setting("application/config/icon"), "res://icon.png", "project icon uses generated title icon")
	_runner.assert_true(ResourceLoader.exists("res://icon.png"), "project icon resource exists")
	_runner.assert_true(FileAccess.file_exists("res://assets/branding/app_icon_192.png"), "android launcher icon exists")
	_runner.assert_true(FileAccess.file_exists("res://assets/branding/app_icon_512.png"), "web launcher icon exists")
