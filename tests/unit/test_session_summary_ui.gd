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
	_runner.assert_eq(snapshot["memory_label"], "기억 조각", "permanent reward label is concise")
	_runner.assert_eq(snapshot["memory_amount"], "+42", "permanent reward is the largest result number")
	_runner.assert_eq(snapshot["students"], "구출 3", "rescued students render as a record chip")
	_runner.assert_eq(snapshot["friends"], "친구 1", "purified friends render as a record chip")
	_runner.assert_eq(snapshot["rooms"], "방 18", "room count renders as a record chip")
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
	_runner.assert_eq(return_button.text, "학교로 귀환", "return action copy is stable")
	_runner.assert_eq(retry_button.text, "재도전", "retry action copy is stable")
	retry_button.pressed.emit()
	return_button.pressed.emit()

	_runner.assert_eq(counts["return"], 1, "return button emits return flow")
	_runner.assert_eq(counts["retry"], 1, "retry button emits retry flow")


func test_action_buttons_use_pixel_button_skin() -> void:
	_assert_pixel_button_style(_ui.get_node("%PauseButton") as Button, PixelButtonStyle.VARIANT_SECONDARY, "pause")
	_assert_pixel_button_style(_ui.get_node("%ResumeButton") as Button, PixelButtonStyle.VARIANT_PRIMARY, "resume")
	_assert_pixel_button_style(_ui.get_node("%FinishButton") as Button, PixelButtonStyle.VARIANT_DANGER, "finish")
	_assert_pixel_button_style(_ui.get_node("%ReturnButton") as Button, PixelButtonStyle.VARIANT_PRIMARY, "return")
	_assert_pixel_button_style(_ui.get_node("%RetryButton") as Button, PixelButtonStyle.VARIANT_SECONDARY, "retry")


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
