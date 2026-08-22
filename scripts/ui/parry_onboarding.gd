class_name ParryOnboarding
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const InputPromptPolicy = preload("res://scripts/ui/input_prompt_policy.gd")

const FLOW_ID := &"first_wolf_parry"
const REVEAL_SECONDS := 0.6
const DISPLAY_SECONDS := 3.4
const DIM_ALPHA := 0.24
const SPOTLIGHT_PADDING := 22.0
const SPOTLIGHT_MIN_SIZE := Vector2(122.0, 122.0)
const TARGET_WORLD_SIZE := Vector2(96.0, 112.0)
const TARGET_WORLD_OFFSET := Vector2(0.0, -34.0)
const PANEL_SIZE := Vector2(448.0, 96.0)
const PANEL_MARGIN := 16.0
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT
const DESKTOP_MESSAGE := "늑대가 돌진할 때 좌클릭으로 배트를 휘둘러 받아치기"
const TOUCH_MESSAGE := "늑대가 돌진할 때 공격 버튼으로 배트를 휘둘러 받아치기"

var _camera: Camera2D = null
var _wolf: Node2D = null
var _input_mode: StringName = InputPromptPolicy.MODE_DESKTOP
var _active := false
var _elapsed := 0.0
var _root: Control = null
var _dim_rects: Array[ColorRect] = []
var _spotlight_frame: Panel = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _message_label: Label = null


func _ready() -> void:
	layer = max(layer, RenderLayers.UI_MODAL_LAYER - 2)
	_build_ui()
	visible = false
	set_process(false)


func configure(camera: Camera2D) -> void:
	_camera = camera


func show_for_wolf(wolf: Node2D, input_mode: StringName) -> void:
	if wolf == null or not is_instance_valid(wolf):
		return
	_wolf = wolf
	_input_mode = InputPromptPolicy.MODE_TOUCH if input_mode == InputPromptPolicy.MODE_TOUCH else InputPromptPolicy.MODE_DESKTOP
	_active = true
	_elapsed = 0.0
	visible = true
	set_process(true)
	_refresh()


func dismiss() -> bool:
	if not _active:
		return false
	_active = false
	_wolf = null
	visible = false
	set_process(false)
	return true


func dismiss_for_wolf(wolf: Node) -> bool:
	if not _active or _wolf != wolf:
		return false
	return dismiss()


func is_active() -> bool:
	return _active


func is_showing_for(wolf: Node) -> bool:
	return _active and _wolf == wolf


func get_visual_contract() -> Dictionary:
	return {
		"flow": FLOW_ID,
		"blocks_gameplay": false,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
		"reveal_seconds": REVEAL_SECONDS,
		"display_seconds": DISPLAY_SECONDS,
		"desktop_message": DESKTOP_MESSAGE,
		"touch_message": TOUCH_MESSAGE,
	}


func get_snapshot() -> Dictionary:
	return {
		"active": _active,
		"input_mode": _input_mode,
		"message": _message_for_mode(),
		"target_name": _wolf.name if _wolf != null and is_instance_valid(_wolf) else "",
		"target_rect": _target_rect(),
		"spotlight_rect": _spotlight_rect(),
		"panel_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"reveal_complete": _elapsed >= REVEAL_SECONDS,
		"blocks_gameplay": false,
		"tree_paused": get_tree().paused if get_tree() != null else false,
	}


func _process(delta: float) -> void:
	if not _active:
		return
	if _wolf == null or not is_instance_valid(_wolf) or _wolf.is_queued_for_deletion():
		dismiss()
		return
	_elapsed += maxf(0.0, delta)
	if _elapsed >= DISPLAY_SECONDS:
		dismiss()
		return
	_refresh()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for index: int in range(4):
		var rect := ColorRect.new()
		rect.name = "DimRect%d" % index
		rect.color = Color(0.0, 0.0, 0.0, DIM_ALPHA)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rect)
		_dim_rects.append(rect)
	_spotlight_frame = Panel.new()
	_spotlight_frame.name = "SpotlightFrame"
	_spotlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spotlight_frame.add_theme_stylebox_override("panel", _spotlight_style())
	_root.add_child(_spotlight_frame)
	_panel = PanelContainer.new()
	_panel.name = "HintPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.name = "HintStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 4)
	_panel.add_child(stack)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "패링"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.52, 1.0, 0.94, 1.0))
	UiFontRoles.apply_title(_title_label)
	stack.add_child(_title_label)
	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_message_label.custom_minimum_size = Vector2(PANEL_SIZE.x - 24.0, 40.0)
	_message_label.add_theme_font_size_override("font_size", 16)
	_message_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	UiFontRoles.apply_pixel(_message_label)
	stack.add_child(_message_label)


func _refresh() -> void:
	if _root == null:
		return
	_message_label.text = _display_message_for_mode()
	var focus_rect := _spotlight_rect()
	_apply_control_rect(_spotlight_frame, focus_rect)
	var pulse := 0.84 + 0.16 * (0.5 + 0.5 * sin(_elapsed * TAU * 1.6))
	_spotlight_frame.modulate = Color(1.0, 1.0, 1.0, pulse)
	_layout_dim_cutout(focus_rect, _elapsed < REVEAL_SECONDS)
	_layout_panel(focus_rect)


func _message_for_mode() -> String:
	return TOUCH_MESSAGE if _input_mode == InputPromptPolicy.MODE_TOUCH else DESKTOP_MESSAGE


func _display_message_for_mode() -> String:
	return _message_for_mode().replace(" 배트를", "\n배트를")


func _layout_dim_cutout(focus_rect: Rect2, reveal_active: bool) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	var safe_focus := focus_rect.intersection(viewport_rect)
	var rects := [
		Rect2(Vector2.ZERO, Vector2(viewport_rect.size.x, safe_focus.position.y)),
		Rect2(Vector2(0.0, safe_focus.end.y), Vector2(viewport_rect.size.x, viewport_rect.size.y - safe_focus.end.y)),
		Rect2(Vector2(0.0, safe_focus.position.y), Vector2(safe_focus.position.x, safe_focus.size.y)),
		Rect2(Vector2(safe_focus.end.x, safe_focus.position.y), Vector2(viewport_rect.size.x - safe_focus.end.x, safe_focus.size.y)),
	]
	for index: int in range(_dim_rects.size()):
		_dim_rects[index].visible = reveal_active
		_apply_control_rect(_dim_rects[index], rects[index] if reveal_active else Rect2())


func _layout_panel(focus_rect: Rect2) -> void:
	var viewport_size := _viewport_size()
	var desired := Vector2(focus_rect.get_center().x - PANEL_SIZE.x * 0.5, focus_rect.position.y - PANEL_SIZE.y - PANEL_MARGIN)
	if desired.y < MobileSafeArea.MIN_TOP:
		desired.y = focus_rect.end.y + PANEL_MARGIN
	desired.x = clampf(desired.x, MobileSafeArea.MIN_LEFT, viewport_size.x - MobileSafeArea.MIN_RIGHT - PANEL_SIZE.x)
	desired.y = clampf(desired.y, MobileSafeArea.MIN_TOP, viewport_size.y - MobileSafeArea.MIN_BOTTOM - PANEL_SIZE.y)
	_apply_control_rect(_panel, Rect2(desired, PANEL_SIZE))


func _spotlight_rect() -> Rect2:
	var target := _target_rect()
	if target.size == Vector2.ZERO:
		target = Rect2((_viewport_size() - SPOTLIGHT_MIN_SIZE) * 0.5, SPOTLIGHT_MIN_SIZE)
	var focus := target.grow(SPOTLIGHT_PADDING)
	focus.size.x = maxf(focus.size.x, SPOTLIGHT_MIN_SIZE.x)
	focus.size.y = maxf(focus.size.y, SPOTLIGHT_MIN_SIZE.y)
	return focus


func _target_rect() -> Rect2:
	if _wolf == null or not is_instance_valid(_wolf):
		return Rect2()
	var center := _world_to_screen(_wolf.global_position + TARGET_WORLD_OFFSET)
	var size := TARGET_WORLD_SIZE * (_camera.zoom if _camera != null else Vector2.ONE)
	return Rect2(center - size * 0.5, size)


func _world_to_screen(world_position: Vector2) -> Vector2:
	var viewport_size := _viewport_size()
	if _camera == null:
		return viewport_size * 0.5
	return viewport_size * 0.5 + (world_position - _camera.get_screen_center_position()) * _camera.zoom


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return VIEWPORT_FALLBACK
	var size := viewport.get_visible_rect().size
	return size if size.x > 0.0 and size.y > 0.0 else VIEWPORT_FALLBACK


func _apply_control_rect(control: Control, rect: Rect2) -> void:
	if control == null:
		return
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = Vector2(maxf(0.0, rect.size.x), maxf(0.0, rect.size.y))


func _spotlight_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.36, 1.0, 0.9, 0.04)
	style.border_color = Color(0.42, 1.0, 0.92, 0.96)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.085, 0.94)
	style.border_color = Color(0.42, 1.0, 0.92, 0.78)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12.0)
	return style
