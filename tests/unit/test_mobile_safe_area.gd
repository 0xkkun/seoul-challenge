extends Node

const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_landscape_phone_minimum_insets_are_project_contract() -> void:
	_runner.assert_eq(MobileSafeArea.landscape_minimum_insets(), {
		"left": 60.0,
		"top": 24.0,
		"right": 60.0,
		"bottom": 34.0,
	}, "가로폰 safe-area fallback 기준을 고정한다")
	_runner.assert_eq(MobileSafeArea.touch_insets(), {
		"left": 72.0,
		"right": 72.0,
		"bottom": 58.0,
	}, "핵심 터치 컨트롤은 더 넓은 여백을 둔다")


func test_bottom_anchored_cta_rect_keeps_home_indicator_gap() -> void:
	var rect := MobileSafeArea.bottom_anchored_rect(0.61, 0.33, 0.13)
	var margins := MobileSafeArea.margins_for_rect(Rect2(
		Vector2(rect.position.x * 960.0, rect.position.y * 540.0),
		Vector2(rect.size.x * 960.0, rect.size.y * 540.0)
	))

	_runner.assert_true(float(margins["bottom"]) >= MobileSafeArea.cta_bottom_margin(), "하단 CTA는 홈 인디케이터 위로 뜬다")
	_runner.assert_true(float(margins["right"]) >= 57.0, "기존 우측 CTA의 가로 여백을 유지한다")


func test_apply_edge_offsets_moves_control_inside_landscape_safe_area() -> void:
	var control := Control.new()
	control.anchor_left = 1.0
	control.anchor_right = 1.0
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	add_child(control)

	MobileSafeArea.apply_edge_offsets(control, -1.0, -1.0, 72.0, 58.0)

	_runner.assert_eq(control.offset_right, -72.0, "오른쪽 safe-area offset을 적용한다")
	_runner.assert_eq(control.offset_bottom, -58.0, "하단 safe-area offset을 적용한다")
	control.free()
