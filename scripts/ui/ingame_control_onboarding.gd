class_name IngameControlOnboarding
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")

const FLOW_ID := &"first_ingame_controls"
const DIM_ALPHA := 0.58
const SPOTLIGHT_PADDING := 14.0
const SPOTLIGHT_MIN_SIZE := Vector2(96.0, 96.0)
const MOVE_THRESHOLD := 0.18
const CAMERA_ZOOM_TARGET := 1.06
const CAMERA_ZOOM_SECONDS := 0.18
const CAMERA_RESTORE_SECONDS := 0.14
const LABEL_SIZE := Vector2(270.0, 82.0)
const LABEL_MARGIN := 18.0
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

const STEPS: Array[Dictionary] = [
	{
		"id": &"move",
		"title": "이동",
		"body": "왼쪽 스틱을 밀어 움직이기",
		"targets": ["Joystick"],
	},
	{
		"id": &"attack",
		"title": "기본공격",
		"body": "칼 버튼으로 가까운 적을 공격",
		"targets": ["AttackButton"],
	},
	{
		"id": &"dash",
		"title": "대쉬",
		"body": "> 버튼으로 짧게 회피",
		"targets": ["SkillButton"],
	},
	{
		"id": &"power_attack",
		"title": "강공격",
		"body": "대쉬 직후 칼 버튼으로 강공격",
		"targets": ["SkillButton", "AttackButton"],
	},
]

var _touch_controls: Node = null
var _camera: Camera2D = null
var _player: Node = null
var _active := false
var _step_index := 0
var _original_camera_zoom := Vector2.ONE
var _camera_zoom_active := false
var _camera_tween: Tween = null
var _pulse_time := 0.0
var _root: Control = null
var _dim_rects: Array[ColorRect] = []
var _spotlight_frame: Panel = null
var _label_panel: PanelContainer = null
var _title_label: Label = null
var _body_label: Label = null


func _ready() -> void:
	layer = max(layer, RenderLayers.UI_MODAL_LAYER - 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	set_process(false)


func configure(touch_controls: Node, camera: Camera2D = null, player: Node = null) -> void:
	_touch_controls = touch_controls
	_camera = camera
	_player = player
	if _camera != null:
		_original_camera_zoom = _camera.zoom


func start() -> void:
	_step_index = 0
	_active = true
	visible = true
	set_process(true)
	_apply_camera_zoom()
	_refresh_step()


func finish() -> void:
	if not _active and not visible:
		return
	_active = false
	visible = false
	set_process(false)
	_restore_camera_zoom()


func is_active() -> bool:
	return _active


func get_visual_contract() -> Dictionary:
	return {
		"flow": FLOW_ID,
		"blocks_gameplay": false,
		"uses_dim_cutout": true,
		"dim_alpha": DIM_ALPHA,
		"spotlight_padding": SPOTLIGHT_PADDING,
		"camera_zoom_target": CAMERA_ZOOM_TARGET,
		"step_ids": _step_ids(),
		"step_target_names": _step_target_names(),
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
	}


func get_current_step_snapshot() -> Dictionary:
	var step := _current_step()
	var target_names := _current_target_names()
	return {
		"active": _active,
		"step_id": step.get("id", &""),
		"title": String(step.get("title", "")),
		"body": String(step.get("body", "")),
		"target_names": target_names,
		"target_rect": _target_rect_for_names(target_names),
		"dim_alpha": DIM_ALPHA if _active else 0.0,
	}


func advance_from_input(input_state: Dictionary) -> bool:
	if not _active:
		return false
	var step_id: StringName = _current_step().get("id", &"")
	var should_advance := false
	match step_id:
		&"move":
			should_advance = (input_state.get("move", Vector2.ZERO) as Vector2).length() >= MOVE_THRESHOLD
		&"attack":
			should_advance = bool(input_state.get("attack_pressed", false))
		&"dash":
			should_advance = bool(input_state.get("dash_pressed", false))
		&"power_attack":
			should_advance = (
				bool(input_state.get("dash_pressed", false))
				and bool(input_state.get("attack_pressed", false))
				and bool(input_state.get("power_window_active", false))
			)
	if not should_advance:
		return false
	_advance_step()
	return true


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += maxf(0.0, delta)
	advance_from_input(_runtime_input_state())
	_refresh_step()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	for index in range(4):
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
	_label_panel = PanelContainer.new()
	_label_panel.name = "HintPanel"
	_label_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_panel.custom_minimum_size = LABEL_SIZE
	_label_panel.add_theme_stylebox_override("panel", _hint_panel_style())
	_root.add_child(_label_panel)
	var box := VBoxContainer.new()
	box.name = "HintText"
	box.add_theme_constant_override("separation", 4)
	_label_panel.add_child(box)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	UiFontRoles.apply_title(_title_label)
	box.add_child(_title_label)
	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	UiFontRoles.apply_pixel(_body_label)
	box.add_child(_body_label)


func _refresh_step() -> void:
	if not _active or _root == null:
		return
	var step := _current_step()
	_title_label.text = String(step.get("title", ""))
	_body_label.text = String(step.get("body", ""))
	var focus_rect := _spotlight_rect_for_names(_current_target_names())
	_layout_dim_cutout(focus_rect)
	_layout_spotlight(focus_rect)
	_layout_label(focus_rect)


func _layout_dim_cutout(focus_rect: Rect2) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	var safe_focus := focus_rect.intersection(viewport_rect)
	var top_rect := Rect2(Vector2.ZERO, Vector2(viewport_rect.size.x, safe_focus.position.y))
	var bottom_rect := Rect2(Vector2(0.0, safe_focus.end.y), Vector2(viewport_rect.size.x, viewport_rect.size.y - safe_focus.end.y))
	var left_rect := Rect2(Vector2(0.0, safe_focus.position.y), Vector2(safe_focus.position.x, safe_focus.size.y))
	var right_rect := Rect2(Vector2(safe_focus.end.x, safe_focus.position.y), Vector2(viewport_rect.size.x - safe_focus.end.x, safe_focus.size.y))
	var rects := [top_rect, bottom_rect, left_rect, right_rect]
	for index in range(_dim_rects.size()):
		_apply_control_rect(_dim_rects[index], rects[index])


func _layout_spotlight(focus_rect: Rect2) -> void:
	_apply_control_rect(_spotlight_frame, focus_rect)
	var pulse := 0.82 + (0.18 * (0.5 + 0.5 * sin(_pulse_time * TAU * 1.4)))
	_spotlight_frame.modulate = Color(1.0, 1.0, 1.0, pulse)


func _layout_label(focus_rect: Rect2) -> void:
	var viewport_size := _viewport_size()
	var desired := Vector2(focus_rect.position.x, focus_rect.position.y - LABEL_SIZE.y - LABEL_MARGIN)
	if desired.y < MobileSafeArea.MIN_TOP:
		desired.y = focus_rect.end.y + LABEL_MARGIN
	if focus_rect.get_center().x > viewport_size.x * 0.5:
		desired.x = focus_rect.end.x - LABEL_SIZE.x
	desired.x = clampf(desired.x, MobileSafeArea.MIN_LEFT, viewport_size.x - MobileSafeArea.MIN_RIGHT - LABEL_SIZE.x)
	desired.y = clampf(desired.y, MobileSafeArea.MIN_TOP, viewport_size.y - MobileSafeArea.MIN_BOTTOM - LABEL_SIZE.y)
	_apply_control_rect(_label_panel, Rect2(desired, LABEL_SIZE))


func _spotlight_rect_for_names(target_names: Array) -> Rect2:
	var rect := _target_rect_for_names(target_names)
	if rect.size == Vector2.ZERO:
		rect = Rect2((_viewport_size() - SPOTLIGHT_MIN_SIZE) * 0.5, SPOTLIGHT_MIN_SIZE)
	var focus := rect.grow(SPOTLIGHT_PADDING)
	focus.size.x = maxf(focus.size.x, SPOTLIGHT_MIN_SIZE.x)
	focus.size.y = maxf(focus.size.y, SPOTLIGHT_MIN_SIZE.y)
	return focus


func _target_rect_for_names(target_names: Array) -> Rect2:
	var rect := Rect2()
	var found := false
	if _touch_controls == null:
		return rect
	for target_name: String in target_names:
		var control := _touch_controls.get_node_or_null(NodePath(target_name)) as Control
		if control == null or not control.visible:
			continue
		var control_rect := control.get_global_rect()
		if not found:
			rect = control_rect
			found = true
		else:
			rect = rect.merge(control_rect)
	return rect if found else Rect2()


func _runtime_input_state() -> Dictionary:
	if _touch_controls == null:
		return {}
	var move := Vector2.ZERO
	var attack_pressed := false
	var dash_pressed := false
	if _touch_controls.has_method("get_move"):
		move = _touch_controls.call("get_move")
	if _touch_controls.has_method("is_attack_pressed"):
		attack_pressed = bool(_touch_controls.call("is_attack_pressed"))
	if _touch_controls.has_method("is_skill_pressed"):
		dash_pressed = bool(_touch_controls.call("is_skill_pressed"))
	return {
		"move": move,
		"attack_pressed": attack_pressed,
		"dash_pressed": dash_pressed,
		"power_window_active": _is_power_window_active(),
	}


func _is_power_window_active() -> bool:
	if _player == null:
		return false
	var is_dodging := false
	var has_power_window := false
	if _player.has_method("is_dodging"):
		is_dodging = bool(_player.call("is_dodging"))
	if _player.has_method("get_dash_power_attack_remaining"):
		has_power_window = float(_player.call("get_dash_power_attack_remaining")) > 0.0
	return is_dodging or has_power_window


func _advance_step() -> void:
	_step_index += 1
	if _step_index >= STEPS.size():
		finish()
		return
	_refresh_step()


func _apply_camera_zoom() -> void:
	if _camera == null:
		return
	if not _camera_zoom_active:
		_original_camera_zoom = _camera.zoom
	_camera_zoom_active = true
	_camera.zoom = _original_camera_zoom * lerpf(1.0, CAMERA_ZOOM_TARGET, 0.45)
	_kill_camera_tween()
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, ^"zoom", _original_camera_zoom * CAMERA_ZOOM_TARGET, CAMERA_ZOOM_SECONDS)


func _restore_camera_zoom() -> void:
	if _camera == null or not _camera_zoom_active:
		return
	_camera_zoom_active = false
	_kill_camera_tween()
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, ^"zoom", _original_camera_zoom, CAMERA_RESTORE_SECONDS)


func _kill_camera_tween() -> void:
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null


func _current_step() -> Dictionary:
	if STEPS.is_empty():
		return {}
	return STEPS[clampi(_step_index, 0, STEPS.size() - 1)]


func _current_target_names() -> Array:
	return (_current_step().get("targets", []) as Array).duplicate()


func _step_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for step: Dictionary in STEPS:
		ids.append(step.get("id", &""))
	return ids


func _step_target_names() -> Array:
	var target_names := []
	for step: Dictionary in STEPS:
		target_names.append((step.get("targets", []) as Array).duplicate())
	return target_names


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
	style.bg_color = Color(1.0, 1.0, 1.0, 0.04)
	style.border_color = Color(1.0, 0.86, 0.36, 0.95)
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	return style


func _hint_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.88)
	style.border_color = Color(1.0, 0.84, 0.36, 0.72)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14.0)
	return style
