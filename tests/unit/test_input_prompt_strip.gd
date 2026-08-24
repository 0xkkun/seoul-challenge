extends Node

const STRIP_PATH := "res://scripts/ui/input_prompt_strip.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_desktop_strip_renders_mouse_sequence_and_shift_keycap() -> void:
	_runner.assert_true(ResourceLoader.exists(STRIP_PATH), "공통 입력 글리프 strip이 존재한다")
	if not ResourceLoader.exists(STRIP_PATH):
		return
	var strip := (load(STRIP_PATH) as Script).new() as Control
	add_child(strip)
	strip.call("configure", [&"aim_hold", &"attack", &"dash"], &"desktop")
	var snapshot: Dictionary = strip.call("get_snapshot")
	_runner.assert_eq(snapshot.get("actions", []), [&"aim_hold", &"attack", &"dash"], "요청한 입력 순서를 보존한다")
	_runner.assert_eq(snapshot.get("texture_paths", []), [
		"res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png",
		"res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png",
	], "우클릭 조준 뒤 좌클릭 타격 그림을 사용한다")
	_runner.assert_eq(snapshot.get("keycaps", []), ["SHIFT"], "대시는 Shift 키캡으로 그린다")
	_runner.assert_eq(snapshot.get("texture_filter", -1), CanvasItem.TEXTURE_FILTER_NEAREST, "16px 글리프는 nearest로 확대한다")
	var visible_copy := String(snapshot.get("visible_copy", ""))
	_runner.assert_false(visible_copy.contains("LMB"), "LMB 약어를 노출하지 않는다")
	_runner.assert_false(visible_copy.contains("RMB"), "RMB 약어를 노출하지 않는다")
	_runner.assert_false(visible_copy.contains("SPACE"), "SPACE 약어를 노출하지 않는다")


func test_touch_mode_hides_pc_strip() -> void:
	_runner.assert_true(ResourceLoader.exists(STRIP_PATH), "공통 입력 글리프 strip이 존재한다")
	if not ResourceLoader.exists(STRIP_PATH):
		return
	var strip := (load(STRIP_PATH) as Script).new() as Control
	add_child(strip)
	strip.call("configure", [&"attack"], &"touch")
	_runner.assert_false(strip.visible, "touch mode는 PC 글리프를 렌더링하지 않는다")
