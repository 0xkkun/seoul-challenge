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
const FontRoles := preload("res://scripts/ui/ui_font_roles.gd")
const REWARD_CHOICE_ROW_OFFSET_LEFT := -390.0
const REWARD_CHOICE_ROW_OFFSET_TOP := -84.0
const REWARD_CHOICE_ROW_OFFSET_RIGHT := 390.0
const REWARD_CHOICE_ROW_OFFSET_BOTTOM := 84.0
const REWARD_CHOICE_TITLE_TEXT := "방 클리어 보상"
const REWARD_CHOICE_TITLE_OFFSET_TOP := -170.0
const REWARD_CHOICE_TITLE_OFFSET_BOTTOM := -124.0
const REWARD_CHOICE_CARD_SIZE := Vector2(244.0, 146.0)
const REWARD_CHOICE_DIM_ALPHA := 0.28
const REWARD_CHOICE_CARD_TITLE_FONT_SIZE := 25
const REWARD_CHOICE_CARD_EFFECT_FONT_SIZE := 15
const REWARD_CHOICE_CARD_TITLE_OUTLINE := 4
const REWARD_CHOICE_CARD_EFFECT_OUTLINE := 1
const REWARD_CHOICE_CARD_TITLE_COLOR := Color(1.0, 0.835294, 0.258824, 1.0)
const REWARD_CHOICE_CARD_EFFECT_COLOR := Color(0.88, 0.86, 0.66, 0.94)
const REWARD_CHOICE_OPEN_DURATION := 0.18
const REWARD_CHOICE_CARD_STAGGER := 0.045
const REWARD_CHOICE_CARD_START_SCALE := Vector2(0.94, 0.94)
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
var _reward_choice_title_label: Label = null
var _reward_choice_row: HBoxContainer = null
var _reward_choice_cards: Array[Button] = []
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
	_apply_font_roles()
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
	# Main frame uses the shared textured popup frame (gold-on-navy ornaments) so the
	# results screen matches the buttons; the inner record/reward panels keep their
	# category colors as content.
	var summary_panel := get_node_or_null(PANEL) as PanelContainer
	if summary_panel != null:
		summary_panel.add_theme_stylebox_override("panel", DungeonUiTheme.framed_panel_style(10.0, 8.0))
	# Reward panel was a flat green fill (read as plain next to the textured frame); give
	# it the card-frame texture with a warm tint so it gains wood-grain + gold trim detail
	# and ties to the gold crystal / +120.
	var reward_panel := get_node_or_null(CONTENT + "/RewardPanel") as PanelContainer
	if reward_panel != null:
		reward_panel.add_theme_stylebox_override(
			"panel", DungeonUiTheme.card_style(12.0, 10.0, Color(1.05, 0.98, 0.8))
		)
	# Record rows are short bars, so instead of the ornate card frame (whose corners
	# would swallow the ~54px height) they get a filled category tint sharing the set's
	# gold trim — green/blue/purple stays legible while reading as the same family.
	const FILL_GREEN := Color(0.18, 0.27, 0.15)
	const FILL_BLUE := Color(0.13, 0.25, 0.41)
	const FILL_PURPLE := Color(0.26, 0.15, 0.37)
	_style_record_panel(RECORDS + "/StudentsRecordPanel", FILL_GREEN)
	_style_record_panel(RECORDS + "/FriendsRecordPanel", FILL_BLUE)
	_style_record_panel(RECORDS + "/RoomsRecordPanel", FILL_PURPLE)
	_style_record_panel(RECORDS + "/UnlocksRecordPanel", FILL_GREEN)


func _style_panel(path: String, bg: Color, border: Color, width: int, corner: int) -> void:
	var panel := get_node_or_null(path) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", DungeonUiTheme.panel_style(bg, border, width, 0.0, 0.0, corner))


## Short record bars: filled category tint with the set's gold trim, on a small corner
## radius so they read as the same family as the textured popups without the ornate
## card frame collapsing at this height.
func _style_record_panel(path: String, fill: Color) -> void:
	var panel := get_node_or_null(path) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override(
			"panel",
			DungeonUiTheme.panel_style(fill, DungeonUiTheme.COLOR_GOLD_DIM, 2, 0.0, 0.0, 4)
		)


func _apply_font_roles() -> void:
	FontRoles.apply_pixel(map_tab_button)
	FontRoles.apply_pixel(status_label)
	FontRoles.apply_pixel(interaction_label)
	FontRoles.apply_title(result_title_label)
	FontRoles.apply_body(narrative_label)
	FontRoles.apply_body(memory_label)
	FontRoles.apply_pixel(memory_amount_label)
	FontRoles.apply_pixel(students_record_label)
	FontRoles.apply_pixel(friends_record_label)
	FontRoles.apply_pixel(rooms_record_label)
	FontRoles.apply_pixel(unlocks_record_label)
	FontRoles.apply_pixel(return_button)
	FontRoles.apply_pixel(retry_button)


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
	memory_label.text = "혼 조각"
	memory_amount_label.text = "+%d" % int(summary["memory_reward"])
	# Record bars split the label (static title) from the count (large, colored) so the
	# number reads as the achievement — set just the number here.
	students_record_label.text = "%d" % int(summary["students_rescued"])
	friends_record_label.text = "정화 %d" % int(summary["friends_purified"])
	rooms_record_label.text = "%d" % int(summary["rooms_cleared"])
	# Results screen intentionally shows only 혼 조각 / 구출 / 방; 정화·해금 are hidden
	# (FriendsRecordPanel is hidden in the scene; keep the unlock row hidden here too).
	unlocks_record_panel.visible = false
	var unlock_labels: Array[String] = summary["unlocks"]
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
	var effects: Array[String] = []
	var button_texts: Array[String] = []
	var title_font_sizes: Array[int] = []
	var effect_font_sizes: Array[int] = []
	var title_outline_sizes: Array[int] = []
	var effect_outline_sizes: Array[int] = []
	for choice: Dictionary in _reward_choice_models:
		texts.append(String(choice.get("display_name", "")))
		effects.append(String(choice.get("effect", "")))
	if _reward_choice_row != null:
		for child: Node in _reward_choice_row.get_children():
			if child is Button:
				var card := child as Button
				button_texts.append(_reward_choice_card_snapshot_text(card))
				title_font_sizes.append(_reward_choice_label_font_size(card, "RewardTitleLabel"))
				effect_font_sizes.append(_reward_choice_label_font_size(card, "RewardEffectLabel"))
				title_outline_sizes.append(_reward_choice_label_outline_size(card, "RewardTitleLabel"))
				effect_outline_sizes.append(_reward_choice_label_outline_size(card, "RewardEffectLabel"))
	return {
		"visible": is_reward_choice_visible(),
		"room_id": _reward_choice_room_id,
		"choice_ids": get_reward_choice_ids(),
		"choice_texts": texts,
		"choice_effects": effects,
		"choice_button_texts": button_texts,
		"choice_title_font_sizes": title_font_sizes,
		"choice_effect_font_sizes": effect_font_sizes,
		"choice_title_outline_sizes": title_outline_sizes,
		"choice_effect_outline_sizes": effect_outline_sizes,
		"visible_card_count": _reward_choice_cards.size(),
		"has_backdrop": _reward_choice_dim != null and is_instance_valid(_reward_choice_dim),
		"dim_alpha": _reward_choice_dim.color.a if _reward_choice_dim != null and is_instance_valid(_reward_choice_dim) else 0.0,
		"has_outer_panel": false,
		"has_title": _reward_choice_title_label != null and is_instance_valid(_reward_choice_title_label) and _reward_choice_title_label.text != "",
		"title": _reward_choice_title_label.text if _reward_choice_title_label != null and is_instance_valid(_reward_choice_title_label) else "",
	}


func get_reward_choice_animation_snapshot() -> Dictionary:
	_ensure_reward_choice_overlay()
	var card_alphas: Array = []
	var card_scales: Array = []
	for card: Button in _reward_choice_cards:
		card_alphas.append(card.modulate.a)
		card_scales.append(card.scale)
	return {
		"visible": is_reward_choice_visible(),
		"overlay_process_mode": _reward_choice_overlay.process_mode,
		"has_backdrop": _reward_choice_dim != null and is_instance_valid(_reward_choice_dim),
		"dim_alpha": _reward_choice_dim.color.a if _reward_choice_dim != null and is_instance_valid(_reward_choice_dim) else 0.0,
		"has_outer_panel": false,
		"title": _reward_choice_title_label.text if _reward_choice_title_label != null and is_instance_valid(_reward_choice_title_label) else "",
		"card_alphas": card_alphas,
		"card_scales": card_scales,
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

	_reward_choice_dim = ColorRect.new()
	_reward_choice_dim.name = "RewardChoiceDim"
	_reward_choice_dim.color = Color(0.0, 0.0, 0.0, REWARD_CHOICE_DIM_ALPHA)
	_reward_choice_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_choice_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reward_choice_overlay.add_child(_reward_choice_dim)

	_reward_choice_title_label = Label.new()
	_reward_choice_title_label.name = "RewardChoiceTitle"
	_reward_choice_title_label.text = REWARD_CHOICE_TITLE_TEXT
	_reward_choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_choice_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reward_choice_title_label.add_theme_font_size_override("font_size", 30)
	FontRoles.apply_title(_reward_choice_title_label)
	_reward_choice_title_label.add_theme_color_override("font_color", Color(0.937255, 0.811765, 0.298039, 1.0))
	_reward_choice_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_reward_choice_title_label.add_theme_constant_override("outline_size", 4)
	_reward_choice_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_choice_title_label.anchor_left = 0.5
	_reward_choice_title_label.anchor_top = 0.5
	_reward_choice_title_label.anchor_right = 0.5
	_reward_choice_title_label.anchor_bottom = 0.5
	_reward_choice_title_label.offset_left = -260.0
	_reward_choice_title_label.offset_top = REWARD_CHOICE_TITLE_OFFSET_TOP
	_reward_choice_title_label.offset_right = 260.0
	_reward_choice_title_label.offset_bottom = REWARD_CHOICE_TITLE_OFFSET_BOTTOM
	_reward_choice_overlay.add_child(_reward_choice_title_label)

	_reward_choice_row = HBoxContainer.new()
	_reward_choice_row.name = "RewardChoiceRow"
	_reward_choice_row.add_theme_constant_override("separation", 12)
	_reward_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_choice_row.anchor_left = 0.5
	_reward_choice_row.anchor_top = 0.5
	_reward_choice_row.anchor_right = 0.5
	_reward_choice_row.anchor_bottom = 0.5
	_reward_choice_row.offset_left = REWARD_CHOICE_ROW_OFFSET_LEFT
	_reward_choice_row.offset_top = REWARD_CHOICE_ROW_OFFSET_TOP
	_reward_choice_row.offset_right = REWARD_CHOICE_ROW_OFFSET_RIGHT
	_reward_choice_row.offset_bottom = REWARD_CHOICE_ROW_OFFSET_BOTTOM
	_reward_choice_overlay.add_child(_reward_choice_row)

	_reset_reward_choice_animation_to_rest()


func _show_reward_choice_overlay_animated() -> void:
	_kill_reward_choice_open_tween()
	_reward_choice_overlay.visible = true
	for card: Button in _reward_choice_cards:
		card.modulate.a = 0.0
		card.scale = REWARD_CHOICE_CARD_START_SCALE

	_reward_choice_open_tween = create_tween()
	_reward_choice_open_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reward_choice_open_tween.set_parallel(true)
	for index: int in range(_reward_choice_cards.size()):
		var card := _reward_choice_cards[index]
		var delay := float(index) * REWARD_CHOICE_CARD_STAGGER
		_reward_choice_open_tween.tween_property(card, "modulate:a", 1.0, REWARD_CHOICE_OPEN_DURATION).set_delay(delay)
		_reward_choice_open_tween.tween_property(card, "scale", Vector2.ONE, REWARD_CHOICE_OPEN_DURATION).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_reward_choice_open_tween() -> void:
	if _reward_choice_open_tween != null:
		_reward_choice_open_tween.kill()
		_reward_choice_open_tween = null


func _reset_reward_choice_animation_to_rest() -> void:
	if _reward_choice_row != null:
		_reward_choice_row.offset_left = REWARD_CHOICE_ROW_OFFSET_LEFT
		_reward_choice_row.offset_top = REWARD_CHOICE_ROW_OFFSET_TOP
		_reward_choice_row.offset_right = REWARD_CHOICE_ROW_OFFSET_RIGHT
		_reward_choice_row.offset_bottom = REWARD_CHOICE_ROW_OFFSET_BOTTOM
	for card: Button in _reward_choice_cards:
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
	if _reward_choice_dim != null:
		_reward_choice_dim.color.a = REWARD_CHOICE_DIM_ALPHA
	if _reward_choice_title_label != null:
		_reward_choice_title_label.text = REWARD_CHOICE_TITLE_TEXT
		_reward_choice_title_label.modulate.a = 1.0


func _render_reward_choices() -> void:
	_ensure_reward_choice_overlay()
	_reward_choice_cards.clear()
	for child: Node in _reward_choice_row.get_children():
		_reward_choice_row.remove_child(child)
		child.queue_free()
	for choice: Dictionary in _reward_choice_models:
		var item_id := StringName(choice.get("item_id", &""))
		var display_name := String(choice.get("display_name", String(item_id)))
		var effect := String(choice.get("effect", ""))
		var button := Button.new()
		button.name = "RewardChoice%sButton" % _node_suffix_for_reward_id(item_id)
		button.text = ""
		button.custom_minimum_size = REWARD_CHOICE_CARD_SIZE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("test_id", "session.reward_choice.%s" % String(item_id))
		button.set_meta("uat_action", "session.reward_choice.%s" % String(item_id))
		button.pressed.connect(_on_reward_choice_pressed.bind(item_id))
		PixelButtonStyle.apply(button, PixelButtonStyle.VARIANT_PRIMARY, REWARD_CHOICE_CARD_SIZE)
		FontRoles.apply_pixel(button)
		button.pivot_offset = REWARD_CHOICE_CARD_SIZE * 0.5
		_add_reward_choice_card_content(button, display_name, effect)
		_reward_choice_row.add_child(button)
		_reward_choice_cards.append(button)


func _add_reward_choice_card_content(button: Button, display_name: String, effect: String) -> void:
	var margin := MarginContainer.new()
	margin.name = "RewardCardMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(margin)

	var stack := VBoxContainer.new()
	stack.name = "RewardCardTextStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)

	var title := Label.new()
	title.name = "RewardTitleLabel"
	title.text = display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", REWARD_CHOICE_CARD_TITLE_FONT_SIZE)
	FontRoles.apply_title(title)
	title.add_theme_color_override("font_color", REWARD_CHOICE_CARD_TITLE_COLOR)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	title.add_theme_constant_override("outline_size", REWARD_CHOICE_CARD_TITLE_OUTLINE)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(title)

	var effect_label := Label.new()
	effect_label.name = "RewardEffectLabel"
	effect_label.text = "효과: %s" % effect if effect != "" else ""
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_font_size_override("font_size", REWARD_CHOICE_CARD_EFFECT_FONT_SIZE)
	FontRoles.apply_pixel(effect_label)
	effect_label.add_theme_color_override("font_color", REWARD_CHOICE_CARD_EFFECT_COLOR)
	effect_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	effect_label.add_theme_constant_override("outline_size", REWARD_CHOICE_CARD_EFFECT_OUTLINE)
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(effect_label)


func _reward_choice_card_snapshot_text(card: Button) -> String:
	var title := _reward_choice_card_label(card, "RewardTitleLabel")
	var effect := _reward_choice_card_label(card, "RewardEffectLabel")
	var parts: Array[String] = []
	if title != null:
		parts.append(title.text)
	if effect != null and effect.text != "":
		parts.append(effect.text)
	return "\n".join(parts)


func _reward_choice_label_font_size(card: Button, label_name: String) -> int:
	var label := _reward_choice_card_label(card, label_name)
	return label.get_theme_font_size("font_size") if label != null else 0


func _reward_choice_label_outline_size(card: Button, label_name: String) -> int:
	var label := _reward_choice_card_label(card, label_name)
	return label.get_theme_constant("outline_size") if label != null else 0


func _reward_choice_card_label(card: Button, label_name: String) -> Label:
	return card.find_child(label_name, true, false) as Label


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
	if String(result.get("reason", "")) == "onboarding_friend_purified":
		return "정화 완료"
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
	var reason := String(result.get("reason", ""))
	if outcome in ["death", "dead", "failed"] or bool(result.get("died", false)):
		return "새벽 종소리와 함께 교실에서 눈을 떴다. 혼 조각은 손에 남아 있다."
	if reason == "onboarding_friend_purified":
		return "야구부 주장이 제정신을 되찾았다. 학교로 돌아가 배트와 단서를 받자."
	if reason == "boss_resolved":
		return "도깨비왕은 쓰러졌지만 친구는 돌아오지 않았다. 범인은 아직 따로 있다."
	if bool(result.get("completed", false)) or outcome in ["success", "escaped", "complete", "completed"]:
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
