extends CanvasLayer

const RenderLayers = preload("res://scripts/constants/render_layers.gd")

signal pause_requested
signal resume_requested
signal finish_requested
signal return_requested
signal retry_requested

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


func _ready() -> void:
	layer = RenderLayers.UI_SESSION_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_apply_result_panel_styles()
	pause_button.pressed.connect(_on_pause_button_pressed)
	resume_button.pressed.connect(_on_resume_button_pressed)
	finish_button.pressed.connect(_on_finish_button_pressed)
	return_button.pressed.connect(_on_return_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	set_status("Ready")
	set_interaction_count(0)
	show_summary({})


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


func set_interaction_count(count: int) -> void:
	interaction_label.text = "Interactions: %d" % count


func show_summary(result: Dictionary) -> void:
	if result.is_empty():
		summary_overlay.visible = false
		action_panel.visible = true
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


func _apply_button_styles() -> void:
	PixelButtonStyle.apply(pause_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(resume_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(finish_button, PixelButtonStyle.VARIANT_DANGER, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(return_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(0.0, 58.0))
	PixelButtonStyle.apply(retry_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(0.0, 58.0))


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
