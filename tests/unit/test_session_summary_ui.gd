extends Node

const SESSION_UI_SCENE := preload("res://scenes/ui/session_ui_root.tscn")

var _runner: Node
var _ui: CanvasLayer


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	_ui = SESSION_UI_SCENE.instantiate()
	add_child(_ui)


func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_ui):
		_ui.free()
	_ui = null


func test_success_result_renders_player_facing_summary() -> void:
	_ui.show_summary({
		"completed": true,
		"memory_reward": 42,
		"students_rescued": 3,
		"friends_purified": 1,
		"rooms_cleared": 18,
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_true(snapshot["visible"], "result panel is shown")
	_runner.assert_eq(snapshot["title"], "탈출 성공", "success header uses player-facing copy")
	_runner.assert_true(snapshot["narrative"].contains("친구의 기억"), "success summary explains the next narrative beat")
	_runner.assert_eq(snapshot["memory_label"], "기억 조각", "permanent reward label is concise")
	_runner.assert_eq(snapshot["memory_amount"], "+42", "permanent reward is the largest result number")
	_runner.assert_eq(snapshot["students"], "구출 3", "rescued students render as a record chip")
	_runner.assert_eq(snapshot["friends"], "친구 1", "purified friends render as a record chip")
	_runner.assert_eq(snapshot["rooms"], "방 18", "room count renders as a record chip")
	_runner.assert_eq(snapshot["unlocks"], "", "no unlock row is rendered without unlocks")
	_assert_no_explainer_copy(snapshot)


func test_death_result_keeps_same_layout_without_loss_copy() -> void:
	_ui.show_summary({
		"outcome": "death",
		"memory_reward": 5,
		"students_rescued": 1,
		"friends_purified": 0,
		"rooms_cleared": 7,
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["title"], "쓰러짐", "death state uses its own header")
	_runner.assert_true(snapshot["narrative"].contains("기억 조각은 손에 남아 있다"), "death summary reassures retained progress")
	_runner.assert_eq(snapshot["memory_amount"], "+5", "death still foregrounds earned memory")
	_runner.assert_eq(snapshot["students"], "구출 1", "death keeps the record stack")
	_runner.assert_eq(snapshot["friends"], "친구 0", "zero values stay aligned in the same chip")
	_runner.assert_eq(snapshot["rooms"], "방 7", "room count remains visible")
	_assert_no_explainer_copy(snapshot)


func test_run_result_contract_derives_records_from_existing_payload() -> void:
	_ui.show_summary({
		"completed": true,
		"cleared_room_ids": [&"start", &"combat_1", &"final_1"],
		"visited_room_ids": [&"start", &"combat_1", &"event_1", &"final_1"],
		"boss_id": &"gyeongbokgung_boss",
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["title"], "탈출 성공", "completed run maps to success")
	_runner.assert_eq(snapshot["memory_amount"], "+3", "existing cleared rooms derive memory reward")
	_runner.assert_eq(snapshot["friends"], "친구 1", "boss result derives purified friend count")
	_runner.assert_eq(snapshot["rooms"], "방 3", "cleared rooms drive room record")


func test_explicit_zero_reward_is_not_derived_from_rooms() -> void:
	_ui.show_summary({
		"completed": true,
		"memory_reward": 0,
		"cleared_room_ids": [&"start", &"combat_1"],
		"friends_purified": 0,
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["memory_amount"], "+0", "explicit zero reward is honored")
	_runner.assert_eq(snapshot["friends"], "친구 0", "explicit zero friend count is honored")
	_runner.assert_eq(snapshot["rooms"], "방 2", "room records still derive when not explicit")


func test_summary_actions_emit_distinct_flow_signals() -> void:
	var counts := {
		"return": 0,
		"retry": 0,
	}
	_ui.return_requested.connect(func() -> void: counts["return"] += 1)
	_ui.retry_requested.connect(func() -> void: counts["retry"] += 1)

	var return_button := _ui.get_node("%ReturnButton") as Button
	var retry_button := _ui.get_node("%RetryButton") as Button
	_runner.assert_eq(return_button.text, "학교로 돌아가기", "return action copy is stable")
	_runner.assert_eq(retry_button.text, "다시 밤으로", "retry action copy is stable")
	retry_button.pressed.emit()
	return_button.pressed.emit()

	_runner.assert_eq(counts["return"], 1, "return button emits return flow")
	_runner.assert_eq(counts["retry"], 1, "retry button emits retry flow")


func test_map_tab_replaces_bottom_action_panel() -> void:
	var map_tab := _ui.get_node("%MapTabButton") as Button
	_runner.assert_eq(map_tab.text, "경복궁", "session map tab defaults to the current MVP map name")
	_runner.assert_eq(map_tab.get_meta("test_id", ""), "session.map_tab", "map tab has stable test id")
	_runner.assert_eq(map_tab.get_meta("uat_action", ""), "session.map_tab", "map tab has stable UAT action")
	_runner.assert_false(_ui.is_action_panel_visible(), "bottom action panel is not visible during gameplay")

	_ui.show_reward_choices(&"combat_1", [
		{"item_id": &"gung_talisman", "display_name": "궁 부적"},
	])
	_runner.assert_false(_ui.is_action_panel_visible(), "reward overlay does not restore bottom action buttons")
	_ui.hide_reward_choices()
	_runner.assert_false(_ui.is_action_panel_visible(), "closing overlays keeps bottom action buttons removed")


func test_session_hides_legacy_status_copy_during_gameplay() -> void:
	var top_panel := _ui.get_node("Root/TopPanel") as Control
	var status_label := _ui.get_node("%StatusLabel") as Label
	var interaction_label := _ui.get_node("%InteractionLabel") as Label

	_runner.assert_false(top_panel.is_visible_in_tree(), "legacy status row is hidden during gameplay")
	_runner.assert_false(status_label.is_visible_in_tree(), "session status copy is not rendered over gameplay")
	_runner.assert_false(interaction_label.is_visible_in_tree(), "legacy interaction count is not rendered over gameplay")
	_runner.assert_eq(status_label.text, "", "legacy session status starts empty")
	_runner.assert_eq(interaction_label.text, "", "legacy interaction count starts empty")


func test_map_tab_uses_configured_map_name_and_toggles_pause_resume_signals() -> void:
	var counts := {
		"pause": 0,
		"resume": 0,
	}
	_ui.pause_requested.connect(func() -> void: counts["pause"] += 1)
	_ui.resume_requested.connect(func() -> void: counts["resume"] += 1)

	_ui.set_map_name("창덕궁")
	var map_tab := _ui.get_node("%MapTabButton") as Button
	_runner.assert_eq(map_tab.text, "창덕궁", "map tab renders the configured map name")

	get_tree().paused = false
	map_tab.pressed.emit()
	_runner.assert_eq(counts["pause"], 1, "map tab requests pause while the run is active")
	_runner.assert_eq(counts["resume"], 0, "map tab does not request resume while active")

	get_tree().paused = true
	map_tab.pressed.emit()
	_runner.assert_eq(counts["pause"], 1, "map tab does not request a second pause while paused")
	_runner.assert_eq(counts["resume"], 1, "map tab requests resume while the run is paused")


func test_reward_choices_render_three_actions_and_emit_selected_id() -> void:
	var selected_ids: Array[StringName] = []
	_ui.reward_choice_selected.connect(func(item_id: StringName) -> void: selected_ids.append(item_id))

	_ui.show_reward_choices(&"combat_1", [
		{
			"item_id": &"gung_talisman",
			"display_name": "궁 부적",
			"flavor": "붉은 궁 부적이 주먹과 배트에 힘을 싣는다.",
			"effect": "근접 피해 +1 / 배트 피해 +1",
		},
		{
			"item_id": &"dokkaebi_fire",
			"display_name": "도깨비불",
			"flavor": "푸른 불씨가 공격 박자를 앞당긴다.",
			"effect": "근접 공격 간격 -16% / 투척 간격 -16%",
		},
		{
			"item_id": &"wind_step",
			"display_name": "바람 매듭",
			"flavor": "매듭이 풀리며 발끝이 가벼워진다.",
			"effect": "이동 속도 +15%",
		},
	])

	var snapshot: Dictionary = _ui.get_reward_choice_snapshot()
	_runner.assert_true(snapshot["visible"], "reward choice overlay is visible")
	_runner.assert_eq(snapshot["room_id"], &"combat_1", "reward choice keeps source room id")
	_runner.assert_eq(snapshot["choice_ids"], [&"gung_talisman", &"dokkaebi_fire", &"wind_step"], "reward choices keep stable item order")
	_runner.assert_eq(snapshot["choice_texts"][0], "궁 부적", "reward button uses display name")
	_runner.assert_true(snapshot["choice_flavors"][1].contains("공격 박자"), "reward flavor is available for scan")
	_runner.assert_true(snapshot.has("choice_effects"), "reward snapshot exposes concrete stat effects")
	if not snapshot.has("choice_effects"):
		return
	_runner.assert_eq(snapshot["choice_effects"][0], "근접 피해 +1 / 배트 피해 +1", "reward card exposes concrete stat effect")
	_runner.assert_true(snapshot["choice_effects"][1].contains("간격 -16%"), "tempo reward exposes concrete cooldown effect")

	_runner.assert_true(_ui.select_reward_choice(&"dokkaebi_fire"), "reward choice can be selected by id")
	_runner.assert_eq(selected_ids, [&"dokkaebi_fire"], "selection emits item id once")
	_runner.assert_false(_ui.is_reward_choice_visible(), "selection hides reward choice overlay")


func test_summary_renders_baseball_unlocks_when_present() -> void:
	_ui.show_summary({
		"completed": true,
		"memory_reward": 8,
		"students_rescued": 0,
		"friends_purified": 1,
		"rooms_cleared": 8,
		"unlocks": [&"baseball_stage_3", &"awakened_bat"],
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_true(snapshot["unlocks"].contains("야구부 STAGE 3"), "stage unlock is shown")
	_runner.assert_true(snapshot["unlocks"].contains("마지막 시즌의 배트"), "awakened bat unlock is shown")


func test_visible_session_actions_use_pixel_button_skin() -> void:
	_assert_pixel_button_style(_ui.get_node("%MapTabButton") as Button, PixelButtonStyle.VARIANT_PRIMARY, "map tab")
	_assert_pixel_button_style(_ui.get_node("%ReturnButton") as Button, PixelButtonStyle.VARIANT_PRIMARY, "return")
	_assert_pixel_button_style(_ui.get_node("%RetryButton") as Button, PixelButtonStyle.VARIANT_SECONDARY, "retry")
	_runner.assert_eq(_ui.get_node_or_null("%PauseButton"), null, "old bottom pause button is removed")
	_runner.assert_eq(_ui.get_node_or_null("%ResumeButton"), null, "old bottom resume button is removed")
	_runner.assert_eq(_ui.get_node_or_null("%FinishButton"), null, "old bottom finish button is removed")


func _assert_no_explainer_copy(snapshot: Dictionary) -> void:
	for value: Variant in snapshot.values():
		var text := str(value)
		_runner.assert_false(text.contains("보존"), "summary does not explain preserved currency")
		_runner.assert_false(text.contains("소멸"), "summary does not mention expiring currency")
		_runner.assert_false(text.contains("저장 완료"), "summary does not show save-complete footer")


func _assert_pixel_button_style(button: Button, variant: StringName, label: String) -> void:
	_assert_pixel_button_texture(button.get_theme_stylebox("normal"), PixelButtonStyle.normal_texture_path(variant), "%s normal" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("hover"), PixelButtonStyle.normal_texture_path(variant), "%s hover" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("pressed"), PixelButtonStyle.pressed_texture_path(variant), "%s pressed" % label)


func _assert_pixel_button_texture(style: StyleBox, texture_path: String, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses pixel button texture style" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, texture_path, message)
	_runner.assert_eq(texture_style.texture_margin_left, 60.0, "%s left 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_bottom, 12.0, "%s bottom 9-slice margin" % message)
