class_name ConfirmModal
extends CanvasLayer

const TEST_ID_YES := "confirm_modal.yes_button"
const TEST_ID_NO := "confirm_modal.no_button"
const ACTION_YES := "confirm_modal.yes"
const ACTION_NO := "confirm_modal.no"

const YES_COLOR := Color("#67e8f9")
const YES_HOVER_COLOR := Color("#9bf2ff")
const DANGER_COLOR := Color("#ef4444")
const DANGER_HOVER_COLOR := Color("#f87171")
const NEUTRAL_COLOR := Color("#263241")
const NEUTRAL_HOVER_COLOR := Color("#334155")
const BUTTON_BORDER := Color("#d7e0e8")

@onready var _message_label: Label = %MessageLabel
@onready var _yes_button: Button = %YesButton
@onready var _no_button: Button = %NoButton

var _yes_callback := Callable()
var _no_callback := Callable()
var _danger := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_yes_button.set_meta("test_id", TEST_ID_YES)
	_yes_button.set_meta("uat_action", ACTION_YES)
	_no_button.set_meta("test_id", TEST_ID_NO)
	_no_button.set_meta("uat_action", ACTION_NO)
	_yes_button.pressed.connect(confirm_yes)
	_no_button.pressed.connect(confirm_no)
	_apply_button_styles(false)


func open(message: String, on_yes: Callable, on_no: Callable = Callable(), danger: bool = false) -> void:
	_message_label.text = message
	_yes_callback = on_yes
	_no_callback = on_no
	_danger = danger
	_apply_button_styles(_danger)
	visible = true
	_yes_button.grab_focus.call_deferred()


func confirm_yes() -> void:
	if not visible:
		return
	var callback := _yes_callback
	_close()
	if callback.is_valid():
		callback.call()


func confirm_no() -> void:
	if not visible:
		return
	var callback := _no_callback
	_close()
	if callback.is_valid():
		callback.call()


func is_open() -> bool:
	return visible


func is_danger_mode() -> bool:
	return _danger


func get_message_text() -> String:
	return _message_label.text


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or _is_escape_key(event):
		confirm_no()
		get_viewport().set_input_as_handled()


func _close() -> void:
	visible = false
	_yes_callback = Callable()
	_no_callback = Callable()


func _apply_button_styles(danger: bool) -> void:
	var yes_color := DANGER_COLOR if danger else YES_COLOR
	var yes_hover_color := DANGER_HOVER_COLOR if danger else YES_HOVER_COLOR
	_yes_button.add_theme_stylebox_override("normal", _button_style(yes_color))
	_yes_button.add_theme_stylebox_override("hover", _button_style(yes_hover_color))
	_yes_button.add_theme_stylebox_override("pressed", _button_style(yes_hover_color.darkened(0.12)))
	_yes_button.add_theme_color_override("font_color", Color("#071018"))
	_yes_button.add_theme_color_override("font_hover_color", Color("#071018"))
	_yes_button.add_theme_color_override("font_pressed_color", Color("#071018"))

	_no_button.add_theme_stylebox_override("normal", _button_style(NEUTRAL_COLOR))
	_no_button.add_theme_stylebox_override("hover", _button_style(NEUTRAL_HOVER_COLOR))
	_no_button.add_theme_stylebox_override("pressed", _button_style(NEUTRAL_HOVER_COLOR.darkened(0.12)))
	_no_button.add_theme_color_override("font_color", Color("#eef5f8"))
	_no_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	_no_button.add_theme_color_override("font_pressed_color", Color("#ffffff"))


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BUTTON_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 14.0
	style.content_margin_top = 8.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 8.0
	return style


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
