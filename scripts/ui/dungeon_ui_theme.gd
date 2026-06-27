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

## Textured 9-slice frames — the panel/card companions to the pixel button textures
## (navy wood-grain + gold). The corner ornaments live inside the texture margin so
## they stay crisp at any size; the navy center stretches. Marked as preloads so a
## missing asset fails loudly at parse time rather than rendering an invisible panel.
const PANEL_FRAME_TEXTURE := preload("res://assets/ui/panels/popup_panel.png")
const CARD_FRAME_TEXTURE := preload("res://assets/ui/panels/card_frame.png")
const PANEL_FRAME_TEXTURE_MARGIN := 64.0
const CARD_FRAME_TEXTURE_MARGIN := 40.0


## Big popup/dialog frame: textured 9-slice gold-on-navy panel. `margin_*` become the
## inner content padding. Falls back to the flat builder if the texture is unavailable.
static func framed_panel_style(
	margin_x := 22.0,
	margin_y := 18.0,
	fallback_bg := COLOR_PANEL,
	fallback_border := COLOR_GOLD_DIM,
	fallback_width := 2
) -> StyleBox:
	if PANEL_FRAME_TEXTURE == null:
		return panel_style(fallback_bg, fallback_border, fallback_width, margin_x, margin_y)
	return _texture_box(PANEL_FRAME_TEXTURE, PANEL_FRAME_TEXTURE_MARGIN, margin_x, margin_y, Color.WHITE)


## Item-card frame: textured 9-slice thin gold trim + corner studs. `modulate` tints
## the whole frame so callers can express selected/hover/disabled states — or a category
## color — on one texture. `tex_margin` can be shrunk for short bars where the default
## 40px corners would not fit (Godot would otherwise squash the slices to fit).
static func card_style(
	margin_x := 12.0,
	margin_y := 10.0,
	modulate := Color.WHITE,
	tex_margin := CARD_FRAME_TEXTURE_MARGIN
) -> StyleBox:
	if CARD_FRAME_TEXTURE == null:
		return panel_style(COLOR_SLOT, COLOR_STEEL, 2, margin_x, margin_y)
	return _texture_box(CARD_FRAME_TEXTURE, tex_margin, margin_x, margin_y, modulate)


static func _texture_box(
	texture: Texture2D,
	tex_margin: float,
	margin_x: float,
	margin_y: float,
	modulate: Color
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = tex_margin
	style.texture_margin_top = tex_margin
	style.texture_margin_right = tex_margin
	style.texture_margin_bottom = tex_margin
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	style.modulate_color = modulate
	return style


static func panel_style(
	bg_color := COLOR_PANEL,
	border_color := COLOR_STEEL,
	border_width := 2,
	margin_x := 16.0,
	margin_y := 12.0,
	corner_radius := 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.content_margin_left = margin_x
	style.content_margin_top = margin_y
	style.content_margin_right = margin_x
	style.content_margin_bottom = margin_y
	return style


## Weapon/item slot, drawn on the textured card frame. State is read off the gold trim
## via modulate: warm gold = selected, cool dim = idle, faded = disabled.
static func slot_style(selected: bool, disabled := false) -> StyleBox:
	if disabled:
		return card_style(12.0, 10.0, Color(0.5, 0.52, 0.58, 0.7))
	if selected:
		return card_style(12.0, 10.0, Color(1.0, 0.93, 0.62))
	return card_style(12.0, 10.0, Color(0.82, 0.86, 0.93))


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
