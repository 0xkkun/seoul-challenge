class_name SettingsUI
extends PopupBase

const TEST_ID_BGM_TOGGLE := "settings.bgm_toggle"
const TEST_ID_SFX_TOGGLE := "settings.sfx_toggle"
const TEST_ID_HAPTIC_TOGGLE := "settings.haptic_toggle"
const TEST_ID_CLOSE := "settings.close_button"
const ACTION_BGM_TOGGLE := "settings.bgm.toggle"
const ACTION_SFX_TOGGLE := "settings.sfx.toggle"
const ACTION_HAPTIC_TOGGLE := "settings.haptic.toggle"
const ACTION_CLOSE := "settings.close"

const _OPEN_DURATION := 0.14
const _CLOSE_DURATION := 0.1
const _TOGGLE_DURATION := 0.08
const _TOGGLE_MIN_SIZE := Vector2(104.0, 46.0)
const _ICON_SIZE := Vector2(32.0, 32.0)

const _SOUND_ON_ICON := preload("res://assets/ui/icons/settings/sound.png")
const _SOUND_OFF_ICON := preload("res://assets/ui/icons/settings/sound_off.png")
const _HAPTIC_ON_ICON := preload("res://assets/ui/icons/settings/haptic.png")
const _HAPTIC_OFF_ICON := preload("res://assets/ui/icons/settings/haptic_off.png")
const FontRoles := preload("res://scripts/ui/ui_font_roles.gd")

@onready var _root: Control = $Root
@onready var _panel: PanelContainer = $Root/Panel
@onready var _title_label: Label = $Root/Panel/Margin/Stack/TitleLabel
@onready var _rows: VBoxContainer = %Rows
@onready var _close_button: Button = %CloseButton

var _toggle_buttons: Dictionary = {}
var _open_tween: Tween
var _close_tween: Tween
var _closing := false

signal closed


func _ready() -> void:
	_setup_popup($Root/Backdrop, $Root/Panel)
	_close_button.set_meta("test_id", TEST_ID_CLOSE)
	_close_button.set_meta("uat_action", ACTION_CLOSE)
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.focus_mode = Control.FOCUS_NONE
	PixelButtonStyle.apply(_close_button, PixelButtonStyle.VARIANT_SECONDARY, Vector2(136.0, 50.0))
	FontRoles.apply_title(_title_label)
	FontRoles.apply_pixel(_close_button)
	_build_rows()
	_refresh_all()


func _exit_tree() -> void:
	if _open_tween != null:
		_open_tween.kill()
	if _close_tween != null:
		_close_tween.kill()


func open() -> void:
	if _close_tween != null:
		_close_tween.kill()
	if _open_tween != null:
		_open_tween.kill()
	_closing = false
	_refresh_all()
	visible = true
	_root.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.size * 0.5
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(_root, "modulate:a", 1.0, _OPEN_DURATION)
	(
		_open_tween
		. tween_property(_panel, "scale", Vector2.ONE, _OPEN_DURATION)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


func close(immediate: bool = false) -> void:
	if not visible:
		return
	if _closing:
		return
	if immediate or not is_inside_tree():
		_finish_close()
		return
	_closing = true
	if _open_tween != null:
		_open_tween.kill()
	if _close_tween != null:
		_close_tween.kill()
	_close_tween = create_tween()
	_close_tween.set_parallel(true)
	_close_tween.tween_property(_root, "modulate:a", 0.0, _CLOSE_DURATION)
	(
		_close_tween
		. tween_property(_panel, "scale", Vector2(0.96, 0.96), _CLOSE_DURATION)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	_close_tween.chain().tween_callback(_finish_close)


func is_open() -> bool:
	return visible


func is_closing() -> bool:
	return _closing


func get_toggle_text(key: String) -> String:
	var state := _toggle_buttons.get(key, {}) as Dictionary
	var button := state.get("button") as Button
	if button == null:
		return ""
	return button.text


func _on_popup_cancel() -> void:
	close()


func _build_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_toggle_buttons.clear()
	for row: Dictionary in _toggle_rows():
		_rows.add_child(_make_toggle_row(row))


func _make_toggle_row(row: Dictionary) -> Control:
	var container := PanelContainer.new()
	container.name = "%sRow" % _node_suffix_for_key(String(row["key"]))
	container.custom_minimum_size = Vector2(0.0, 58.0)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.047, 0.067, 0.098, 0.92)
	row_style.border_color = Color(0.27, 0.56, 0.64, 0.75)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 1
	row_style.corner_radius_top_left = 6
	row_style.corner_radius_top_right = 6
	row_style.corner_radius_bottom_right = 6
	row_style.corner_radius_bottom_left = 6
	container.add_theme_stylebox_override("panel", row_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	container.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = _ICON_SIZE
	icon.size = _ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)

	var label := Label.new()
	label.text = String(row["label"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	FontRoles.apply_pixel(label)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.97, 1.0))
	hbox.add_child(label)

	var button := Button.new()
	button.name = "%sToggleButton" % _node_suffix_for_key(String(row["key"]))
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("test_id", String(row["test_id"]))
	button.set_meta("uat_action", String(row["action"]))
	button.pressed.connect(_on_toggle_pressed.bind(String(row["key"])))
	hbox.add_child(button)
	_toggle_buttons[String(row["key"])] = {
		"button": button,
		"icon": icon,
		"icon_on": row["icon_on"],
		"icon_off": row["icon_off"],
	}
	_sync_toggle_button(String(row["key"]))
	return container


func _on_toggle_pressed(key: String) -> void:
	var next_value := not bool(Settings.get_value(key, true))
	match key:
		Settings.KEY_BGM_ENABLED:
			Settings.set_bgm_enabled(next_value)
		Settings.KEY_SFX_ENABLED:
			Settings.set_sfx_enabled(next_value)
		Settings.KEY_HAPTIC_ENABLED:
			Settings.set_haptic_enabled(next_value)
		_:
			Settings.set_value(key, next_value)
	_sync_toggle_button(key)
	var state := _toggle_buttons.get(key, {}) as Dictionary
	_animate_toggle_button(state.get("button") as Button)
	Settings.try_vibrate(24)


func _sync_toggle_button(key: String) -> void:
	var state := _toggle_buttons.get(key, {}) as Dictionary
	var button := state.get("button") as Button
	if button == null:
		return
	var enabled := bool(Settings.get_value(key, true))
	button.text = "ON" if enabled else "OFF"
	var variant := PixelButtonStyle.VARIANT_PRIMARY if enabled else PixelButtonStyle.VARIANT_SECONDARY
	PixelButtonStyle.apply(button, variant, _TOGGLE_MIN_SIZE)
	FontRoles.apply_pixel(button)
	var icon := state.get("icon") as TextureRect
	if icon != null:
		var icon_texture: Texture2D = (state.get("icon_on") if enabled else state.get("icon_off")) as Texture2D
		icon.texture = icon_texture


func _refresh_all() -> void:
	for row: Dictionary in _toggle_rows():
		_sync_toggle_button(String(row["key"]))


func _toggle_rows() -> Array[Dictionary]:
	return [
		{
			"key": Settings.KEY_BGM_ENABLED,
			"label": "배경음",
			"test_id": TEST_ID_BGM_TOGGLE,
			"action": ACTION_BGM_TOGGLE,
			"icon_on": _SOUND_ON_ICON,
			"icon_off": _SOUND_OFF_ICON,
		},
		{
			"key": Settings.KEY_SFX_ENABLED,
			"label": "효과음",
			"test_id": TEST_ID_SFX_TOGGLE,
			"action": ACTION_SFX_TOGGLE,
			"icon_on": _SOUND_ON_ICON,
			"icon_off": _SOUND_OFF_ICON,
		},
		{
			"key": Settings.KEY_HAPTIC_ENABLED,
			"label": "진동",
			"test_id": TEST_ID_HAPTIC_TOGGLE,
			"action": ACTION_HAPTIC_TOGGLE,
			"icon_on": _HAPTIC_ON_ICON,
			"icon_off": _HAPTIC_OFF_ICON,
		},
	]


func _node_suffix_for_key(key: String) -> String:
	var suffix := ""
	for part in key.split("_", false):
		suffix += part.capitalize()
	return suffix


func _animate_toggle_button(button: Button) -> void:
	if button == null or not button.is_inside_tree():
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(0.92, 0.92), _TOGGLE_DURATION)
	tween.tween_property(button, "scale", Vector2.ONE, _TOGGLE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_close_pressed() -> void:
	Settings.try_vibrate(18)
	close()


func get_toggle_icon_path(key: String) -> String:
	var state := _toggle_buttons.get(key, {}) as Dictionary
	var icon := state.get("icon") as TextureRect
	if icon == null or icon.texture == null:
		return ""
	return icon.texture.resource_path


func _finish_close() -> void:
	visible = false
	_closing = false
	_root.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	closed.emit()
