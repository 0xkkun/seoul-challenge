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
const RICH_TEXT_FONT_KEYS: Array[StringName] = [
	&"normal_font",
	&"bold_font",
	&"italics_font",
	&"bold_italics_font",
	&"mono_font",
]


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
		for font_key: StringName in RICH_TEXT_FONT_KEYS:
			control.add_theme_font_override(font_key, font)
		return
	control.add_theme_font_override("font", font)
