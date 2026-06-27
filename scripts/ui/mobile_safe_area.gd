class_name MobileSafeArea
extends RefCounted
## 가로폰(landscape phone) safe-area 기준과 반복 배치 헬퍼.
##
## 960x540 설계 좌표에서 좌/우 노치·라운드 코너와 하단 gesture bar를
## 피하기 위한 최소 여백을 제공한다. 실제 기기 safe-area API 연동 전에도
## 일관된 fallback 계약으로 UI가 화면 가장자리에 붙지 않게 유지한다.

const DESIGN_VIEWPORT := Vector2(960.0, 540.0)
const MIN_LEFT := 60.0
const MIN_TOP := 24.0
const MIN_RIGHT := 60.0
const MIN_BOTTOM := 34.0
const TOUCH_SIDE := 72.0
const TOUCH_BOTTOM := 58.0
const CTA_BOTTOM := 40.0


static func landscape_minimum_insets() -> Dictionary:
	return {
		"left": MIN_LEFT,
		"top": MIN_TOP,
		"right": MIN_RIGHT,
		"bottom": MIN_BOTTOM,
	}


static func touch_insets() -> Dictionary:
	return {
		"left": TOUCH_SIDE,
		"right": TOUCH_SIDE,
		"bottom": TOUCH_BOTTOM,
	}


static func cta_bottom_margin() -> float:
	return CTA_BOTTOM


static func bottom_anchored_rect(left: float, width: float, height: float, bottom_margin_px := CTA_BOTTOM, viewport_size := DESIGN_VIEWPORT) -> Rect2:
	var safe_left := MIN_LEFT / viewport_size.x
	var safe_right := 1.0 - (MIN_RIGHT / viewport_size.x)
	var clamped_left := clampf(left, safe_left, safe_right - width)
	var top := 1.0 - (bottom_margin_px / viewport_size.y) - height
	return Rect2(clamped_left, top, width, height)


static func apply_edge_offsets(control: Control, left := -1.0, top := -1.0, right := -1.0, bottom := -1.0) -> void:
	if control == null:
		return
	var preserve_width := left >= 0.0 and right < 0.0 and is_equal_approx(control.anchor_left, control.anchor_right)
	var preserve_right_width := right >= 0.0 and left < 0.0 and is_equal_approx(control.anchor_left, control.anchor_right)
	var preserve_height := top >= 0.0 and bottom < 0.0 and is_equal_approx(control.anchor_top, control.anchor_bottom)
	var preserve_bottom_height := bottom >= 0.0 and top < 0.0 and is_equal_approx(control.anchor_top, control.anchor_bottom)
	var width := control.offset_right - control.offset_left
	var height := control.offset_bottom - control.offset_top
	if left >= 0.0:
		control.offset_left = left
		if preserve_width:
			control.offset_right = control.offset_left + width
	if right >= 0.0:
		control.offset_right = -right
		if preserve_right_width:
			control.offset_left = control.offset_right - width
	if top >= 0.0:
		control.offset_top = top
		if preserve_height:
			control.offset_bottom = control.offset_top + height
	if bottom >= 0.0:
		control.offset_bottom = -bottom
		if preserve_bottom_height:
			control.offset_top = control.offset_bottom - height


static func margins_for_rect(rect: Rect2, viewport_size := DESIGN_VIEWPORT) -> Dictionary:
	return {
		"left": rect.position.x,
		"top": rect.position.y,
		"right": viewport_size.x - rect.end.x,
		"bottom": viewport_size.y - rect.end.y,
	}


static func meets_landscape_minimum(rect: Rect2, viewport_size := DESIGN_VIEWPORT) -> bool:
	var margins := margins_for_rect(rect, viewport_size)
	return (
		float(margins["left"]) >= MIN_LEFT
		and float(margins["top"]) >= MIN_TOP
		and float(margins["right"]) >= MIN_RIGHT
		and float(margins["bottom"]) >= MIN_BOTTOM
	)
