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
	_runner.assert_eq(snapshot["memory_label"], "혼 조각", "permanent reward label is concise")
	_runner.assert_eq(snapshot["memory_amount"], "+42", "permanent reward is the largest result number")
	_runner.assert_eq(snapshot["students"], "3", "rescued students render as a record chip number")
	_runner.assert_eq(snapshot["friends"], "정화 1", "purified friends render as a record chip")
	_runner.assert_eq(snapshot["rooms"], "18", "room count renders as a record chip number")
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
	_runner.assert_true(snapshot["narrative"].contains("혼 조각은 손에 남아 있다"), "death summary reassures retained progress")
	_runner.assert_eq(
		snapshot["narrative"],
		"새벽 종소리와 함께 교실에서 눈을 떴다.\n혼 조각은 손에 남아 있다.",
		"death summary breaks after waking in the classroom"
	)
	_runner.assert_eq(snapshot["memory_amount"], "+5", "death still foregrounds earned memory")
	_runner.assert_eq(snapshot["students"], "1", "death keeps the record stack")
	_runner.assert_eq(snapshot["friends"], "정화 0", "zero values stay aligned in the same chip")
	_runner.assert_eq(snapshot["rooms"], "7", "room count remains visible")
	_assert_no_explainer_copy(snapshot)


func test_death_summary_modal_and_key_record_areas_are_transparent() -> void:
	_ui.show_summary({
		"outcome": "death",
		"memory_reward": 5,
		"students_rescued": 1,
		"friends_purified": 0,
		"rooms_cleared": 7,
	})

	_assert_transparent_panel_style("Root/SummaryOverlay/SummaryPanel", "death summary modal")
	_assert_transparent_panel_style(
		"Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RecordsStack/StudentsRecordPanel",
		"rescued students record area"
	)
	_assert_transparent_panel_style(
		"Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RecordsStack/RoomsRecordPanel",
		"rooms record area"
	)


func test_death_summary_reward_uses_locker_weapon_card_layout() -> void:
	_ui.show_summary({
		"outcome": "death",
		"memory_reward": 5,
		"students_rescued": 1,
		"friends_purified": 0,
		"rooms_cleared": 7,
	})

	var reward_panel := _ui.get_node("Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RewardPanel") as PanelContainer
	_assert_card_frame_style(
		reward_panel.get_theme_stylebox("panel"),
		Color(1.0, 0.93, 0.62),
		DungeonUiTheme.CARD_FRAME_TEXTURE_MARGIN,
		Vector2(28.0, 22.0),
		"death memory shard card"
	)
	var reward_row := _ui.get_node("Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RewardPanel/RewardMargin/RewardRow") as HBoxContainer
	var memory_chip := _ui.get_node("Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RewardPanel/RewardMargin/RewardRow/MemoryChip") as TextureRect
	var reward_text := _ui.get_node("Root/SummaryOverlay/SummaryPanel/SummaryMargin/SummaryStack/SummaryContent/RewardPanel/RewardMargin/RewardRow/RewardTextStack") as VBoxContainer
	var memory_amount := _ui.get_node("%MemoryAmountLabel") as Label

	_runner.assert_eq(reward_row.alignment, BoxContainer.ALIGNMENT_CENTER, "memory shard row centers icon and number together")
	_runner.assert_true(memory_chip.custom_minimum_size.y <= 56.0, "memory shard icon leaves vertical breathing room")
	_runner.assert_eq(memory_chip.size_flags_vertical, Control.SIZE_SHRINK_CENTER, "memory shard icon stays vertically centered")
	_runner.assert_eq(reward_text.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "memory amount sits next to the shard instead of filling the right side")
	_runner.assert_eq(reward_text.size_flags_vertical, Control.SIZE_SHRINK_CENTER, "memory amount stays vertically centered")
	_runner.assert_true(memory_amount.get_theme_font_size("font_size") <= 42, "memory amount no longer fills the full card height")
	_runner.assert_eq(memory_amount.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "memory amount is centered in its own compact stack")


func test_summary_return_button_is_compact_red_action() -> void:
	var return_button := _ui.get_node("%ReturnButton") as Button

	_assert_pixel_button_style(return_button, PixelButtonStyle.VARIANT_DANGER, "return")
	_runner.assert_true(return_button.custom_minimum_size.y <= 52.0, "return button is shorter than the previous oversized result CTA")
	_runner.assert_true(return_button.get_theme_font_size("font_size") <= 24, "return button text is scaled down with the smaller button")


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
	_runner.assert_eq(snapshot["friends"], "정화 0", "boss result does not count as a purified friend")
	_runner.assert_eq(snapshot["rooms"], "3", "cleared rooms drive room record")


func test_onboarding_completion_summary_points_back_to_baseball_captain() -> void:
	_ui.show_summary({
		"reason": "onboarding_friend_purified",
		"completed": true,
		"memory_reward": 1,
		"friend_ids": [&"baseball_captain"],
		"rooms_cleared": 2,
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["title"], "정화 완료", "onboarding completion uses a purification header")
	_runner.assert_true(snapshot["narrative"].contains("야구부 주장"), "onboarding summary directs the player back to the captain")
	_runner.assert_eq(snapshot["friends"], "정화 1", "onboarding friend id still counts as one purification")


func test_boss_resolved_summary_keeps_open_ending() -> void:
	_ui.show_summary({
		"reason": "boss_resolved",
		"completed": true,
		"memory_reward": 3,
		"rooms_cleared": 15,
		"boss_id": &"gyeongbokgung_boss",
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["title"], "탈출 성공", "boss clear still completes the run")
	_runner.assert_true(snapshot["narrative"].contains("돌아오지 않았다"), "boss clear does not pretend the friend returned")
	_runner.assert_true(snapshot["narrative"].contains("범인"), "boss clear foreshadows the unresolved culprit")
	_runner.assert_eq(snapshot["friends"], "정화 0", "boss clear is not a purification")


func test_explicit_zero_reward_is_not_derived_from_rooms() -> void:
	_ui.show_summary({
		"completed": true,
		"memory_reward": 0,
		"cleared_room_ids": [&"start", &"combat_1"],
		"friends_purified": 0,
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["memory_amount"], "+0", "explicit zero reward is honored")
	_runner.assert_eq(snapshot["friends"], "정화 0", "explicit zero friend count is honored")
	_runner.assert_eq(snapshot["rooms"], "2", "room records still derive when not explicit")


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
		{"item_id": &"gung_talisman", "display_name": "강타 부적"},
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
			"item_id": &"dokkaebi_fire",
			"display_name": "도깨비불",
			"flavor": "푸른 불씨가 공격 타이밍을 앞당긴다.",
			"effect": "근접 공격 속도 +19%",
		},
		{
			"item_id": &"wind_step",
			"display_name": "바람 매듭",
			"flavor": "매듭이 풀리며 발끝이 가벼워진다.",
			"effect": "이동 속도 +15%",
		},
		{
			"item_id": &"moon_guard",
			"display_name": "달빛 호신부",
			"flavor": "달빛이 체력 한 칸을 잠시 감싼다.",
			"effect": "최대 체력 +1",
		},
	])

	var snapshot: Dictionary = _ui.get_reward_choice_snapshot()
	_runner.assert_true(snapshot["visible"], "reward choice overlay is visible")
	_runner.assert_eq(snapshot["room_id"], &"combat_1", "reward choice keeps source room id")
	_runner.assert_eq(snapshot["choice_ids"], [&"dokkaebi_fire", &"wind_step", &"moon_guard"], "reward choices keep stable item order")
	_runner.assert_false((snapshot["choice_ids"] as Array).has(&"gung_talisman"), "reward choices omit direct attack damage")
	_runner.assert_eq(snapshot["choice_texts"][0], "도깨비불", "reward button uses display name")
	_runner.assert_false(snapshot.has("choice_flavors"), "reward choice snapshot omits flavor descriptions from the card contract")
	var button_texts := snapshot.get("choice_button_texts", []) as Array
	_runner.assert_eq(button_texts.size(), 3, "reward snapshot exposes rendered button copy for every card")
	if button_texts.size() == 3:
		_runner.assert_false(String(button_texts[1]).contains("공격 타이밍"), "reward button omits flavor description copy")
	_runner.assert_true(snapshot.has("choice_effects"), "reward snapshot exposes concrete stat effects")
	if not snapshot.has("choice_effects"):
		return
	_runner.assert_eq(snapshot["choice_effects"][0], "근접 공격 속도 +19%", "tempo reward exposes readable attack speed effect")
	_runner.assert_true(snapshot["choice_effects"][1].contains("이동 속도"), "speed reward exposes concrete movement effect")
	_runner.assert_true(snapshot.has("visible_card_count"), "reward snapshot exposes rendered card count")
	_runner.assert_true(snapshot.has("has_backdrop"), "reward snapshot exposes backdrop contract")
	_runner.assert_true(snapshot.has("has_outer_panel"), "reward snapshot exposes outer panel contract")
	_runner.assert_true(snapshot.has("has_title"), "reward snapshot exposes title contract")
	if not snapshot.has("visible_card_count") or not snapshot.has("has_backdrop") or not snapshot.has("has_outer_panel") or not snapshot.has("has_title"):
		return
	_runner.assert_eq(snapshot["visible_card_count"], 3, "reward choice renders only the three visible cards")
	_runner.assert_true(snapshot["has_backdrop"], "reward choice dims the full gameplay view behind the cards")
	_runner.assert_false(snapshot["has_outer_panel"], "reward choice removes the framed outer panel")
	_runner.assert_true(snapshot["has_title"], "reward choice keeps a visible room-clear reward title")
	_runner.assert_eq(snapshot.get("title", ""), "방 클리어 보상", "reward title names the modal purpose")
	_runner.assert_true(float(snapshot.get("dim_alpha", 0.0)) > 0.0, "reward backdrop is visible")
	_runner.assert_true(float(snapshot.get("dim_alpha", 0.0)) <= 0.35, "reward backdrop stays lightly dimmed")
	_runner.assert_true(snapshot.has("choice_title_font_sizes"), "reward snapshot exposes card title font sizes")
	_runner.assert_true(snapshot.has("choice_effect_font_sizes"), "reward snapshot exposes card effect font sizes")
	_runner.assert_true(snapshot.has("choice_title_outline_sizes"), "reward snapshot exposes card title outline sizes")
	_runner.assert_true(snapshot.has("choice_effect_outline_sizes"), "reward snapshot exposes card effect outline sizes")
	var title_font_sizes := snapshot.get("choice_title_font_sizes", []) as Array
	var effect_font_sizes := snapshot.get("choice_effect_font_sizes", []) as Array
	var title_outline_sizes := snapshot.get("choice_title_outline_sizes", []) as Array
	var effect_outline_sizes := snapshot.get("choice_effect_outline_sizes", []) as Array
	_runner.assert_eq(title_font_sizes.size(), 3, "reward snapshot tracks title font size for each card")
	_runner.assert_eq(effect_font_sizes.size(), 3, "reward snapshot tracks effect font size for each card")
	_runner.assert_eq(title_outline_sizes.size(), 3, "reward snapshot tracks title outline for each card")
	_runner.assert_eq(effect_outline_sizes.size(), 3, "reward snapshot tracks effect outline for each card")
	if title_font_sizes.size() == 3 and effect_font_sizes.size() == 3 and title_outline_sizes.size() == 3 and effect_outline_sizes.size() == 3:
		_runner.assert_true(int(title_font_sizes[0]) >= int(effect_font_sizes[0]) + 6, "reward card title reads larger than effect copy")
		_runner.assert_true(int(title_outline_sizes[0]) > int(effect_outline_sizes[0]), "reward card title uses stronger outline than effect copy")

	_runner.assert_true(_ui.select_reward_choice(&"dokkaebi_fire"), "reward choice can be selected by id")
	_runner.assert_eq(selected_ids, [&"dokkaebi_fire"], "selection emits item id once")
	_runner.assert_false(_ui.is_reward_choice_visible(), "selection hides reward choice overlay")


func test_reward_choice_onboarding_hint_explains_first_combat_reward() -> void:
	_runner.assert_true(_ui.has_method("set_reward_choice_onboarding_hint"), "reward UI can enable first-reward onboarding copy")
	if not _ui.has_method("set_reward_choice_onboarding_hint"):
		return

	_ui.call("set_reward_choice_onboarding_hint", true)
	_ui.show_reward_choices(&"combat_1", [
		{
			"item_id": &"dokkaebi_fire",
			"display_name": "도깨비불",
			"effect": "근접 공격 속도 +19% / 투척 속도 +19%",
		},
		{
			"item_id": &"wind_step",
			"display_name": "바람 매듭",
			"effect": "이동 속도 +15%",
		},
		{
			"item_id": &"moon_guard",
			"display_name": "달빛 호신부",
			"effect": "최대 체력 +1",
		},
	])

	var snapshot: Dictionary = _ui.get_reward_choice_snapshot()
	_runner.assert_true(snapshot.has("onboarding_hint_visible"), "reward snapshot exposes onboarding hint visibility")
	_runner.assert_true(snapshot.has("onboarding_hint_title"), "reward snapshot exposes onboarding hint title")
	_runner.assert_true(snapshot.has("onboarding_hint_body"), "reward snapshot exposes onboarding hint body")
	_runner.assert_true(snapshot.has("onboarding_hint_target_count"), "reward snapshot exposes how many cards the hint covers")
	if not snapshot.has("onboarding_hint_visible"):
		return
	_runner.assert_true(snapshot["onboarding_hint_visible"], "first reward onboarding hint is visible when enabled")
	_runner.assert_eq(snapshot.get("onboarding_hint_title", ""), "전투 보상", "hint title names the new reward moment")
	_runner.assert_true(String(snapshot.get("onboarding_hint_body", "")).contains("하나"), "hint body tells the player to choose one card")
	_runner.assert_eq(int(snapshot.get("onboarding_hint_target_count", 0)), 3, "hint points at the visible reward cards")

	_ui.hide_reward_choices()
	var hidden_snapshot: Dictionary = _ui.get_reward_choice_snapshot()
	_runner.assert_false(bool(hidden_snapshot.get("onboarding_hint_visible", true)), "hiding rewards hides the onboarding hint too")


func test_reward_choice_open_starts_slide_fade_animation() -> void:
	get_tree().paused = true

	_ui.show_reward_choices(&"combat_1", [
		{
			"item_id": &"dokkaebi_fire",
			"display_name": "도깨비불",
			"flavor": "푸른 불씨가 공격 타이밍을 앞당긴다.",
			"effect": "근접 공격 속도 +19%",
		},
	])

	_runner.assert_true(_ui.has_method("get_reward_choice_animation_snapshot"), "reward UI exposes animation state for tests")
	if not _ui.has_method("get_reward_choice_animation_snapshot"):
		return
	var snapshot: Dictionary = _ui.call("get_reward_choice_animation_snapshot")
	_runner.assert_true(snapshot["visible"], "reward overlay is visible before animation completes")
	_runner.assert_eq(snapshot["overlay_process_mode"], Node.PROCESS_MODE_ALWAYS, "reward overlay can animate while gameplay is paused")
	_runner.assert_true(snapshot.has("has_backdrop"), "reward animation snapshot exposes backdrop contract")
	_runner.assert_true(snapshot.has("has_outer_panel"), "reward animation snapshot exposes outer panel contract")
	_runner.assert_true(snapshot.has("card_alphas"), "reward animation snapshot exposes card alpha values")
	_runner.assert_true(snapshot.has("card_scales"), "reward animation snapshot exposes card scale values")
	if not snapshot.has("has_backdrop") or not snapshot.has("has_outer_panel") or not snapshot.has("card_alphas") or not snapshot.has("card_scales"):
		return
	_runner.assert_true(snapshot["has_backdrop"], "reward animation includes the dimmed full-screen backdrop")
	_runner.assert_false(snapshot["has_outer_panel"], "reward animation has no outer panel frame")
	_runner.assert_eq(snapshot.get("title", ""), "방 클리어 보상", "reward animation snapshot exposes the visible title")
	_runner.assert_true(float(snapshot.get("dim_alpha", 0.0)) <= 0.35, "reward animation keeps the backdrop subtle")
	var card_alphas: Array = snapshot["card_alphas"]
	var card_scales: Array = snapshot["card_scales"]
	_runner.assert_eq(card_alphas.size(), 1, "animation tracks the rendered reward card")
	_runner.assert_eq(card_alphas[0], 0.0, "reward card starts transparent for fade-in")
	_runner.assert_true((card_scales[0] as Vector2).x < 1.0, "reward card starts slightly smaller for pop-in")


func test_reward_choice_cards_keep_ornament_height_fixed() -> void:
	_ui.show_reward_choices(&"combat_1", [
		{
			"item_id": &"dokkaebi_fire",
			"display_name": "도깨비불",
			"effect": "근접 공격 속도 +19%",
		},
		{
			"item_id": &"shadow_knot",
			"display_name": "그림자 매듭",
			"effect": "회피 무적 +0.25초",
		},
		{
			"item_id": &"breathing_room",
			"display_name": "숨 고르기",
			"effect": "다음 전투방부터 방 클리어 시 체력 +1",
		},
	])

	var snapshot: Dictionary = _ui.get_reward_choice_snapshot()
	_runner.assert_true(snapshot.has("choice_card_heights"), "reward snapshot exposes card heights")
	_runner.assert_true(snapshot.has("choice_card_ornament_heights"), "reward snapshot exposes fixed ornament heights")
	_runner.assert_true(snapshot.has("choice_card_content_expands"), "reward snapshot exposes which layer takes vertical stretch")
	_runner.assert_true(snapshot.has("choice_card_background_texture_paths"), "reward snapshot exposes stretchable card background style")
	_runner.assert_true(snapshot.has("choice_card_ornament_texture_paths"), "reward snapshot exposes fixed ornament texture")
	if not snapshot.has("choice_card_heights") or not snapshot.has("choice_card_ornament_heights") or not snapshot.has("choice_card_content_expands") or not snapshot.has("choice_card_background_texture_paths") or not snapshot.has("choice_card_ornament_texture_paths"):
		return
	var card_heights := snapshot["choice_card_heights"] as Array
	var ornament_heights := snapshot["choice_card_ornament_heights"] as Array
	var content_expands := snapshot["choice_card_content_expands"] as Array
	var background_paths := snapshot["choice_card_background_texture_paths"] as Array
	var ornament_paths := snapshot["choice_card_ornament_texture_paths"] as Array
	_runner.assert_eq(card_heights.size(), 3, "reward snapshot tracks every card height")
	_runner.assert_eq(ornament_heights.size(), 3, "reward snapshot tracks every ornament height")
	_runner.assert_eq(content_expands.size(), 3, "reward snapshot tracks every content stack")
	if card_heights.size() == 3 and ornament_heights.size() == 3 and content_expands.size() == 3:
		_runner.assert_eq(float(card_heights[0]), 146.0, "reward card keeps the mobile landscape card height")
		_runner.assert_eq(float(ornament_heights[0]), 49.0, "flower ornament keeps the source art height")
		_runner.assert_true(float(ornament_heights[0]) < float(card_heights[0]) * 0.5, "ornament does not stretch to fill the whole card")
		_runner.assert_true(bool(content_expands[0]), "card text/content layer takes the vertical slack")
	if background_paths.size() == 3 and ornament_paths.size() == 3:
		_runner.assert_eq(String(background_paths[0]), "", "stretchable card background does not use the flower button texture")
		_runner.assert_eq(String(ornament_paths[0]), PixelButtonStyle.NORMAL_TEXTURE_PATH, "fixed ornament layer uses the existing flower button art")


func test_summary_hides_unlock_records_for_mvp_result_layout() -> void:
	_ui.show_summary({
		"completed": true,
		"memory_reward": 8,
		"students_rescued": 0,
		"friends_purified": 1,
		"rooms_cleared": 8,
		"unlocks": [&"baseball_stage_3", &"awakened_bat"],
	})

	var snapshot: Dictionary = _ui.get_summary_snapshot()
	_runner.assert_eq(snapshot["unlocks"], "", "result summary hides unlock rows during gameplay")


func test_visible_session_actions_use_pixel_button_skin() -> void:
	_assert_pixel_button_style(_ui.get_node("%MapTabButton") as Button, PixelButtonStyle.VARIANT_PRIMARY, "map tab")
	_assert_pixel_button_style(_ui.get_node("%ReturnButton") as Button, PixelButtonStyle.VARIANT_DANGER, "return")
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


func _assert_card_frame_style(
	style: StyleBox,
	expected_modulate: Color,
	expected_texture_margin: float,
	expected_content_margin: Vector2,
	message: String
) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses the shared textured card frame" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, "res://assets/ui/panels/card_frame.png", "%s texture" % message)
	_runner.assert_eq(texture_style.texture_margin_left, expected_texture_margin, "%s left 9-slice margin" % message)
	_runner.assert_eq(texture_style.content_margin_left, expected_content_margin.x, "%s horizontal content padding" % message)
	_runner.assert_eq(texture_style.content_margin_top, expected_content_margin.y, "%s vertical content padding" % message)
	_runner.assert_eq(texture_style.modulate_color, expected_modulate, "%s selected weapon-card tint" % message)


func _assert_transparent_panel_style(path: String, label: String) -> void:
	var panel := _ui.get_node(path) as PanelContainer
	_runner.assert_not_null(panel, "%s panel exists" % label)
	if panel == null:
		return
	var flat_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	_runner.assert_not_null(flat_style, "%s uses a transparent flat style" % label)
	if flat_style == null:
		return
	_runner.assert_eq(flat_style.bg_color.a, 0.0, "%s has no colored fill" % label)
	_runner.assert_eq(flat_style.border_color.a, 0.0, "%s has no colored border" % label)
	_runner.assert_eq(flat_style.border_width_left, 0, "%s left border is removed" % label)
	_runner.assert_eq(flat_style.border_width_top, 0, "%s top border is removed" % label)
	_runner.assert_eq(flat_style.border_width_right, 0, "%s right border is removed" % label)
	_runner.assert_eq(flat_style.border_width_bottom, 0, "%s bottom border is removed" % label)
