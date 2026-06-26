class_name PixelButtonStyle
extends RefCounted

const VARIANT_PRIMARY := &"primary"
const VARIANT_SECONDARY := &"secondary"
const VARIANT_DANGER := &"danger"

const NORMAL_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_normal.png")
const PRESSED_TEXTURE := preload("res://assets/ui/buttons/lobby/lobby_button_pressed.png")

const NORMAL_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_normal.png"
const PRESSED_TEXTURE_PATH := "res://assets/ui/buttons/lobby/lobby_button_pressed.png"


static func apply(button: Button, variant: StringName = VARIANT_PRIMARY, minimum_size: Vector2 = Vector2.ZERO) -> void:
	if button == null:
		return
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = Vector2(
			maxf(button.custom_minimum_size.x, minimum_size.x),
			maxf(button.custom_minimum_size.y, minimum_size.y)
		)
	button.add_theme_stylebox_override("normal", _style(NORMAL_TEXTURE, _normal_modulate(variant)))
	button.add_theme_stylebox_override("hover", _style(NORMAL_TEXTURE, _hover_modulate(variant)))
	button.add_theme_stylebox_override("pressed", _style(PRESSED_TEXTURE, _pressed_modulate(variant)))
	button.add_theme_stylebox_override("focus", _style(NORMAL_TEXTURE, _hover_modulate(variant)))
	button.add_theme_color_override("font_color", _font_color(variant))
	button.add_theme_color_override("font_hover_color", _font_hover_color(variant))
	button.add_theme_color_override("font_focus_color", _font_hover_color(variant))
	button.add_theme_color_override("font_pressed_color", _font_pressed_color(variant))


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


static func _normal_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(1.0, 0.62, 0.62, 1.0)
		VARIANT_SECONDARY:
			return Color(0.78, 0.82, 0.88, 1.0)
		_:
			return Color.WHITE


static func _hover_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(1.0, 0.74, 0.74, 1.0)
		VARIANT_SECONDARY:
			return Color(0.9, 0.93, 0.98, 1.0)
		_:
			return Color(1.0, 0.956863, 0.776471, 1.0)


static func _pressed_modulate(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(0.9, 0.44, 0.44, 1.0)
		VARIANT_SECONDARY:
			return Color(0.66, 0.7, 0.78, 1.0)
		_:
			return Color.WHITE


static func _font_color(variant: StringName) -> Color:
	match variant:
		VARIANT_DANGER:
			return Color(1.0, 0.9, 0.9, 1.0)
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
			return Color(1.0, 0.8, 0.8, 1.0)
		VARIANT_SECONDARY:
			return Color(0.78, 0.82, 0.9, 1.0)
		_:
			return Color(0.831373, 0.705882, 0.388235, 1.0)
