extends CanvasLayer

const RenderLayers = preload("res://scripts/constants/render_layers.gd")

signal pause_requested
signal resume_requested
signal finish_requested
signal return_requested
signal retry_requested
signal reward_choice_selected(item_id: StringName)

const DEFAULT_MEMORY_REWARD_PER_ROOM := 1
const DEFAULT_MAP_NAME := "경복궁"
const MAP_TAB_TEST_ID := "session.map_tab"
const MAP_TAB_ACTION := "session.map_tab"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const REWARD_CHOICE_DIM_ALPHA := 0.66
const REWARD_CHOICE_PANEL_OFFSET_LEFT := -380.0
const REWARD_CHOICE_PANEL_OFFSET_TOP := -164.0
const REWARD_CHOICE_PANEL_OFFSET_RIGHT := 380.0
const REWARD_CHOICE_PANEL_OFFSET_BOTTOM := 164.0
const REWARD_CHOICE_PANEL_SLIDE_OFFSET := 36.0
const REWARD_CHOICE_OPEN_DURATION := 0.18
const UNLOCK_LABELS := {
	&"baseball_stage_3": "야구부 3단계",
	&"awakened_bat": "마지막 시즌의 배트",
}

@onready var map_tab_button: Button = %MapTabButton
@onready var top_panel: Control = $Root/TopPanel
@onready var status_label: Label = %StatusLabel
@onready var interaction_label: Label = %InteractionLabel
@onready var summary_overlay: Control = %SummaryOverlay
@onready var result_title_label: Label = %ResultTitleLabel
@onready var narrative_label: Label = %NarrativeLabel
@onready var memory_label: Label = %MemoryLabel
@onready var memory_amount_label: Label = %MemoryAmountLabel
@onready var students_record_label: Label = %StudentsRecordLabel
@onready var friends_record_label: Label = %FriendsRecordLabel
@onready var rooms_record_label: Label = %RoomsRecordLabel
@onready var unlocks_record_panel: PanelContainer = %UnlocksRecordPanel
@onready var unlocks_record_label: Label = %UnlocksRecordLabel
@onready var return_button: Button = %ReturnButton
@onready var retry_button: Button = %RetryButton

var _reward_choice_overlay: Control = null
var _reward_choice_dim: ColorRect = null
var _reward_choice_panel: PanelContainer = null
var _reward_choice_row: HBoxContainer = null
var _reward_choice_room_id: StringName = &""
var _reward_choice_models: Array[Dictionary] = []
var _reward_choice_open_tween: Tween = null


func _ready() -> void:
	layer = RenderLayers.UI_SESSION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_reward_choice_overlay()
	map_tab_button.set_meta("test_id", MAP_TAB_TEST_ID)
	map_tab_button.set_meta("uat_action", MAP_TAB_ACTION)
	return_button.set_meta("test_id", "session.return_button")
	return_button.set_meta("uat_action", "session.return_to_school")
	retry_button.set_meta("test_id", "session.retry_button")
	retry_button.set_meta("uat_action", "session.retry")
	_apply_landscape_safe_area()
	_apply_button_styles()
	_apply_result_panel_styles()
	map_tab_button.pressed.connect(_on_map_tab_button_pressed)
	return_button.pressed.connect(_on_return_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	set_map_name(DEFAULT_MAP_NAME)
	top_panel.visible = false
	status_label.text = ""
	interaction_label.text = ""
	show_summary({})


func _apply_landscape_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	MobileSafeArea.apply_edge_offsets(map_tab_button, float(insets["left"]), float(insets["top"]), -1.0, -1.0)
	MobileSafeArea.apply_edge_offsets(top_panel, -1.0, float(insets["top"]), float(insets["right"]), -1.0)
	top_panel.offset_left = map_tab_button.offset_right + 16.0


func _apply_result_panel_styles() -> void:
	# Build the summary/result panels through the shared DungeonUiTheme builder
	# instead of five hand-authored scene StyleBoxFlats. Colors, border widths and
	# corner radii are preserved 1:1; margins stay 0 (panels handle their own).
	const PANEL := "Root/SummaryOverlay/SummaryPanel"
	const CONTENT := PANEL + "/SummaryMargin/SummaryStack/SummaryContent"
	const RECORDS := CONTENT + "/RecordsStack"
	const GOLD := Color(0.784314, 0.631373, 0.227451, 1)
	const GREEN_BG := Color(0.129412, 0.231373, 0.12549, 1)
	const GREEN_BORDER := Color(0.352941, 0.490196, 0.352941, 1)
	_style_panel(PANEL, Color(0.0352941, 0.0980392, 0.0627451, 0.96), GOLD, 2, 4)
	_style_panel(CONTENT + "/RewardPanel", Color(0.0705882, 0.184314, 0.105882, 1), GOLD, 1, 3)
	_style_panel(RECORDS + "/StudentsRecordPanel", GREEN_BG, GREEN_BORDER, 1, 3)
	_style_panel(RECORDS + "/FriendsRecordPanel", Color(0.0980392, 0.172549, 0.254902, 1), Color(0.227451, 0.431373, 0.647059, 1), 1, 3)
	_style_panel(RECORDS + "/RoomsRecordPanel", Color(0.164706, 0.105882, 0.2, 1), Color(0.415686, 0.227451, 0.541176, 1), 1, 3)
	_style_panel(RECORDS + "/UnlocksRecordPanel", GREEN_BG, GREEN_BORDER, 1, 3)


func _style_panel(path: String, bg: Color, border: Color, width: int, corner: int) -> void:
	var panel := get_node_or_null(path) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", DungeonUiTheme.panel_style(bg, border, width, 0.0, 0.0, corner))


func set_status(text: String) -> void:
	status_label.text = text


func set_map_name(text: String) -> void:
	var map_name := text.strip_edges()
	map_tab_button.text = map_name if map_name != "" else DEFAULT_MAP_NAME


func get_map_name() -> String:
	return map_tab_button.text


func set_interaction_count(count: int) -> void:
	interaction_label.text = "진행도 %d" % count


func show_summary(result: Dictionary) -> void:
	if result.is_empty():
		summary_overlay.visible = false
		return

	var summary := _build_summary(result)
	result_title_label.text = summary["title"]
	narrative_label.text = summary["narrative"]
	memory_label.text = "기억 조각"
	memory_amount_label.text = "+%d" % int(summary["memory_reward"])
	students_record_label.text = "구출 %d" % int(summary["students_rescued"])
	friends_record_label.text = "정화 %d" % int(summary["friends_purified"])
	rooms_record_label.text = "방 %d" % int(summary["rooms_cleared"])
	var unlock_labels: Array[String] = summary["unlocks"]
	unlocks_record_panel.visible = not unlock_labels.is_empty()
	unlocks_record_label.text = "해금 %s" % " / ".join(unlock_labels) if not unlock_labels.is_empty() else ""
	summary_overlay.visible = true
	hide_reward_choices()


func get_summary_snapshot() -> Dictionary:
	return {
		"visible": summary_overlay.visible,
		"title": result_title_label.text,
		"narrative": narrative_label.text,
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
	if _reward_choice_models.is_empty():
		hide_reward_choices()
		return
	_show_reward_choice_overlay_animated()


func hide_reward_choices() -> void:
	_kill_reward_choice_open_tween()
	if _reward_choice_overlay != null:
		_reward_choice_overlay.visible = false
	_reset_reward_choice_animation_to_rest()


func is_reward_choice_visible() -> bool:
	return _reward_choice_overlay != null and _reward_choice_overlay.visible


func is_action_panel_visible() -> bool:
	return false


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
	var effects: Array[String] = []
	for choice: Dictionary in _reward_choice_models:
		texts.append(String(choice.get("display_name", "")))
		flavors.append(String(choice.get("flavor", "")))
		effects.append(String(choice.get("effect", "")))
	return {
		"visible": is_reward_choice_visible(),
		"room_id": _reward_choice_room_id,
		"choice_ids": get_reward_choice_ids(),
		"choice_texts": texts,
		"choice_flavors": flavors,
		"choice_effects": effects,
	}


func get_reward_choice_animation_snapshot() -> Dictionary:
	_ensure_reward_choice_overlay()
	return {
		"visible": is_reward_choice_visible(),
		"overlay_process_mode": _reward_choice_overlay.process_mode,
		"dim_alpha": _reward_choice_dim.modulate.a,
		"panel_alpha": _reward_choice_panel.modulate.a,
		"panel_offset_top": _reward_choice_panel.offset_top,
		"target_offset_top": REWARD_CHOICE_PANEL_OFFSET_TOP,
		"panel_offset_bottom": _reward_choice_panel.offset_bottom,
		"target_offset_bottom": REWARD_CHOICE_PANEL_OFFSET_BOTTOM,
		"slide_offset": REWARD_CHOICE_PANEL_SLIDE_OFFSET,
	}


func _apply_button_styles() -> void:
	PixelButtonStyle.apply(map_tab_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(144.0, 50.0))
	PixelButtonStyle.apply(return_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(retry_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(0.0, 58.0))


func _ensure_reward_choice_overlay() -> void:
	if _reward_choice_overlay != null and is_instance_valid(_reward_choice_overlay):
		return
	var root := get_node("Root") as Control
	_reward_choice_overlay = Control.new()
	_reward_choice_overlay.name = "RewardChoiceOverlay"
	_reward_choice_overlay.visible = false
	_reward_choice_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_reward_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward_choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_reward_choice_overlay)

	var dim := ColorRect.new()
	dim.name = "RewardChoiceDim"
	dim.color = Color(0.0156863, 0.0156863, 0.0235294, REWARD_CHOICE_DIM_ALPHA)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reward_choice_overlay.add_child(dim)
	_reward_choice_dim = dim

	var panel := PanelContainer.new()
	panel.name = "RewardChoicePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = REWARD_CHOICE_PANEL_OFFSET_LEFT
	panel.offset_top = REWARD_CHOICE_PANEL_OFFSET_TOP
	panel.offset_right = REWARD_CHOICE_PANEL_OFFSET_RIGHT
	panel.offset_bottom = REWARD_CHOICE_PANEL_OFFSET_BOTTOM
	panel.add_theme_stylebox_override("panel", _reward_choice_panel_style())
	_reward_choice_overlay.add_child(panel)
	_reward_choice_panel = panel

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

	_reset_reward_choice_animation_to_rest()


func _show_reward_choice_overlay_animated() -> void:
	_kill_reward_choice_open_tween()
	_reward_choice_overlay.visible = true
	_reward_choice_dim.modulate.a = 0.0
	_reward_choice_panel.modulate.a = 0.0
	_reward_choice_panel.offset_top = REWARD_CHOICE_PANEL_OFFSET_TOP + REWARD_CHOICE_PANEL_SLIDE_OFFSET
	_reward_choice_panel.offset_bottom = REWARD_CHOICE_PANEL_OFFSET_BOTTOM + REWARD_CHOICE_PANEL_SLIDE_OFFSET

	_reward_choice_open_tween = create_tween()
	_reward_choice_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reward_choice_open_tween.set_parallel(true)
	_reward_choice_open_tween.tween_property(_reward_choice_dim, "modulate:a", 1.0, REWARD_CHOICE_OPEN_DURATION)
	_reward_choice_open_tween.tween_property(_reward_choice_panel, "modulate:a", 1.0, REWARD_CHOICE_OPEN_DURATION)
	_reward_choice_open_tween.tween_property(_reward_choice_panel, "offset_top", REWARD_CHOICE_PANEL_OFFSET_TOP, REWARD_CHOICE_OPEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reward_choice_open_tween.tween_property(_reward_choice_panel, "offset_bottom", REWARD_CHOICE_PANEL_OFFSET_BOTTOM, REWARD_CHOICE_OPEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _kill_reward_choice_open_tween() -> void:
	if _reward_choice_open_tween != null:
		_reward_choice_open_tween.kill()
		_reward_choice_open_tween = null


func _reset_reward_choice_animation_to_rest() -> void:
	if _reward_choice_dim != null:
		_reward_choice_dim.modulate.a = 1.0
	if _reward_choice_panel != null:
		_reward_choice_panel.modulate.a = 1.0
		_reward_choice_panel.offset_left = REWARD_CHOICE_PANEL_OFFSET_LEFT
		_reward_choice_panel.offset_top = REWARD_CHOICE_PANEL_OFFSET_TOP
		_reward_choice_panel.offset_right = REWARD_CHOICE_PANEL_OFFSET_RIGHT
		_reward_choice_panel.offset_bottom = REWARD_CHOICE_PANEL_OFFSET_BOTTOM


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
		var effect := String(choice.get("effect", ""))
		var button := Button.new()
		button.name = "RewardChoice%sButton" % _node_suffix_for_reward_id(item_id)
		button.text = _reward_choice_button_text(display_name, flavor, effect)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(228.0, 138.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 20)
		button.set_meta("test_id", "session.reward_choice.%s" % String(item_id))
		button.set_meta("uat_action", "session.reward_choice.%s" % String(item_id))
		button.pressed.connect(_on_reward_choice_pressed.bind(item_id))
		PixelButtonStyle.apply(button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(228.0, 138.0))
		_reward_choice_row.add_child(button)


func _reward_choice_button_text(display_name: String, flavor: String, effect: String) -> String:
	var parts: Array[String] = [display_name]
	if flavor != "":
		parts.append(flavor)
	if effect != "":
		parts.append("효과: %s" % effect)
	return "\n".join(parts)


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
		"narrative": _result_narrative(result),
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
	return "밤 종료"


func _result_narrative(result: Dictionary) -> String:
	var outcome := String(result.get("outcome", "")).to_lower()
	if outcome in ["death", "dead", "failed"] or bool(result.get("died", false)):
		return "새벽 종소리와 함께 교실에서 눈을 떴다. 기억 조각은 손에 남아 있다."
	if bool(result.get("completed", false)) or String(result.get("reason", "")) == "boss_resolved" or outcome in ["success", "escaped", "complete", "completed"]:
		return "친구의 기억이 조금 돌아왔다. 학교로 돌아가 말을 걸어보자."
	return "오늘 밤의 기록을 챙겼다. 학교에서 정비한 뒤 다시 나갈 수 있다."


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


func _on_map_tab_button_pressed() -> void:
	if get_tree().paused:
		resume_requested.emit()
	else:
		pause_requested.emit()


func _on_return_button_pressed() -> void:
	return_requested.emit()


func _on_retry_button_pressed() -> void:
	retry_requested.emit()
