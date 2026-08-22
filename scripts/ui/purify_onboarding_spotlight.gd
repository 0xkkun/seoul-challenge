class_name PurifyOnboardingSpotlight
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const InputPromptPolicy := preload("res://scripts/ui/input_prompt_policy.gd")

signal dismissed(step_id: StringName)

const FLOW_ID := &"baseball_purify_spotlight"
const DIM_ALPHA := 0.66
const SPOTLIGHT_PADDING := 26.0
const SPOTLIGHT_MIN_SIZE := Vector2(132.0, 132.0)
const DEFAULT_TARGET_SIZE := Vector2(132.0, 156.0)
const DEFAULT_TARGET_OFFSET := Vector2(0.0, -52.0)
const PANEL_SIZE := Vector2(410.0, 116.0)
const PANEL_MARGIN := 18.0
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

var _camera: Camera2D = null
var _target: Node2D = null
var _target_world_size := DEFAULT_TARGET_SIZE
var _target_world_offset := DEFAULT_TARGET_OFFSET
var _active := false
var _step_id: StringName = &""
var _message := ""
var _pulse_time := 0.0
var _root: Control = null
var _dim_rects: Array[ColorRect] = []
var _spotlight_frame: Panel = null
var _panel: PanelContainer = null
var _message_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	layer = max(layer, RenderLayers.UI_MODAL_LAYER - 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	set_process(false)


func configure(camera: Camera2D) -> void:
	_camera = camera


func show_step(
		step_id: StringName,
		message: String,
		target: Node2D,
		target_world_size := DEFAULT_TARGET_SIZE,
		target_world_offset := DEFAULT_TARGET_OFFSET
) -> void:
	_step_id = step_id
	_message = message
	_target = target
	_target_world_size = target_world_size
	_target_world_offset = target_world_offset
	_active = true
	visible = true
	set_process(true)
	_pulse_time = 0.0
	_refresh()


func dismiss() -> bool:
	if not _active:
		return false
	var dismissed_step := _step_id
	_active = false
	visible = false
	set_process(false)
	_target = null
	dismissed.emit(dismissed_step)
	return true


func is_active() -> bool:
	return _active


func get_visual_contract() -> Dictionary:
	return {
		"flow": FLOW_ID,
		"blocks_gameplay": true,
		"uses_dim_cutout": true,
		"dim_alpha": DIM_ALPHA,
		"spotlight_padding": SPOTLIGHT_PADDING,
		"step_ids": [&"intro", &"groggy"],
		"intro_message": "요괴에 씌인 친구를 정화시켜주세요",
		"groggy_message": "친구에게 다가가면 정화의식이 시작돼요!",
		"tap_to_continue": true,
	}


func get_snapshot() -> Dictionary:
	var focus_rect := _spotlight_rect()
	return {
		"active": _active,
		"step_id": _step_id,
		"message": _message,
		"target_name": _target.name if _target != null and is_instance_valid(_target) else "",
		"target_rect": _target_rect(),
		"spotlight_rect": focus_rect,
		"dim_alpha": DIM_ALPHA if _active else 0.0,
		"tap_to_continue": true,
	}


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += maxf(0.0, delta)
	_refresh()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		get_viewport().set_input_as_handled()
		dismiss()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		get_viewport().set_input_as_handled()
		dismiss()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_panel.name = "MessagePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_root.add_child(_panel)
	var box := VBoxContainer.new()
	box.name = "MessageStack"
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_message_label = Label.new()
	_message_label.name = "MessageLabel"
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 21)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.64, 1.0))
	_message_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	_message_label.add_theme_constant_override("outline_size", 2)
	UiFontRoles.apply_title(_message_label)
	box.add_child(_message_label)
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = _action_hint(&"start")
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.91, 0.95, 1.0, 0.9))
	UiFontRoles.apply_pixel(_hint_label)
	box.add_child(_hint_label)


func _refresh() -> void:
	if _root == null:
		return
	_message_label.text = _message
	_hint_label.text = _action_hint(&"start" if _step_id == &"intro" else &"continue")
	var focus_rect := _spotlight_rect()
	_layout_dim_cutout(focus_rect)
	_apply_control_rect(_spotlight_frame, focus_rect)
	var pulse := 0.82 + (0.18 * (0.5 + 0.5 * sin(_pulse_time * TAU * 1.25)))
	_spotlight_frame.modulate = Color(1.0, 1.0, 1.0, pulse)
	_layout_panel(focus_rect)


func _action_hint(action: StringName) -> String:
	var features := {}
	if has_node("/root/PlatformManager"):
		features = PlatformManager.get_feature_flags()
	return InputPromptPolicy.action_hint(
		action,
		InputPromptPolicy.input_mode_from_features(features)
	)


func _layout_dim_cutout(focus_rect: Rect2) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	var safe_focus := focus_rect.intersection(viewport_rect)
	var top_rect := Rect2(Vector2.ZERO, Vector2(viewport_rect.size.x, safe_focus.position.y))
	var bottom_rect := Rect2(Vector2(0.0, safe_focus.end.y), Vector2(viewport_rect.size.x, viewport_rect.size.y - safe_focus.end.y))
	var left_rect := Rect2(Vector2(0.0, safe_focus.position.y), Vector2(safe_focus.position.x, safe_focus.size.y))
	var right_rect := Rect2(Vector2(safe_focus.end.x, safe_focus.position.y), Vector2(viewport_rect.size.x - safe_focus.end.x, safe_focus.size.y))
	var rects := [top_rect, bottom_rect, left_rect, right_rect]
	for index: int in range(_dim_rects.size()):
		_apply_control_rect(_dim_rects[index], rects[index])


func _layout_panel(focus_rect: Rect2) -> void:
	var viewport_size := _viewport_size()
	var desired := Vector2(focus_rect.get_center().x - PANEL_SIZE.x * 0.5, focus_rect.position.y - PANEL_SIZE.y - PANEL_MARGIN)
	if desired.y < MobileSafeArea.MIN_TOP:
		desired.y = focus_rect.end.y + PANEL_MARGIN
	desired.x = clampf(desired.x, MobileSafeArea.MIN_LEFT, viewport_size.x - MobileSafeArea.MIN_RIGHT - PANEL_SIZE.x)
	desired.y = clampf(desired.y, MobileSafeArea.MIN_TOP, viewport_size.y - MobileSafeArea.MIN_BOTTOM - PANEL_SIZE.y)
	_apply_control_rect(_panel, Rect2(desired, PANEL_SIZE))


func _spotlight_rect() -> Rect2:
	var rect := _target_rect()
	if rect.size == Vector2.ZERO:
		rect = Rect2((_viewport_size() - SPOTLIGHT_MIN_SIZE) * 0.5, SPOTLIGHT_MIN_SIZE)
	var focus := rect.grow(SPOTLIGHT_PADDING)
	focus.size.x = maxf(focus.size.x, SPOTLIGHT_MIN_SIZE.x)
	focus.size.y = maxf(focus.size.y, SPOTLIGHT_MIN_SIZE.y)
	return focus


func _target_rect() -> Rect2:
	if _target == null or not is_instance_valid(_target):
		return Rect2()
	var center := world_to_screen(_target.global_position + _target_world_offset, _camera, _viewport_size())
	var size := _target_world_size * _camera_zoom()
	return Rect2(center - size * 0.5, size)


func world_to_screen(world_position: Vector2, camera: Camera2D, viewport_size: Vector2) -> Vector2:
	if camera == null:
		return viewport_size * 0.5
	var camera_center := camera.get_screen_center_position()
	return viewport_size * 0.5 + (world_position - camera_center) * camera.zoom


func _camera_zoom() -> Vector2:
	return _camera.zoom if _camera != null else Vector2.ONE


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
	style.bg_color = Color(1.0, 1.0, 1.0, 0.035)
	style.border_color = Color(1.0, 0.82, 0.24, 0.95)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.08, 0.92)
	style.border_color = Color(1.0, 0.80, 0.26, 0.76)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	return style
