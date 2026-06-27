class_name PixelButtonStyle
extends RefCounted

const VARIANT_PRIMARY := &"primary"
const VARIANT_SECONDARY := &"secondary"
const VARIANT_DANGER := &"danger"

const NORMAL_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_normal.png")
const PRESSED_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_pressed.png")
const DANGER_NORMAL_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_danger.png")
const DANGER_PRESSED_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_danger_pressed.png")

const NORMAL_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_normal.png"
const PRESSED_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_pressed.png"
const DANGER_NORMAL_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_danger.png"
const DANGER_PRESSED_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_danger_pressed.png"


static func apply(button: Button, variant: StringName = VARIANT_PRIMARY, minimum_size: Vector2 = Vector2.ZERO, with_sfx: bool = true) -> void:
	if button == null:
		return
	if with_sfx:
		attach_press_sfx(button)
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = Vector2(
			maxf(button.custom_minimum_size.x, minimum_size.x),
			maxf(button.custom_minimum_size.y, minimum_size.y)
		)
	button.add_theme_stylebox_override("normal", _style(_normal_texture(variant), _normal_modulate(variant)))
	button.add_theme_stylebox_override("hover", _style(_normal_texture(variant), _hover_modulate(variant)))
	button.add_theme_stylebox_override("pressed", _style(_pressed_texture(variant), _pressed_modulate(variant)))
	button.add_theme_stylebox_override("focus", _style(_normal_texture(variant), _hover_modulate(variant)))
	button.add_theme_stylebox_override("disabled", _style(_normal_texture(variant), _disabled_modulate(variant)))
	button.add_theme_color_override("font_color", _font_color(variant))
	button.add_theme_color_override("font_hover_color", _font_hover_color(variant))
	button.add_theme_color_override("font_focus_color", _font_hover_color(variant))
	button.add_theme_color_override("font_pressed_color", _font_pressed_color(variant))
	button.add_theme_color_override("font_disabled_color", _font_disabled_color(variant))


## Connects the shared UI button-press SFX to a button's `pressed` signal.
## Safe to call multiple times — the connection is deduplicated.
static func attach_press_sfx(button: Button) -> void:
	if button == null:
		return
	var press_cb := Callable(PixelButtonStyle, "_play_press_sfx")
	if not button.pressed.is_connected(press_cb):
		button.pressed.connect(press_cb)


static func _play_press_sfx() -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var audio := loop.root.get_node_or_null(^"AudioManager")
	if audio != null and audio.has_method(&"play_sfx"):
		audio.play_sfx(AudioManager.UI_BUTTON_PRESS)


static func normal_texture_path(variant: StringName) -> String:
	if variant == VARIANT_DANGER:
		return DANGER_NORMAL_TEXTURE_PATH
	return NORMAL_TEXTURE_PATH


static func pressed_texture_path(variant: StringName) -> String:
	if variant == VARIANT_DANGER:
		return DANGER_PRESSED_TEXTURE_PATH
	return PRESSED_TEXTURE_PATH


static func _style(texture: Texture2D, modulate: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 60.0
	style.texture_margin_top = 12.0
	style.texture_margin_right = 60.0
	style.texture_margin_bottom = 12.0
	style.content_margin_left = 28.0
	style.content_margin_top = 9.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 9.0
	style.modulate_color = modulate
	return style


static func _normal_texture(variant: StringName) -> Texture2D:
	if variant == VARIANT_DANGER:
		return DANGER_NORMAL_TEXTURE
	return NORMAL_TEXTURE


static func _pressed_texture(variant: StringName) -> Texture2D:
	if variant == VARIANT_DANGER:
		return DANGER_PRESSED_TEXTURE
	return PRESSED_TEXTURE


static func _normal_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color.WHITE
		VARIANT_SECONDARY:
			return Color(0.78, 0.82, 0.88, 1.0)
		_:
			return Color.WHITE


static func _hover_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(1.0, 0.92, 0.88, 1.0)
		VARIANT_SECONDARY:
			return Color(0.9, 0.93, 0.98, 1.0)
		_:
			return Color(1.0, 0.956863, 0.776471, 1.0)


static func _pressed_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color.WHITE
		VARIANT_SECONDARY:
			return Color(0.66, 0.7, 0.78, 1.0)
		_:
			return Color.WHITE


static func _disabled_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(0.55, 0.45, 0.43, 0.86)
		VARIANT_SECONDARY:
			return Color(0.43, 0.48, 0.56, 0.82)
		_:
			return Color(0.58, 0.55, 0.45, 0.86)


static func _font_color(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color.WHITE
		VARIANT_SECONDARY:
			return Color(0.9, 0.93, 0.98, 1.0)
		_:
			return Color(0.984314, 0.956863, 0.839216, 1.0)


static func _font_hover_color(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color.WHITE
		VARIANT_SECONDARY:
			return Color.WHITE
		_:
			return Color(1.0, 0.984314, 0.878431, 1.0)


static func _font_pressed_color(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(1.0, 0.92, 0.88, 1.0)
		VARIANT_SECONDARY:
			return Color(0.78, 0.82, 0.9, 1.0)
		_:
			return Color(0.831373, 0.705882, 0.388235, 1.0)


static func _font_disabled_color(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(0.82, 0.7, 0.68, 1.0)
		VARIANT_SECONDARY:
			return Color(0.68, 0.72, 0.78, 1.0)
		_:
			return Color(0.72, 0.67, 0.52, 1.0)
