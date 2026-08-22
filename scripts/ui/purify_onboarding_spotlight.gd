class_name PurifyOnboardingSpotlight
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const InputPromptPolicy = preload("res://scripts/ui/input_prompt_policy.gd")
const Tokens = preload("res://scripts/ui/onboarding_visual_tokens.gd")

signal dismissed(step_id: StringName)

const FLOW_ID := &"baseball_purify_spotlight"
const DIM_ALPHA := 0.28
const DIM_REST_ALPHA := 0.14
const DIM_REVEAL_SECONDS := 0.45
const DIM_FADE_SECONDS := 0.14
const SPOTLIGHT_PADDING := 20.0
const SPOTLIGHT_MIN_SIZE := Vector2(132.0, 132.0)
const DEFAULT_TARGET_SIZE := Vector2(132.0, 156.0)
const DEFAULT_TARGET_OFFSET := Vector2(0.0, -52.0)
const PANEL_SIZE := Vector2(340.0, 72.0)
const PANEL_MARGIN := 14.0
const CONTINUE_SIZE := Vector2(180.0, 34.0)
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

var _camera: Camera2D = null
var _target: Node2D = null
var _target_world_size := DEFAULT_TARGET_SIZE
var _target_world_offset := DEFAULT_TARGET_OFFSET
var _active := false
var _step_id: StringName = &""
var _message := ""
var _elapsed := 0.0
var _root: Control = null
var _dim_rects: Array[ColorRect] = []
var _bracket_parts: Array[ColorRect] = []
var _panel: PanelContainer = null
var _action_label: Label = null
var _detail_label: Label = null
var _continue_chip: Label = null
var _shown_process_frame := -1


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
	_elapsed = 0.0
	_shown_process_frame = Engine.get_process_frames()
	visible = true
	set_process(true)
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
		"bracket_style": &"corners",
		"step_ids": [&"intro", &"groggy"],
		"intro_action": "기절시키기",
		"intro_detail": "공격 · 가까이 가면 정화 시작",
		"groggy_action": "곁을 지켜 정화",
		"groggy_detail": "범위를 벗어나면 처음부터",
		"continue_placement": &"bottom_right_chip",
		"tap_to_continue": true,
	}


func get_snapshot() -> Dictionary:
	var focus_rect := _spotlight_rect()
	var copy := _visual_copy()
	return {
		"active": _active,
		"step_id": _step_id,
		"message": _message,
		"action": copy.get("action", ""),
		"detail": copy.get("detail", ""),
		"target_name": _target.name if _target != null and is_instance_valid(_target) else "",
		"target_rect": _target_rect(),
		"spotlight_rect": focus_rect,
		"panel_rect": _panel.get_global_rect() if _panel != null else Rect2(),
		"continue_rect": _continue_chip.get_global_rect() if _continue_chip != null else Rect2(),
		"bracket_style": &"corners",
		"dim_alpha": _current_dim_alpha() if _active else 0.0,
		"tap_to_continue": true,
		"reduced_motion": _is_reduced_motion(),
	}


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += maxf(0.0, delta)
	_refresh()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if Engine.get_process_frames() <= _shown_process_frame:
		return
	if not InputPromptPolicy.should_accept_pointer_event(_input_mode(), event):
		return
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
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rect)
		_dim_rects.append(rect)
	for index: int in range(8):
		var part := ColorRect.new()
		part.name = "BracketPart%d" % index
		part.color = Tokens.GOLD_INFO
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(part)
		_bracket_parts.append(part)
	_panel = PanelContainer.new()
	_panel.name = "MessagePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", Tokens.coach_style(&"info", true))
	_root.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.name = "MessageStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	_panel.add_child(stack)
	_action_label = Label.new()
	_action_label.name = "ActionLabel"
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 22)
	_action_label.add_theme_color_override("font_color", Tokens.GOLD_INFO)
	UiFontRoles.apply_title(_action_label)
	stack.add_child(_action_label)
	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Tokens.PAPER_TEXT)
	UiFontRoles.apply_pixel(_detail_label)
	stack.add_child(_detail_label)
	_continue_chip = Label.new()
	_continue_chip.name = "ContinueChip"
	_continue_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_continue_chip.add_theme_font_size_override("font_size", 15)
	_continue_chip.add_theme_color_override("font_color", Tokens.GOLD_INFO)
	_continue_chip.add_theme_stylebox_override("normal", Tokens.key_chip_style(&"info"))
	UiFontRoles.apply_pixel(_continue_chip)
	_root.add_child(_continue_chip)


func _refresh() -> void:
	if _root == null:
		return
	var copy := _visual_copy()
	_action_label.text = String(copy.get("action", ""))
	_detail_label.text = String(copy.get("detail", ""))
	_continue_chip.text = "탭  계속" if _input_mode() == InputPromptPolicy.MODE_TOUCH else "클릭  계속"
	var focus_rect := _spotlight_rect()
	_layout_dim_cutout(focus_rect)
	_layout_brackets(focus_rect)
	_layout_panel(focus_rect)
	_layout_continue_chip()
	_apply_motion_state()


func _visual_copy() -> Dictionary:
	if _step_id == &"groggy":
		return {"action": "곁을 지켜 정화", "detail": "범위를 벗어나면 처음부터"}
	return {"action": "기절시키기", "detail": "공격 · 가까이 가면 정화 시작"}


func _input_mode() -> StringName:
	var features := {}
	if has_node("/root/PlatformManager"):
		features = PlatformManager.get_feature_flags()
	return InputPromptPolicy.input_mode_from_features(features)


func _current_dim_alpha() -> float:
	if _is_reduced_motion() or _elapsed >= DIM_REVEAL_SECONDS + DIM_FADE_SECONDS:
		return DIM_REST_ALPHA
	if _elapsed <= DIM_REVEAL_SECONDS:
		return DIM_ALPHA
	var progress := (_elapsed - DIM_REVEAL_SECONDS) / DIM_FADE_SECONDS
	return lerpf(DIM_ALPHA, DIM_REST_ALPHA, clampf(progress, 0.0, 1.0))


func _layout_dim_cutout(focus_rect: Rect2) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	var safe_focus := focus_rect.intersection(viewport_rect)
	var rects := [
		Rect2(Vector2.ZERO, Vector2(viewport_rect.size.x, safe_focus.position.y)),
		Rect2(Vector2(0.0, safe_focus.end.y), Vector2(viewport_rect.size.x, viewport_rect.size.y - safe_focus.end.y)),
		Rect2(Vector2(0.0, safe_focus.position.y), Vector2(safe_focus.position.x, safe_focus.size.y)),
		Rect2(Vector2(safe_focus.end.x, safe_focus.position.y), Vector2(viewport_rect.size.x - safe_focus.end.x, safe_focus.size.y)),
	]
	var dim_color := Color(0.0, 0.0, 0.0, _current_dim_alpha())
	for index: int in range(_dim_rects.size()):
		_dim_rects[index].color = dim_color
		_apply_control_rect(_dim_rects[index], rects[index])


func _layout_brackets(focus_rect: Rect2) -> void:
	var length := Tokens.TARGET_BRACKET_LENGTH
	var width := Tokens.TARGET_BRACKET_WIDTH
	var rects: Array[Rect2] = [
		Rect2(focus_rect.position, Vector2(length, width)),
		Rect2(focus_rect.position, Vector2(width, length)),
		Rect2(Vector2(focus_rect.end.x - length, focus_rect.position.y), Vector2(length, width)),
		Rect2(Vector2(focus_rect.end.x - width, focus_rect.position.y), Vector2(width, length)),
		Rect2(Vector2(focus_rect.position.x, focus_rect.end.y - width), Vector2(length, width)),
		Rect2(Vector2(focus_rect.position.x, focus_rect.end.y - length), Vector2(width, length)),
		Rect2(Vector2(focus_rect.end.x - length, focus_rect.end.y - width), Vector2(length, width)),
		Rect2(Vector2(focus_rect.end.x - width, focus_rect.end.y - length), Vector2(width, length)),
	]
	for index: int in range(_bracket_parts.size()):
		_apply_control_rect(_bracket_parts[index], rects[index])


func _layout_panel(focus_rect: Rect2) -> void:
	var viewport_size := _viewport_size()
	var desired := Vector2(focus_rect.get_center().x - PANEL_SIZE.x * 0.5, focus_rect.position.y - PANEL_SIZE.y - PANEL_MARGIN)
	if desired.y < MobileSafeArea.MIN_TOP:
		desired.y = focus_rect.end.y + PANEL_MARGIN
	desired.x = clampf(desired.x, MobileSafeArea.MIN_LEFT, viewport_size.x - MobileSafeArea.MIN_RIGHT - PANEL_SIZE.x)
	desired.y = clampf(desired.y, MobileSafeArea.MIN_TOP, viewport_size.y - MobileSafeArea.MIN_BOTTOM - PANEL_SIZE.y)
	_apply_control_rect(_panel, Rect2(desired, PANEL_SIZE))


func _layout_continue_chip() -> void:
	var viewport_size := _viewport_size()
	_apply_control_rect(_continue_chip, Rect2(
		Vector2(viewport_size.x - MobileSafeArea.MIN_RIGHT - CONTINUE_SIZE.x, viewport_size.y - 58.0 - CONTINUE_SIZE.y),
		CONTINUE_SIZE
	))


func _apply_motion_state() -> void:
	if _is_reduced_motion():
		_panel.modulate = Color.WHITE
		_panel.scale = Vector2.ONE
		for part: ColorRect in _bracket_parts:
			part.modulate = Color.WHITE
		return
	var enter_progress := clampf(_elapsed / Tokens.ENTER_DURATION, 0.0, 1.0)
	_panel.modulate.a = enter_progress
	_panel.scale = Vector2.ONE * lerpf(0.94, 1.0, enter_progress)
	var bracket_progress := clampf(_elapsed / Tokens.BRACKET_DURATION, 0.0, 1.0)
	for part: ColorRect in _bracket_parts:
		part.modulate.a = bracket_progress


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
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = Vector2(maxf(0.0, rect.size.x), maxf(0.0, rect.size.y))


func _is_reduced_motion() -> bool:
	return has_node("/root/Settings") and Settings.is_reduced_motion_enabled()
