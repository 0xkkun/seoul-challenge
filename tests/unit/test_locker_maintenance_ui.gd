extends Node

const LockerMaintenanceScene := preload("res://scenes/ui/locker_maintenance.tscn")
const LockerMaintenanceScript := preload("res://scripts/ui/locker_maintenance.gd")
const NightMapSelectScene := preload("res://scenes/ui/night_map_select.tscn")
const NightMapSelectScript := preload("res://scripts/ui/night_map_select.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	SceneTransition.clear_pending_run_config()
	AudioManager.reset()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_locker_maintenance_focuses_on_memory_weapons_and_single_map_entry() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BAT, "locker maintenance starts with the story-backed bat selected")
	_runner.assert_eq(screen.get_map_entry_count(), 1, "locker maintenance exposes exactly one map entry")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return action is available")
	_runner.assert_eq(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_CYCLE_WEAPON), null, "bottom CTA no longer competes with weapon cards")
	_runner.assert_eq(UiTestHarness.find_by_uat_action(screen, "locker_maintenance.weapon.baseball"), null, "story-unused baseball memory weapon is not selectable")
	var map_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_OPEN_MAP) as Button
	_runner.assert_not_null(map_button, "map action is available only as the bottom button")
	if map_button != null:
		_runner.assert_eq(map_button.text, "지도", "map button uses text-only copy")
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
	var map_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_OPEN_MAP) as Button

	_runner.assert_eq(baseball_card, null, "story-unused baseball memory weapon card is removed")
	_runner.assert_eq(bat_card.focus_mode, Control.FOCUS_NONE, "weapon slot does not show desktop focus chrome")
	_runner.assert_eq(screen.get_weapon_card_icon_path(LockerMaintenanceScript.WEAPON_BAT), LockerMaintenanceScript.BAT_ICON_PATH, "locker bat card uses the real bat icon asset")
	_runner.assert_eq(return_button.text, "복도", "return CTA uses text-only copy")
	_runner.assert_eq(map_button.text, "지도", "map CTA uses text-only copy")
	_runner.assert_eq(weapon_status.text, "선택한 기억\n\n금 간 나무 배트\n\n지도에서\n경복궁으로 이동", "selected loadout is summarized beside the slot")
	_assert_flat_style_border(bat_card.get_theme_stylebox("normal"), 4, "selected weapon slot uses a thick border")
	_assert_pixel_button_style(return_button, PixelButtonStyle.VARIANT_SECONDARY, "return")
	_runner.assert_eq(weapon_button, null, "weapon cycle CTA is removed; selecting a weapon card is the weapon action")
	_assert_pixel_button_style(map_button, PixelButtonStyle.VARIANT_PRIMARY, "map entry")
	var expected_bottom := 1.0 - (MobileSafeArea.cta_bottom_margin() / MobileSafeArea.DESIGN_VIEWPORT.y)
	_runner.assert_true(return_button.anchor_bottom <= expected_bottom, "return CTA stays above landscape phone home indicator")
	_runner.assert_true(map_button.anchor_bottom <= expected_bottom, "map CTA stays above landscape phone home indicator")


func test_locker_maintenance_title_and_subtitle_have_breathing_room() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	var title := screen.get_node("TitleLabel") as Label
	var subtitle := screen.get_node("SubtitleLabel") as Label

	_runner.assert_true(subtitle.anchor_top - title.anchor_bottom >= 0.025, "subtitle is visually separated from title")
	_runner.assert_eq(subtitle.text, "밤의 경복궁에 들어가기 전, 가져갈 기억을 고른다.", "subtitle copy stays player-facing")


func test_locker_maintenance_buttons_emit_flow_signals() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	var weapon_ids: Array[StringName] = []
	var return_count := [0]
	var map_count := [0]
	add_child(screen)
	screen.weapon_changed.connect(func(weapon_id: StringName) -> void:
		weapon_ids.append(weapon_id)
	)
	screen.return_requested.connect(func() -> void:
		return_count[0] += 1
	)
	screen.map_requested.connect(func() -> void:
		map_count[0] += 1
	)

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_SELECT_BAT), "bat card remains pressable")
	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BAT, "bat remains the selected weapon")
	_runner.assert_eq(weapon_ids, [], "pressing the already-selected single weapon does not emit a redundant change")
	_runner.assert_false(UiTestHarness.press_by_uat_action(screen, "locker_maintenance.weapon.baseball"), "baseball weapon action is removed")
	var weapon_status := screen.get_node("LoadoutSummaryPanel/WeaponStatusLabel") as Label
	_runner.assert_true(weapon_status.text.contains("금 간 나무 배트"), "loadout summary keeps the story-backed weapon")

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return button can be pressed")
	_runner.assert_eq(return_count[0], 1, "return button emits return request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_OPEN_MAP), "map button can be pressed")
	_runner.assert_eq(map_count[0], 1, "map button emits one map request")
	var pending_config := SceneTransition.get_pending_run_config()
	_runner.assert_eq(pending_config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], LockerMaintenanceScript.WEAPON_BAT, "map entry preserves the selected story-backed weapon")


func test_night_map_select_is_separate_from_locker_maintenance() -> void:
	SceneTransition.set_pending_run_config({
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: LockerMaintenanceScript.WEAPON_BAT,
	})
	var screen := NightMapSelectScene.instantiate()
	screen.set("scene_transition_enabled", false)
	var selected_stages: Array[StringName] = []
	var return_count := [0]
	add_child(screen)
	screen.stage_selected.connect(func(stage_id: StringName) -> void:
		selected_stages.append(stage_id)
	)
	screen.return_requested.connect(func() -> void:
		return_count[0] += 1
	)

	_runner.assert_eq(screen.get_selected_stage_id(), NightMapSelectScript.STAGE_GYEONGBOKGUNG, "night map defaults to Gyeongbokgung")
	_runner.assert_eq(screen.get_stage_entry_count(), 1, "night map exposes one selectable MVP destination")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, NightMapSelectScript.ACTION_RETURN), "map screen can return to maintenance")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG), "map screen exposes Gyeongbokgung as the run entry")
	var map_label := screen.get_node("RouteMapPanel/MapLabel") as Label
	var destination_label := screen.get_node("DestinationPanel/DestinationLabel") as Label
	_runner.assert_true(map_label.text.contains("학교 정비실"), "map screen frames the MVP route as a node path")
	_runner.assert_true(map_label.text.contains("잠김"), "future locations are shown as locked, not competing choices")
	_runner.assert_true(destination_label.text.contains("선택한 곳"), "destination panel confirms the active stage")
	_runner.assert_true(destination_label.text.contains("친구 정화 · 탈출"), "destination panel states the night objective")
	var departure_config: Dictionary = screen.get_departure_config()
	_runner.assert_eq(departure_config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], LockerMaintenanceScript.WEAPON_BAT, "map departure keeps the locker weapon")
	_runner.assert_eq(departure_config["stage_id"], NightMapSelectScript.STAGE_GYEONGBOKGUNG, "map departure includes selected stage")

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, NightMapSelectScript.ACTION_RETURN), "return action is pressable")
	_runner.assert_eq(return_count[0], 1, "map return emits a request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG), "Gyeongbokgung action is pressable")
	_runner.assert_eq(selected_stages, [NightMapSelectScript.STAGE_GYEONGBOKGUNG], "map stage selection emits the stage id")
	var departure_button := UiTestHarness.find_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG) as Button
	_runner.assert_not_null(departure_button, "departure button remains addressable for UAT")
	if departure_button != null:
		_runner.assert_eq(departure_button.text, "경복궁으로\n들어가기", "departure CTA is short and explicit")
		_runner.assert_true(departure_button.disabled, "departure button disables after the first request")
		_assert_pixel_button_style(departure_button, PixelButtonStyle.VARIANT_PRIMARY, "departure")
	var map_return_button := UiTestHarness.find_by_uat_action(screen, NightMapSelectScript.ACTION_RETURN) as Button
	_assert_pixel_button_style(map_return_button, PixelButtonStyle.VARIANT_SECONDARY, "map return")
	var expected_bottom := 1.0 - (MobileSafeArea.cta_bottom_margin() / MobileSafeArea.DESIGN_VIEWPORT.y)
	_runner.assert_true(map_return_button.anchor_bottom <= expected_bottom, "map return CTA stays above landscape phone home indicator")
	_runner.assert_true(departure_button.anchor_bottom <= expected_bottom, "departure CTA stays above landscape phone home indicator")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG), "test harness can still reach the disabled button")
	_runner.assert_eq(selected_stages, [NightMapSelectScript.STAGE_GYEONGBOKGUNG], "double departure does not emit another stage")


func test_night_map_departure_uses_bell_without_generic_press_sfx() -> void:
	AudioManager.reset()
	var screen := NightMapSelectScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG), "departure action is pressable")
	_runner.assert_false(
		AudioManager.get_played_sfx().has(AudioManager.UI_BUTTON_PRESS),
		"departure action leaves room for the session bell instead of playing generic press SFX"
	)


func _assert_flat_style_border(style: StyleBox, expected_width: int, message: String) -> void:
	var flat_style := style as StyleBoxFlat
	_runner.assert_not_null(flat_style, "%s is a flat dungeon UI style" % message)
	if flat_style == null:
		return
	_runner.assert_eq(flat_style.get_border_width(SIDE_LEFT), expected_width, message)
	_runner.assert_eq(flat_style.corner_radius_top_left, 0, "%s keeps square pixel corners" % message)


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
