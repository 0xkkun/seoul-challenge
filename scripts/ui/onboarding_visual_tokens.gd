class_name OnboardingVisualTokens
extends RefCounted

const MAX_LABEL_SIZE := Vector2(340.0, 72.0)
const MAX_RIBBON_SIZE := Vector2(320.0, 48.0)
const INK_SURFACE := Color(0.025, 0.04, 0.055, 0.74)
const INK_SURFACE_STRONG := Color(0.025, 0.04, 0.055, 0.88)
const PAPER_TEXT := Color(0.96, 0.91, 0.80, 1.0)
const GOLD_INFO := Color(0.93, 0.70, 0.25, 1.0)
const CYAN_TIMING := Color(0.38, 0.94, 0.89, 1.0)
const VERMILION_DANGER := Color(0.91, 0.29, 0.23, 1.0)
const SOFT_SHADOW := Color(0.0, 0.0, 0.0, 0.54)
const PANEL_RADIUS := 4
const PANEL_BORDER_WIDTH := 1
const KEY_CHIP_HEIGHT := 34.0
const TARGET_BRACKET_LENGTH := 14.0
const TARGET_BRACKET_WIDTH := 3.0
const ENTER_DURATION := 0.18
const BRACKET_DURATION := 0.22
const COMPLETE_DURATION := 0.20
const DISMISS_DURATION := 0.14


static func tone_color(tone: StringName) -> Color:
	match tone:
		&"timing":
			return CYAN_TIMING
		&"danger":
			return VERMILION_DANGER
	return GOLD_INFO


static func motion_duration(kind: StringName, reduced_motion: bool) -> float:
	if reduced_motion:
		return 0.0
	match kind:
		&"enter":
			return ENTER_DURATION
		&"bracket":
			return BRACKET_DURATION
		&"complete":
			return COMPLETE_DURATION
		&"dismiss":
			return DISMISS_DURATION
	return 0.0


static func coach_style(tone: StringName, strong := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = INK_SURFACE_STRONG if strong else INK_SURFACE
	style.border_color = tone_color(tone)
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(PANEL_RADIUS)
	style.set_content_margin_all(8.0)
	return style


static func key_chip_style(tone: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.04, 0.94)
	style.border_color = tone_color(tone)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func screen_coverage(rects: Array[Rect2], viewport_size: Vector2) -> float:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 0.0
	var area := 0.0
	for rect: Rect2 in rects:
		area += maxf(0.0, rect.size.x) * maxf(0.0, rect.size.y)
	return area / (viewport_size.x * viewport_size.y)
