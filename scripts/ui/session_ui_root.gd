extends CanvasLayer

const RenderLayers = preload("res://scripts/constants/render_layers.gd")

signal pause_requested
signal resume_requested
signal finish_requested
signal return_requested
signal retry_requested
signal reward_choice_selected(item_id: StringName)

const DEFAULT_MEMORY_REWARD_PER_ROOM := 1
const UNLOCK_LABELS := {
	&"baseball_stage_3": "야구부 STAGE 3",
	&"awakened_bat": "마지막 시즌의 배트",
}

@onready var status_label: Label = %StatusLabel
@onready var interaction_label: Label = %InteractionLabel
@onready var action_panel: Control = %ActionPanel
@onready var summary_overlay: Control = %SummaryOverlay
@onready var result_title_label: Label = %ResultTitleLabel
@onready var memory_label: Label = %MemoryLabel
@onready var memory_amount_label: Label = %MemoryAmountLabel
@onready var students_record_label: Label = %StudentsRecordLabel
@onready var friends_record_label: Label = %FriendsRecordLabel
@onready var rooms_record_label: Label = %RoomsRecordLabel
@onready var unlocks_record_panel: PanelContainer = %UnlocksRecordPanel
@onready var unlocks_record_label: Label = %UnlocksRecordLabel
@onready var pause_button: Button = %PauseButton
@onready var resume_button: Button = %ResumeButton
@onready var finish_button: Button = %FinishButton
@onready var return_button: Button = %ReturnButton
@onready var retry_button: Button = %RetryButton

var _reward_choice_overlay: Control = null
var _reward_choice_row: HBoxContainer = null
var _reward_choice_room_id: StringName = &""
var _reward_choice_models: Array[Dictionary] = []


func _ready() -> void:
	layer = RenderLayers.UI_SESSION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_reward_choice_overlay()
	pause_button.set_meta("test_id", "session.pause_button")
	pause_button.set_meta("uat_action", "session.pause")
	resume_button.set_meta("test_id", "session.resume_button")
	resume_button.set_meta("uat_action", "session.resume")
	finish_button.set_meta("test_id", "session.finish_button")
	finish_button.set_meta("uat_action", "session.finish")
	return_button.set_meta("test_id", "session.return_button")
	return_button.set_meta("uat_action", "session.return_to_school")
	retry_button.set_meta("test_id", "session.retry_button")
	retry_button.set_meta("uat_action", "session.retry")
	_apply_button_styles()
	pause_button.pressed.connect(_on_pause_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	finish_button.pressed.connect(_on_finish_button_pressed)
	return_button.pressed.connect(_on_return_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	set_status("Ready")
	set_interaction_count(0)
	show_summary({})


func set_status(text: String) -> void:
	status_label.text = text


func set_interaction_count(count: int) -> void:
	interaction_label.text = "Interactions: %d" % count


func show_summary(result: Dictionary) -> void:
	if result.is_empty():
		summary_overlay.visible = false
		action_panel.visible = not is_reward_choice_visible()
		return

	var summary := _build_summary(result)
	result_title_label.text = summary["title"]
	memory_label.text = "기억 조각"
	memory_amount_label.text = "+%d" % int(summary["memory_reward"])
	students_record_label.text = "구출 %d" % int(summary["students_rescued"])
	friends_record_label.text = "친구 %d" % int(summary["friends_purified"])
	rooms_record_label.text = "방 %d" % int(summary["rooms_cleared"])
	var unlock_labels: Array[String] = summary["unlocks"]
	unlocks_record_panel.visible = not unlock_labels.is_empty()
	unlocks_record_label.text = "해금 %s" % " / ".join(unlock_labels) if not unlock_labels.is_empty() else ""
	summary_overlay.visible = true
	action_panel.visible = false
	hide_reward_choices()


func get_summary_snapshot() -> Dictionary:
	return {
		"visible": summary_overlay.visible,
		"title": result_title_label.text,
		"memory_label": memory_label.text,
		"memory_amount": memory_amount_label.text,
		"students": students_record_label.text,
		"friends": friends_record_label.text,
		"rooms": rooms_record_label.text,
		"unlocks": unlocks_record_label.text if unlocks_record_panel.visible else "",
	}


func is_summary_visible() -> bool:
	return summary_overlay.visible


func show_reward_choices(room_id: StringName, choices: Array) -> void:
	_ensure_reward_choice_overlay()
	_reward_choice_room_id = room_id
	_reward_choice_models.clear()
	for choice: Dictionary in choices:
		_reward_choice_models.append(choice.duplicate(true))
	_render_reward_choices()
	_reward_choice_overlay.visible = not _reward_choice_models.is_empty()
	action_panel.visible = not _reward_choice_overlay.visible and not summary_overlay.visible


func hide_reward_choices() -> void:
	if _reward_choice_overlay != null:
		_reward_choice_overlay.visible = false
	if not summary_overlay.visible:
		action_panel.visible = true


func is_reward_choice_visible() -> bool:
	return _reward_choice_overlay != null and _reward_choice_overlay.visible


func select_reward_choice(item_id: StringName) -> bool:
	if not is_reward_choice_visible():
		return false
	if not get_reward_choice_ids().has(item_id):
		return false
	hide_reward_choices()
	reward_choice_selected.emit(item_id)
	return true


func get_reward_choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: Dictionary in _reward_choice_models:
		ids.append(StringName(choice.get("item_id", &"")))
	return ids


func get_reward_choice_snapshot() -> Dictionary:
	var texts: Array[String] = []
	var flavors: Array[String] = []
	for choice: Dictionary in _reward_choice_models:
		texts.append(String(choice.get("display_name", "")))
		flavors.append(String(choice.get("flavor", "")))
	return {
		"visible": is_reward_choice_visible(),
		"room_id": _reward_choice_room_id,
		"choice_ids": get_reward_choice_ids(),
		"choice_texts": texts,
		"choice_flavors": flavors,
	}


func _apply_button_styles() -> void:
	PixelButtonStyle.apply(pause_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(resume_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(finish_button, PixelButtonStyle.VARIANT_DANGER, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(return_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(retry_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(0.0, 58.0))


func _ensure_reward_choice_overlay() -> void:
	if _reward_choice_overlay != null and is_instance_valid(_reward_choice_overlay):
		return
	var root := get_node("Root") as Control
	_reward_choice_overlay = Control.new()
	_reward_choice_overlay.name = "RewardChoiceOverlay"
	_reward_choice_overlay.visible = false
	_reward_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward_choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_reward_choice_overlay)

	var dim := ColorRect.new()
	dim.name = "RewardChoiceDim"
	dim.color = Color(0.0156863, 0.0156863, 0.0235294, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reward_choice_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "RewardChoicePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380.0
	panel.offset_top = -164.0
	panel.offset_right = 380.0
	panel.offset_bottom = 164.0
	panel.add_theme_stylebox_override("panel", _reward_choice_panel_style())
	_reward_choice_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "RewardChoiceMargin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "RewardChoiceStack"
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "RewardChoiceTitle"
	title.text = "전투 보상"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.937255, 0.811765, 0.298039, 1.0))
	stack.add_child(title)

	_reward_choice_row = HBoxContainer.new()
	_reward_choice_row.name = "RewardChoiceRow"
	_reward_choice_row.add_theme_constant_override("separation", 12)
	stack.add_child(_reward_choice_row)


func _reward_choice_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0352941, 0.0980392, 0.0627451, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.784314, 0.631373, 0.227451, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func _render_reward_choices() -> void:
	_ensure_reward_choice_overlay()
	for child: Node in _reward_choice_row.get_children():
		_reward_choice_row.remove_child(child)
		child.queue_free()
	for choice: Dictionary in _reward_choice_models:
		var item_id := StringName(choice.get("item_id", &""))
		var display_name := String(choice.get("display_name", String(item_id)))
		var flavor := String(choice.get("flavor", ""))
		var button := Button.new()
		button.name = "RewardChoice%sButton" % _node_suffix_for_reward_id(item_id)
		button.text = "%s\n%s" % [display_name, flavor] if flavor != "" else display_name
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(228.0, 118.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 22)
		button.set_meta("test_id", "session.reward_choice.%s" % String(item_id))
		button.set_meta("uat_action", "session.reward_choice.%s" % String(item_id))
		button.pressed.connect(_on_reward_choice_pressed.bind(item_id))
		PixelButtonStyle.apply(button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(228.0, 118.0))
		_reward_choice_row.add_child(button)


func _node_suffix_for_reward_id(item_id: StringName) -> String:
	var suffix := ""
	for part: String in String(item_id).split("_", false):
		suffix += part.capitalize()
	return suffix


func _on_reward_choice_pressed(item_id: StringName) -> void:
	select_reward_choice(item_id)


func _build_summary(result: Dictionary) -> Dictionary:
	return {
		"title": _result_title(result),
		"memory_reward": _memory_reward(result),
		"students_rescued": _count_from_keys(result, [
			"students_rescued",
			"rescued_students",
			"student_count",
			"rescued_student_count",
		], [
			"student_ids",
			"rescued_student_ids",
		]),
		"friends_purified": _friends_purified(result),
		"rooms_cleared": _rooms_cleared(result),
		"unlocks": _unlock_labels(result),
	}


func _result_title(result: Dictionary) -> String:
	var outcome := String(result.get("outcome", "")).to_lower()
	if outcome in ["death", "dead", "failed"]:
		return "쓰러짐"
	if bool(result.get("died", false)):
		return "쓰러짐"
	if bool(result.get("completed", false)):
		return "탈출 성공"
	if String(result.get("reason", "")) == "boss_resolved":
		return "탈출 성공"
	if outcome in ["success", "escaped", "complete", "completed"]:
		return "탈출 성공"
	return "런 종료"


func _memory_reward(result: Dictionary) -> int:
	var explicit := _count_entry(result, [
		"memory_reward",
		"memory_shards",
		"memory_shard_delta",
		"permanent_reward",
		"permanent_currency_delta",
		"permanent_amount",
		"reward_amount",
	], [])
	if bool(explicit["found"]):
		return int(explicit["count"])

	var cleared_rooms := _rooms_cleared(result)
	return cleared_rooms * DEFAULT_MEMORY_REWARD_PER_ROOM


func _friends_purified(result: Dictionary) -> int:
	var explicit := _count_entry(result, [
		"friends_purified",
		"purified_friends",
		"friend_count",
		"purified_friend_count",
	], [
		"friend_ids",
		"purified_friend_ids",
	])
	if bool(explicit["found"]):
		return int(explicit["count"])
	if result.has("boss_id") or String(result.get("reason", "")) == "boss_resolved":
		return 1
	if bool(result.get("boss_defeated", false)):
		return 1
	return 0


func _rooms_cleared(result: Dictionary) -> int:
	var explicit := _count_entry(result, [
		"rooms_cleared",
		"cleared_rooms",
		"room_count",
		"cleared_room_count",
	], [
		"cleared_room_ids",
	])
	if bool(explicit["found"]):
		return int(explicit["count"])
	return _array_count(result.get("visited_room_ids", []))


func _unlock_labels(result: Dictionary) -> Array[String]:
	var labels: Array[String] = []
	for unlock: Variant in result.get("unlocks", []):
		var unlock_id := StringName(unlock)
		var label := String(UNLOCK_LABELS.get(unlock_id, String(unlock_id)))
		if label != "" and not labels.has(label):
			labels.append(label)
	return labels


func _count_from_keys(result: Dictionary, scalar_keys: Array[String], collection_keys: Array[String]) -> int:
	return int(_count_entry(result, scalar_keys, collection_keys)["count"])


func _count_entry(result: Dictionary, scalar_keys: Array[String], collection_keys: Array[String]) -> Dictionary:
	for key: String in scalar_keys:
		if result.has(key):
			return {"found": true, "count": _non_negative_int(result[key])}
	for key: String in collection_keys:
		if result.has(key):
			return {"found": true, "count": _array_count(result[key])}
	return {"found": false, "count": 0}


func _array_count(value: Variant) -> int:
	if value is Array:
		return value.size()
	if value is PackedStringArray:
		return value.size()
	return 0


func _non_negative_int(value: Variant) -> int:
	var parsed := 0
	if value is int:
		parsed = value
	elif value is float:
		parsed = int(value)
	else:
		var text := str(value)
		if text.is_valid_int():
			parsed = int(text)
	return maxi(0, parsed)


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


func _on_resume_button_pressed() -> void:
	resume_requested.emit()


func _on_finish_button_pressed() -> void:
	finish_requested.emit()


func _on_return_button_pressed() -> void:
	return_requested.emit()


func _on_retry_button_pressed() -> void:
	retry_requested.emit()
