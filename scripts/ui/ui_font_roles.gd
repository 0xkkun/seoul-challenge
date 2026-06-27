class_name UiFontRoles
extends RefCounted

const ROLE_PIXEL := &"pixel"
const ROLE_TITLE := &"title"
const ROLE_BODY := &"body"

const PIXEL_FONT_PATH := "res://assets/fonts/NeoDunggeunmoPro-Regular.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/ChosunCentennial.ttf"
const BODY_FONT_PATH := "res://assets/fonts/RIDIBatang.otf"

const PIXEL_FONT: FontFile = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const TITLE_FONT: FontFile = preload("res://assets/fonts/ChosunCentennial.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/RIDIBatang.otf")
const EMPHASIS_EMBOLDEN := 0.7
const EMPHASIS_SKEW := -0.16


static func apply_pixel(control: Control) -> void:
	_apply_font(control, PIXEL_FONT)


static func apply_title(control: Control) -> void:
	_apply_font(control, TITLE_FONT)


static func apply_body(control: Control) -> void:
	_apply_font(control, BODY_FONT)


static func role_font_path(role: StringName) -> String:
	match role:
		ROLE_TITLE:
			return TITLE_FONT_PATH
		ROLE_BODY:
			return BODY_FONT_PATH
		_:
			return PIXEL_FONT_PATH


static func _apply_font(control: Control, font: FontFile) -> void:
	if control == null:
		return
	if control is RichTextLabel:
		control.add_theme_font_override("normal_font", font)
		control.add_theme_font_override("bold_font", _make_font_variation(font, EMPHASIS_EMBOLDEN, 0.0))
		control.add_theme_font_override("italics_font", _make_font_variation(font, 0.0, EMPHASIS_SKEW))
		control.add_theme_font_override("bold_italics_font", _make_font_variation(font, EMPHASIS_EMBOLDEN, EMPHASIS_SKEW))
		control.add_theme_font_override("mono_font", PIXEL_FONT)
		return
	control.add_theme_font_override("font", font)


static func _make_font_variation(base_font: FontFile, embolden: float, skew: float) -> FontVariation:
	var variation := FontVariation.new()
	variation.base_font = base_font
	variation.variation_embolden = embolden
	if not is_zero_approx(skew):
		variation.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(skew, 1.0), Vector2.ZERO)
	return variation
