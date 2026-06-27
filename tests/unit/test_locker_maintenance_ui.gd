extends Node

const LockerMaintenanceScene := preload("res://scenes/ui/locker_maintenance.tscn")
const LockerMaintenanceScript := preload("res://scripts/ui/locker_maintenance.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const DungeonTheme := preload("res://scripts/ui/dungeon_ui_theme.gd")
const PixelButtonStyle := preload("res://scripts/ui/pixel_button_style.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()


func after_each() -> void:
	SceneTransition.clear_pending_run_config()
	AudioManager.reset()
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_locker_maintenance_focuses_on_memory_weapons_and_single_departure_entry() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BAT, "locker maintenance starts with the story-backed bat selected")
	_runner.assert_eq(screen.get_departure_entry_count(), 1, "locker maintenance exposes exactly one Gyeongbokgung departure entry")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return action is available")
	_runner.assert_eq(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_CYCLE_WEAPON), null, "bottom CTA no longer competes with weapon cards")
	_runner.assert_eq(UiTestHarness.find_by_uat_action(screen, "locker_maintenance.weapon.baseball"), null, "story-unused baseball memory weapon is not selectable")
	var departure_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG) as Button
	_runner.assert_not_null(departure_button, "Gyeongbokgung action is available only as the bottom button")
	if departure_button != null:
		_runner.assert_eq(departure_button.text, "경복궁으로", "departure button names the destination directly")
	_runner.assert_false(screen.has_node("TodayPrepPanel"), "today prep checklist panel is intentionally absent")
	_runner.assert_false(screen.has_node("MapPreviewPanel"), "map preview panel is intentionally absent")
	_runner.assert_false(screen.has_node("StudentIdCard"), "student id slot is intentionally removed from the maintenance layout")


func test_locker_maintenance_uses_dungeon_ui_loadout_hierarchy() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	var baseball_card := screen.get_node_or_null("BaseballCard") as Button
	var bat_card := screen.get_node("BatCard") as Button
	var loadout_panel := screen.get_node("LoadoutSummaryPanel") as PanelContainer
	var weapon_status := loadout_panel.get_node("WeaponStatusLabel") as Label
	var return_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN) as Button
	var weapon_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_CYCLE_WEAPON) as Button
	var departure_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG) as Button

	_runner.assert_eq(baseball_card, null, "story-unused baseball memory weapon card is removed")
	_runner.assert_eq(bat_card.focus_mode, Control.FOCUS_NONE, "weapon slot does not show desktop focus chrome")
	_runner.assert_eq(screen.get_weapon_card_icon_path(LockerMaintenanceScript.WEAPON_BAT), LockerMaintenanceScript.BAT_ICON_PATH, "locker bat card uses the real bat icon asset")
	_runner.assert_eq(return_button.text, "이전으로", "return CTA does not mention the hallway")
	_runner.assert_eq(departure_button.text, "경복궁으로", "departure CTA skips the map step")
	_runner.assert_eq(weapon_status.text, "선택한 장비\n\n금 간 나무 배트\n\n경복궁으로\n바로 이동", "selected loadout is summarized beside the slot")
	var slot_box := bat_card.get_theme_stylebox("normal") as StyleBoxTexture
	_runner.assert_not_null(slot_box, "selected weapon slot uses the shared textured card frame")
	if slot_box != null:
		_runner.assert_eq(slot_box.texture.resource_path, "res://assets/ui/panels/card_frame.png", "weapon slot reuses the card frame texture")
	_assert_pixel_button_style(return_button, PixelButtonStyle.VARIANT_SECONDARY, "return")
	_runner.assert_eq(weapon_button, null, "weapon cycle CTA is removed; selecting a weapon card is the weapon action")
	_assert_pixel_button_style(departure_button, PixelButtonStyle.VARIANT_PRIMARY, "Gyeongbokgung entry")
	var expected_bottom := 1.0 - (MobileSafeArea.cta_bottom_margin() / MobileSafeArea.DESIGN_VIEWPORT.y)
	_runner.assert_true(return_button.anchor_bottom <= expected_bottom, "return CTA stays above landscape phone home indicator")
	_runner.assert_true(departure_button.anchor_bottom <= expected_bottom, "departure CTA stays above landscape phone home indicator")


func test_locker_maintenance_shows_awakened_bat_after_lobby_quest() -> void:
	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)

	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	var weapon_name := screen.get_node("BatCard/WeaponShowcase/WeaponName") as Label
	var weapon_desc := screen.get_node("BatCard/WeaponShowcase/WeaponDesc") as Label
	var weapon_status := screen.get_node("LoadoutSummaryPanel/WeaponStatusLabel") as Label

	_runner.assert_eq(weapon_name.text, "마지막 시즌의 배트", "quest-completed loadout shows the awakened bat name")
	_runner.assert_true(weapon_desc.text.contains("되받아친다"), "quest-completed loadout explains the awakened bat effect")
	_runner.assert_true(weapon_status.text.contains("마지막 시즌의 배트"), "hidden UAT summary mirrors the awakened bat name")


func test_locker_maintenance_title_and_subtitle_have_breathing_room() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	var title := screen.get_node("TitleLabel") as Label
	var subtitle := screen.get_node("SubtitleLabel") as Label

	_runner.assert_true(subtitle.anchor_top - title.anchor_bottom >= 0.025, "subtitle is visually separated from title")
	_runner.assert_eq(subtitle.text, "어둠에 들어서기 전, 장비를 점검한다.", "subtitle copy stays player-facing")


func test_locker_maintenance_buttons_emit_flow_signals() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	var weapon_ids: Array[StringName] = []
	var return_count := [0]
	var departure_stages: Array[StringName] = []
	add_child(screen)
	screen.weapon_changed.connect(func(weapon_id: StringName) -> void:
		weapon_ids.append(weapon_id)
	)
	screen.return_requested.connect(func() -> void:
		return_count[0] += 1
	)
	screen.departure_requested.connect(func(stage_id: StringName) -> void:
		departure_stages.append(stage_id)
	)

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_SELECT_BAT), "bat card remains pressable")
	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BAT, "bat remains the selected weapon")
	_runner.assert_eq(weapon_ids, [], "pressing the already-selected single weapon does not emit a redundant change")
	_runner.assert_false(UiTestHarness.press_by_uat_action(screen, "locker_maintenance.weapon.baseball"), "baseball weapon action is removed")
	var weapon_status := screen.get_node("LoadoutSummaryPanel/WeaponStatusLabel") as Label
	_runner.assert_true(weapon_status.text.contains("금 간 나무 배트"), "loadout summary keeps the story-backed weapon")

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return button can be pressed")
	_runner.assert_eq(return_count[0], 1, "return button emits return request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG), "Gyeongbokgung button can be pressed")
	_runner.assert_eq(departure_stages, [LockerMaintenanceScript.STAGE_GYEONGBOKGUNG], "departure emits the stage id")
	var pending_config := SceneTransition.get_pending_run_config()
	_runner.assert_eq(pending_config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], LockerMaintenanceScript.WEAPON_BAT, "departure preserves the selected story-backed weapon")
	var departure_config: Dictionary = screen.get_departure_config()
	_runner.assert_eq(departure_config["source"], "locker_maintenance", "departure starts directly from locker maintenance")
	_runner.assert_eq(departure_config["stage_id"], LockerMaintenanceScript.STAGE_GYEONGBOKGUNG, "departure includes selected stage")
	_runner.assert_eq(departure_config["stage_name"], LockerMaintenanceScript.STAGE_GYEONGBOKGUNG_NAME, "departure includes the player-facing stage name")
	_runner.assert_eq(departure_config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], LockerMaintenanceScript.WEAPON_BAT, "departure config keeps the locker weapon")
	var departure_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG) as Button
	_runner.assert_not_null(departure_button, "departure button remains addressable for UAT")
	if departure_button != null:
		_runner.assert_true(departure_button.disabled, "departure button disables after the first request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG), "test harness can still reach the disabled button")
	_runner.assert_eq(departure_stages, [LockerMaintenanceScript.STAGE_GYEONGBOKGUNG], "double departure does not emit another stage")


func test_locker_maintenance_departure_uses_bell_without_generic_press_sfx() -> void:
	AudioManager.reset()
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_START_GYEONGBOKGUNG), "departure action is pressable")
	_runner.assert_false(
		AudioManager.get_played_sfx().has(AudioManager.UI_BUTTON_PRESS),
		"departure action leaves room for the session bell instead of playing generic press SFX"
	)


func _assert_texture_slot_style(style: StyleBox, expected_modulate: Color, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s is a textured dungeon UI style" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, "res://assets/ui/panels/card_frame.png", "%s uses the shared card frame" % message)
	_runner.assert_eq(texture_style.texture_margin_left, DungeonTheme.CARD_FRAME_TEXTURE_MARGIN, "%s keeps the card 9-slice margin" % message)
	_runner.assert_eq(texture_style.content_margin_left, 12.0, "%s keeps slot content padding" % message)
	_runner.assert_eq(texture_style.modulate_color, expected_modulate, "%s applies selected tint" % message)


func _assert_pixel_button_style(button: Button, variant: StringName, label: String) -> void:
	_runner.assert_not_null(button, "%s button exists" % label)
	if button == null:
		return
	_assert_pixel_button_texture(button.get_theme_stylebox("normal"), PixelButtonStyle.normal_texture_path(variant), "%s normal" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("hover"), PixelButtonStyle.normal_texture_path(variant), "%s hover" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("pressed"), PixelButtonStyle.pressed_texture_path(variant), "%s pressed" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("disabled"), PixelButtonStyle.normal_texture_path(variant), "%s disabled" % label)


func _assert_pixel_button_texture(style: StyleBox, texture_path: String, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses pixel button texture style" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, texture_path, message)
