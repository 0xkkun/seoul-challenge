class_name ConfirmModal
extends CanvasLayer

const TEST_ID_YES := "confirm_modal.yes_button"
const TEST_ID_NO := "confirm_modal.no_button"
const ACTION_YES := "confirm_modal.yes"
const ACTION_NO := "confirm_modal.no"

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
	var yes_variant := PixelButtonStyle.VARIANT_DANGER if danger else PixelButtonStyle.VARIANT_PRIMARY
	PixelButtonStyle.apply(_yes_button, yes_variant, Vector2(132.0, 50.0))
	PixelButtonStyle.apply(_no_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(132.0, 50.0))


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
