class_name HubDialogueUi
extends CanvasLayer
## 낮 학교 허브 NPC 대화 UI.
## 가로모드 기준 하단 대화 바, 좌측 초상화, 우측하단 선택지, 중앙 해금 팝업을 제공한다.

signal choice_selected(choice_id: StringName)
signal unlock_hidden

const REFERENCE_SIZE := Vector2(844.0, 390.0)
const DIALOGUE_BAR_HEIGHT := 152.0
const UNLOCK_POPUP_SIZE := Vector2(338.0, 148.0)
const UNLOCK_POPUP_CENTER_OFFSET := Vector2(0.0, -58.0)
const CONTINUE_HINT_TOUCH := "▼ 탭하여 계속 ▼"
const CHOICE_ASK := &"ask"
const CHOICE_ACCEPT := &"accept"
const STAGE_STATE_COMPLETED := "completed"
const STAGE_STATE_CURRENT := "current"
const STAGE_STATE_LOCKED := "locked"
const DEFAULT_STAGE_LABELS: Array[String] = [
	"STAGE 1\n첫만남",
	"STAGE 2\n훈련후",
	"STAGE 3\n정화후",
]

const PANEL_COLOR := Color(0.055, 0.063, 0.086, 0.96)
const PANEL_BORDER_COLOR := Color(0.945, 0.91, 0.78)
const NAMEPLATE_COLOR := Color(0.94, 0.89, 0.75)
const NAMEPLATE_TEXT_COLOR := Color(0.075, 0.08, 0.1)
const MEMORY_TEXT_COLOR := Color(0.73, 0.79, 1.0)
const PORTRAIT_COLOR := Color(0.54, 0.24, 0.27)
const PORTRAIT_ACCENT_COLOR := Color(0.18, 0.24, 0.36)
const COMPLETED_STAGE_COLOR := Color(0.51, 0.69, 0.51)
const CURRENT_STAGE_COLOR := Color(0.83, 0.66, 0.27)
const LOCKED_STAGE_COLOR := Color(0.14, 0.17, 0.23)
const UNLOCK_COLOR := Color(0.94, 0.89, 0.75)
const UNLOCK_BORDER_COLOR := Color(0.84, 0.68, 0.28)
const DEFAULT_BALL_COLOR := Color(0.9, 0.88, 0.8)
const DEFAULT_BAT_COLOR := Color(0.54, 0.55, 0.6)

@onready var _dialogue_dimmer: ColorRect = %DialogueDimmer
@onready var _portrait_panel: ColorRect = %PortraitPanel
@onready var _portrait_accent: ColorRect = %PortraitAccent
@onready var _dialogue_bar: PanelContainer = %DialogueBar
@onready var _dialogue_top_rule: ColorRect = %DialogueTopRule
@onready var _name_label: Label = %NameLabel
@onready var _stage_row: HBoxContainer = %StageRow
@onready var _dialogue_label: Label = %DialogueLabel
@onready var _memory_label: Label = %MemoryLabel
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _unlock_overlay: Control = %UnlockOverlay
@onready var _unlock_popup: PanelContainer = %UnlockPopup
@onready var _unlock_title_label: Label = %UnlockTitleLabel
@onready var _unlock_subtitle_label: Label = %UnlockSubtitleLabel
@onready var _unlock_item_grid: GridContainer = %UnlockItemGrid

var _speaker_name := ""
var _dialogue_text := ""
var _memory_text := ""
var _stage_labels := DEFAULT_STAGE_LABELS.duplicate()
var _current_stage := 1
var _completed_stage := 0
var _stage_states: Array[String] = []
var _choice_models: Array[Dictionary] = []
var _unlock_items: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue_dimmer.set_meta("test_id", "hub_dialogue.overlay")
	_dialogue_bar.set_meta("test_id", "hub_dialogue.bar")
	_choice_row.set_meta("test_id", "hub_dialogue.choice_row")
	_apply_static_styles()
	set_dialogue("야구부 주장", "\"스윙은 겁먹으면 늦어. 밤의 궁에선 더 그렇겠지.\"", "기억: 손바닥의 희미한 배트 자국")
	set_stage(2)
	set_choices([
		{"id": CHOICE_ASK, "text": "물어본다", "emphasized": false},
		{"id": CHOICE_ACCEPT, "text": "받는다", "emphasized": true},
	])
	_unlock_overlay.visible = false


func get_reference_size() -> Vector2:
	return REFERENCE_SIZE


func get_dialogue_bar_reference_rect() -> Rect2:
	return Rect2(Vector2(0.0, REFERENCE_SIZE.y - DIALOGUE_BAR_HEIGHT), Vector2(REFERENCE_SIZE.x, DIALOGUE_BAR_HEIGHT))


func get_unlock_popup_reference_rect() -> Rect2:
	var center := REFERENCE_SIZE * 0.5 + UNLOCK_POPUP_CENTER_OFFSET
	return Rect2(center - UNLOCK_POPUP_SIZE * 0.5, UNLOCK_POPUP_SIZE)


func is_dialogue_overlay_visible() -> bool:
	return _dialogue_dimmer.visible and _dialogue_dimmer.color.a > 0.0


func is_dialogue_overlay_modal() -> bool:
	return _dialogue_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP


func set_dialogue(next_speaker_name: String, next_dialogue_text: String, next_memory_text := "", portrait_color := PORTRAIT_COLOR) -> void:
	_speaker_name = next_speaker_name
	_dialogue_text = next_dialogue_text
	_memory_text = next_memory_text
	_name_label.text = _speaker_name
	_dialogue_label.text = _dialogue_text
	_memory_label.text = _memory_text
	_portrait_panel.color = portrait_color
	_portrait_accent.color = PORTRAIT_ACCENT_COLOR


func get_speaker_name() -> String:
	return _speaker_name


func get_dialogue_text() -> String:
	return _dialogue_text


func get_memory_text() -> String:
	return _memory_text


func set_stage(current_stage: int, completed_stage := -1, next_stage_labels: Array[String] = []) -> void:
	if not next_stage_labels.is_empty():
		_stage_labels = next_stage_labels.duplicate()
	_current_stage = clampi(current_stage, 1, _stage_labels.size())
	_completed_stage = current_stage - 1 if completed_stage < 0 else clampi(completed_stage, 0, _stage_labels.size())
	_render_stages()


func get_current_stage() -> int:
	return _current_stage


func get_stage_state(stage_number: int) -> String:
	var index := stage_number - 1
	if index < 0 or index >= _stage_states.size():
		return ""
	return _stage_states[index]


func get_stage_labels() -> Array[String]:
	return _stage_labels.duplicate()


func set_stage_row_visible(should_show: bool) -> void:
	_stage_row.visible = should_show


func is_stage_row_visible() -> bool:
	return _stage_row.visible


func set_choices(next_choices: Array[Dictionary]) -> void:
	_choice_models.clear()
	for choice: Dictionary in next_choices:
		_choice_models.append(choice.duplicate(true))
	_render_choices()


func get_choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: Dictionary in _choice_models:
		ids.append(StringName(choice.get("id", &"")))
	return ids


func is_tap_to_continue_active() -> bool:
	return _tap_to_continue_choice_id() != &""


func get_choice_texts() -> Array[String]:
	var texts: Array[String] = []
	for choice: Dictionary in _choice_models:
		texts.append(String(choice.get("text", "")))
	return texts


func is_choice_emphasized(choice_id: StringName) -> bool:
	for choice: Dictionary in _choice_models:
		if StringName(choice.get("id", &"")) == choice_id:
			return bool(choice.get("emphasized", false))
	return false


func select_choice(choice_id: StringName) -> void:
	if not get_choice_ids().has(choice_id):
		return
	HapticManager.on_ui_confirm()
	choice_selected.emit(choice_id)


func show_unlock(title: String, subtitle: String, items: Array[Dictionary]) -> void:
	_unlock_title_label.text = title
	_unlock_subtitle_label.text = subtitle
	_unlock_items.clear()
	for item: Dictionary in items:
		_unlock_items.append(item.duplicate(true))
	_render_unlock_items()
	_unlock_overlay.visible = true


func hide_unlock() -> void:
	var was_visible := _unlock_overlay.visible
	_unlock_overlay.visible = false
	if was_visible:
		unlock_hidden.emit()


func is_unlock_visible() -> bool:
	return _unlock_overlay.visible


func get_unlock_items() -> Array[Dictionary]:
	return _unlock_items.duplicate(true)


func _input(event: InputEvent) -> void:
	if not visible or is_unlock_visible():
		return
	if not _is_advance_tap_event(event):
		return

	var choice_id := _tap_to_continue_choice_id()
	if choice_id == &"":
		return

	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	select_choice(choice_id)


func _render_stages() -> void:
	_clear_children(_stage_row)
	_stage_states.clear()
	for index in _stage_labels.size():
		var stage_number := index + 1
		var state := STAGE_STATE_LOCKED
		if stage_number <= _completed_stage:
			state = STAGE_STATE_COMPLETED
		if stage_number == _current_stage:
			state = STAGE_STATE_CURRENT
		_stage_states.append(state)

		var label := Label.new()
		label.text = _stage_labels[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size = Vector2(124.0, 34.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", _stage_text_color(state))
		label.add_theme_stylebox_override("normal", _make_panel_style(_stage_color(state), Color(0.35, 0.39, 0.48), 2))
		_stage_row.add_child(label)


func _render_choices() -> void:
	_clear_children(_choice_row)
	for choice: Dictionary in _choice_models:
		var choice_id := StringName(choice.get("id", &""))
		var test_id := String(choice.get("test_id", "hub_dialogue.choice.%s" % String(choice_id)))
		var action_name := String(choice.get("uat_action", "hub_dialogue.choice.%s" % String(choice_id)))
		var is_tap_continue := bool(choice.get("tap_to_continue", false))
		var button := Button.new()
		button.text = String(choice.get("text", ""))
		button.custom_minimum_size = Vector2(170.0, 28.0) if is_tap_continue else Vector2(112.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_tap_continue else Control.MOUSE_FILTER_STOP
		button.set_meta("test_id", test_id)
		button.set_meta("uat_action", action_name)
		button.set_meta("choice_id", choice_id)
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		if is_tap_continue:
			_apply_continue_hint_style(button)
		else:
			_apply_button_style(button, bool(choice.get("emphasized", false)))
		_choice_row.add_child(button)


func _render_unlock_items() -> void:
	_clear_children(_unlock_item_grid)
	for item: Dictionary in _unlock_items:
		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(140.0, 56.0)
		item_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.96, 0.83), Color(0.07, 0.08, 0.1), 2))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		item_panel.add_child(row)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(28.0, 28.0)
		icon.color = item.get("color", DEFAULT_BALL_COLOR)
		row.add_child(icon)

		var label := Label.new()
		label.text = String(item.get("name", ""))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		label.add_theme_font_size_override("font_size", 12)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		_unlock_item_grid.add_child(item_panel)


func _on_choice_pressed(choice_id: StringName) -> void:
	select_choice(choice_id)


func _tap_to_continue_choice_id() -> StringName:
	if _choice_models.size() != 1:
		return &""
	var choice := _choice_models[0]
	if not bool(choice.get("tap_to_continue", false)):
		return &""
	return StringName(choice.get("id", &""))


func _is_advance_tap_event(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	var touch := event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	return false


func _apply_static_styles() -> void:
	_dialogue_bar.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_COLOR, 0))
	_dialogue_top_rule.color = PANEL_BORDER_COLOR
	_name_label.add_theme_color_override("font_color", NAMEPLATE_TEXT_COLOR)
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_stylebox_override("normal", _make_panel_style(NAMEPLATE_COLOR, Color(0.07, 0.08, 0.1), 2))
	_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	_dialogue_label.add_theme_font_size_override("font_size", 18)
	_memory_label.add_theme_color_override("font_color", MEMORY_TEXT_COLOR)
	_memory_label.add_theme_font_size_override("font_size", 13)
	_choice_row.add_theme_constant_override("separation", 8)
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_stage_row.add_theme_constant_override("separation", 4)
	_unlock_popup.add_theme_stylebox_override("panel", _make_panel_style(UNLOCK_COLOR, UNLOCK_BORDER_COLOR, 4))
	_unlock_title_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	_unlock_title_label.add_theme_font_size_override("font_size", 17)
	_unlock_subtitle_label.add_theme_color_override("font_color", Color(0.42, 0.29, 0.1))
	_unlock_subtitle_label.add_theme_font_size_override("font_size", 11)


func _apply_button_style(button: Button, emphasized: bool) -> void:
	var fill := NAMEPLATE_COLOR if emphasized else Color(0.18, 0.23, 0.31)
	var text_color := NAMEPLATE_TEXT_COLOR if emphasized else Color(0.95, 0.94, 0.87)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _make_panel_style(fill, Color(0.45, 0.5, 0.59), 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill.lightened(0.08), Color(0.64, 0.69, 0.78), 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(fill.darkened(0.08), Color(0.07, 0.08, 0.1), 2))


func _apply_continue_hint_style(button: Button) -> void:
	button.flat = true
	button.add_theme_color_override("font_color", MEMORY_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", MEMORY_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", MEMORY_TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())


func _stage_color(state: String) -> Color:
	match state:
		STAGE_STATE_COMPLETED:
			return COMPLETED_STAGE_COLOR
		STAGE_STATE_CURRENT:
			return CURRENT_STAGE_COLOR
		_:
			return LOCKED_STAGE_COLOR


func _stage_text_color(state: String) -> Color:
	return NAMEPLATE_TEXT_COLOR if state != STAGE_STATE_LOCKED else Color(0.58, 0.64, 0.73)


func _make_panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
