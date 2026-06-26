extends Node

const LockerMaintenanceScene := preload("res://scenes/ui/locker_maintenance.tscn")
const LockerMaintenanceScript := preload("res://scripts/ui/locker_maintenance.gd")
const NightMapSelectScene := preload("res://scenes/ui/night_map_select.tscn")
const NightMapSelectScript := preload("res://scripts/ui/night_map_select.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	SceneTransition.clear_pending_run_config()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_locker_maintenance_focuses_on_memory_weapons_and_single_map_entry() -> void:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)

	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BASEBALL, "locker maintenance starts with baseball selected")
	_runner.assert_eq(screen.get_map_entry_count(), 1, "locker maintenance exposes exactly one map entry")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return action is available")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_CYCLE_WEAPON), "weapon action is available")
	var map_button := UiTestHarness.find_by_uat_action(screen, LockerMaintenanceScript.ACTION_OPEN_MAP) as Button
	_runner.assert_not_null(map_button, "map action is available only as the bottom button")
	if map_button != null:
		_runner.assert_eq(map_button.text, "지도\n지도 보기", "map button is the single explicit map affordance")
	_runner.assert_false(screen.has_node("TodayPrepPanel"), "today prep checklist panel is intentionally absent")
	_runner.assert_false(screen.has_node("MapPreviewPanel"), "map preview panel is intentionally absent")


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

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_SELECT_BAT), "bat card can be selected")
	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BAT, "bat selection updates screen state")
	_runner.assert_eq(weapon_ids, [LockerMaintenanceScript.WEAPON_BAT], "bat selection emits weapon id")

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_CYCLE_WEAPON), "weapon action cycles the selected weapon")
	_runner.assert_eq(screen.get_selected_weapon_id(), LockerMaintenanceScript.WEAPON_BASEBALL, "cycle returns to baseball")

	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_RETURN), "return button can be pressed")
	_runner.assert_eq(return_count[0], 1, "return button emits return request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, LockerMaintenanceScript.ACTION_OPEN_MAP), "map button can be pressed")
	_runner.assert_eq(map_count[0], 1, "map button emits one map request")
	var pending_config := SceneTransition.get_pending_run_config()
	_runner.assert_eq(pending_config[SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], LockerMaintenanceScript.WEAPON_BASEBALL, "map entry preserves the selected weapon")


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
		_runner.assert_true(departure_button.disabled, "departure button disables after the first request")
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, NightMapSelectScript.ACTION_SELECT_GYEONGBOKGUNG), "test harness can still reach the disabled button")
	_runner.assert_eq(selected_stages, [NightMapSelectScript.STAGE_GYEONGBOKGUNG], "double departure does not emit another stage")
