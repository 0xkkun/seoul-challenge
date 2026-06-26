class_name DungeonUiTheme
extends RefCounted

const VARIANT_PRIMARY := &"primary"
const VARIANT_SECONDARY := &"secondary"
const VARIANT_MUTED := &"muted"

const COLOR_BACKDROP := Color(0.025, 0.031, 0.041, 1.0)
const COLOR_PANEL := Color(0.038, 0.049, 0.066, 0.97)
const COLOR_PANEL_RAISED := Color(0.052, 0.066, 0.088, 0.98)
const COLOR_SLOT := Color(0.032, 0.042, 0.056, 0.98)
const COLOR_SLOT_SELECTED := Color(0.057, 0.052, 0.039, 1.0)
const COLOR_DISABLED := Color(0.029, 0.034, 0.043, 0.86)
const COLOR_STEEL := Color(0.31, 0.36, 0.43, 1.0)
const COLOR_STEEL_BRIGHT := Color(0.48, 0.56, 0.66, 1.0)
const COLOR_GOLD := Color(0.94, 0.73, 0.25, 1.0)
const COLOR_GOLD_DIM := Color(0.55, 0.43, 0.20, 1.0)
const COLOR_CYAN := Color(0.33, 0.87, 0.93, 1.0)
const COLOR_TEXT := Color(0.91, 0.93, 0.96, 1.0)
const COLOR_MUTED_TEXT := Color(0.62, 0.68, 0.73, 1.0)


static func panel_style(
	bg_color := COLOR_PANEL,
	border_color := COLOR_STEEL,
	border_width := 2,
	margin_x := 16.0,
	margin_y := 12.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	style.content_margin_left = margin_x
	style.content_margin_top = margin_y
	style.content_margin_right = margin_x
	style.content_margin_bottom = margin_y
	return style


static func slot_style(selected: bool, disabled := false) -> StyleBoxFlat:
	if disabled:
		return panel_style(COLOR_DISABLED, Color(0.16, 0.18, 0.22, 1.0), 2, 12.0, 10.0)
	if selected:
		return panel_style(COLOR_SLOT_SELECTED, COLOR_GOLD, 4, 12.0, 10.0)
	return panel_style(COLOR_SLOT, COLOR_STEEL, 2, 12.0, 10.0)


static func apply_button(button: Button, variant := VARIANT_SECONDARY, minimum_size := Vector2.ZERO) -> void:
	if button == null:
		return
	if minimum_size != Vector2.ZERO:
		button.custom_minimum_size = Vector2(
			maxf(button.custom_minimum_size.x, minimum_size.x),
			maxf(button.custom_minimum_size.y, minimum_size.y)
		)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_style(variant, &"normal"))
	button.add_theme_stylebox_override("hover", _button_style(variant, &"hover"))
	button.add_theme_stylebox_override("pressed", _button_style(variant, &"pressed"))
	button.add_theme_stylebox_override("disabled", _button_style(VARIANT_MUTED, &"normal"))
	button.add_theme_color_override("font_color", _button_font_color(variant))
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_pressed_color", _button_pressed_font_color(variant))
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED_TEXT)


static func _button_style(variant: StringName, state: StringName) -> StyleBoxFlat:
	var bg := COLOR_PANEL
	var border := COLOR_STEEL_BRIGHT
	var width := 2
	match variant:
		VARIANT_PRIMARY:
			bg = COLOR_PANEL_RAISED
			border = COLOR_GOLD
			width = 3
		VARIANT_MUTED:
			bg = COLOR_DISABLED
			border = Color(0.15, 0.17, 0.21, 1.0)
		_:
			bg = COLOR_PANEL
			border = COLOR_CYAN
	if state == &"hover":
		bg = bg.lightened(0.08)
		width += 1
	if state == &"pressed":
		bg = bg.darkened(0.08)
	return panel_style(bg, border, width, 18.0, 11.0)


static func _button_font_color(variant: StringName) -> Color:
	return Color(0.98, 0.91, 0.67, 1.0) if variant == VARIANT_PRIMARY else COLOR_TEXT


static func _button_pressed_font_color(variant: StringName) -> Color:
	return COLOR_GOLD if variant == VARIANT_PRIMARY else COLOR_MUTED_TEXT
