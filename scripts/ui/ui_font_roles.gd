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
	else:
		control.add_theme_font_override("font", font)
