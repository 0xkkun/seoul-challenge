class_name IngameControlOnboarding
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const PixelButtonStyle = preload("res://scripts/ui/pixel_button_style.gd")

signal completed
signal skipped
signal gate_released

const FLOW_ID := &"first_ingame_controls"
const DIM_ALPHA := 0.58
const SPOTLIGHT_PADDING := 14.0
const SPOTLIGHT_MIN_SIZE := Vector2(96.0, 96.0)
const MOVE_DISTANCE_REQUIRED := 96.0
const SKIP_REVEAL_SECONDS := 5.0
const SKIP_BUTTON_SIZE := Vector2(168.0, 48.0)
const SKIP_BUTTON_BOTTOM := 58.0
const COMPACT_LEGEND_SIZE := Vector2(238.0, 118.0)
const COMPACT_LEGEND_LEFT := 60.0
const COMPACT_LEGEND_TOP := 118.0
const ONBOARDING_START_ROOM_ID := &"start"
const CAMERA_ZOOM_TARGET := 1.06
const CAMERA_ZOOM_SECONDS := 0.18
const CAMERA_RESTORE_SECONDS := 0.14
const LABEL_SIZE := Vector2(270.0, 82.0)
const LABEL_MARGIN := 18.0
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

const TOUCH_STEPS: Array[Dictionary] = [
	{
		"id": &"move",
		"title": "이동",
		"body": "왼쪽 스틱으로 96px 이동",
		"targets": ["Joystick"],
	},
	{
		"id": &"attack",
		"title": "기본공격",
		"body": "공격 버튼으로 가까운 적을 공격",
		"targets": ["AttackButton"],
	},
	{
		"id": &"dash",
		"title": "대시",
		"body": "대시 버튼으로 짧게 회피",
		"targets": ["SkillButton"],
	},
	{
		"id": &"power_attack",
		"title": "강공격",
		"body": "대시 직후 공격 버튼으로 강공격",
		"targets": ["SkillButton", "AttackButton"],
	},
	{
		"id": &"minimap",
		"title": "지도",
		"body": "오른쪽 위 지도를 탭해 펼치기",
		"targets": ["Minimap"],
	},
	{
		"id": &"exit",
		"title": "출구",
		"body": "열린 문으로 이동",
		"targets": [],
	},
]

const DESKTOP_STEPS: Array[Dictionary] = [
	{
		"id": &"move",
		"title": "이동",
		"body": "WASD 또는 방향키로 96px 이동",
		"targets": [],
	},
	{
		"id": &"attack",
		"title": "기본공격",
		"body": "좌클릭으로 가까운 적을 공격",
		"targets": [],
	},
	{
		"id": &"dash",
		"title": "대시",
		"body": "SPACE로 짧게 회피",
		"targets": [],
	},
	{
		"id": &"power_attack",
		"title": "강공격",
		"body": "SPACE 직후 좌클릭으로 강공격",
		"targets": [],
	},
	{
		"id": &"minimap",
		"title": "지도",
		"body": "오른쪽 위 지도를 클릭해 펼치기",
		"targets": ["Minimap"],
	},
	{
		"id": &"exit",
		"title": "출구",
		"body": "열린 문으로 이동",
		"targets": [],
	},
]

var _touch_controls: Node = null
var _touch_guidance_enabled := false
var _camera: Camera2D = null
var _player: Node = null
var _minimap_target: Control = null
var _active := false
var _step_index := 0
var _active_elapsed := 0.0
var _movement_distance := 0.0
var _last_player_position := Vector2.ZERO
var _has_player_position := false
var _gate_released_emitted := false
var _completed_emitted := false
var _skipped_emitted := false
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
var _skip_button: Button = null
var _compact_legend: PanelContainer = null
var _legend_label: Label = null


func _ready() -> void:
	layer = max(layer, RenderLayers.UI_MODAL_LAYER - 1)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	set_process(false)


func configure(touch_controls: Node, camera: Camera2D = null, player: Node = null, minimap_target: Control = null) -> void:
	_touch_controls = touch_controls
	_touch_guidance_enabled = _touch_controls != null and _touch_controls.visible
	_camera = camera
	_disconnect_player_events()
	_player = player
	_minimap_target = minimap_target
	_connect_player_events()
	if _legend_label != null:
		_legend_label.text = _compact_legend_text()
	if _camera != null:
		_original_camera_zoom = _camera.zoom


func start() -> void:
	_step_index = 0
	_active_elapsed = 0.0
	_movement_distance = 0.0
	_last_player_position = Vector2.ZERO
	_has_player_position = false
	_gate_released_emitted = false
	_completed_emitted = false
	_skipped_emitted = false
	_active = true
	visible = true
	set_process(true)
	_show_step_ui()
	if _skip_button != null:
		_skip_button.visible = false
	if _compact_legend != null:
		_compact_legend.visible = false
	_apply_camera_zoom()
	_refresh_step()


func finish() -> void:
	if not _active and not visible:
		return
	_active = false
	_hide_step_ui()
	if _compact_legend != null:
		_compact_legend.visible = false
	visible = false
	set_process(false)
	_restore_camera_zoom()


func is_active() -> bool:
	return _active


func _exit_tree() -> void:
	_disconnect_player_events()


func get_visual_contract() -> Dictionary:
	return {
		"flow": FLOW_ID,
		"input_mode": _input_mode(),
		"blocks_gameplay": false,
		"uses_dim_cutout": _uses_touch_guidance(),
		"dim_alpha": DIM_ALPHA,
		"spotlight_padding": SPOTLIGHT_PADDING,
		"camera_zoom_target": CAMERA_ZOOM_TARGET,
		"move_distance_required": MOVE_DISTANCE_REQUIRED,
		"skip_reveal_seconds": SKIP_REVEAL_SECONDS,
		"step_ids": _step_ids(),
		"step_target_names": _step_target_names(),
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
	}


func get_current_step_snapshot() -> Dictionary:
	var step := _current_step()
	var target_names := _current_target_names()
	return {
		"active": _active,
		"input_mode": _input_mode(),
		"step_id": step.get("id", &""),
		"title": String(step.get("title", "")),
		"body": String(step.get("body", "")),
		"target_names": target_names,
		"target_rect": _target_rect_for_names(target_names),
		"dim_alpha": DIM_ALPHA if _active else 0.0,
		"movement_distance": _movement_distance,
		"gate_released": _gate_released_emitted,
		"skip_visible": _skip_button != null and _skip_button.visible,
		"compact_legend_visible": _compact_legend != null and _compact_legend.visible,
	}


func get_skip_button_reference_rect() -> Rect2:
	if _skip_button == null:
		return Rect2()
	return Rect2(
		Vector2(
			VIEWPORT_FALLBACK.x * _skip_button.anchor_left + _skip_button.offset_left,
			VIEWPORT_FALLBACK.y * _skip_button.anchor_top + _skip_button.offset_top
		),
		Vector2(
			VIEWPORT_FALLBACK.x * (_skip_button.anchor_right - _skip_button.anchor_left) + _skip_button.offset_right - _skip_button.offset_left,
			VIEWPORT_FALLBACK.y * (_skip_button.anchor_bottom - _skip_button.anchor_top) + _skip_button.offset_bottom - _skip_button.offset_top
		)
	)


func advance_from_input(input_state: Dictionary) -> bool:
	if input_state.has("player_position"):
		return record_player_position(input_state.get("player_position", Vector2.ZERO) as Vector2)
	return false


func record_action(action: StringName, payload: Dictionary = {}) -> bool:
	if not _active:
		return false
	var step_id := StringName(_current_step().get("id", &""))
	var succeeds := (
		(step_id == &"attack" and action == &"attack_executed")
		or (step_id == &"dash" and action == &"dash_started")
		or (step_id == &"power_attack" and action == &"power_attack_executed")
		or (
			step_id == &"minimap"
			and action == &"minimap_expanded"
			and bool(payload.get("expanded", false))
		)
	)
	if not succeeds:
		return false
	_advance_step()
	return true


func record_player_position(position: Vector2) -> bool:
	if not _active or StringName(_current_step().get("id", &"")) != &"move":
		return false
	if not _has_player_position:
		_last_player_position = position
		_has_player_position = true
		return false
	_movement_distance += _last_player_position.distance_to(position)
	_last_player_position = position
	if _movement_distance < MOVE_DISTANCE_REQUIRED:
		return false
	_advance_step()
	return true


func record_room_changed(room_id: StringName, room_type: StringName) -> bool:
	if not _active or _completed_emitted:
		return false
	if StringName(_current_step().get("id", &"")) != &"exit":
		return false
	if room_id == ONBOARDING_START_ROOM_ID or room_type == &"start":
		return false
	_completed_emitted = true
	_active = false
	_hide_step_ui()
	visible = false
	set_process(false)
	_restore_camera_zoom()
	completed.emit()
	return true


func skip_guidance() -> void:
	if not _active or _skipped_emitted:
		return
	_skipped_emitted = true
	_release_gate()
	_active = false
	_hide_step_ui()
	if _compact_legend != null:
		_compact_legend.visible = true
	visible = true
	set_process(false)
	_restore_camera_zoom()
	skipped.emit()


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_time += maxf(0.0, delta)
	_active_elapsed += maxf(0.0, delta)
	if _skip_button != null:
		_skip_button.visible = _active_elapsed >= SKIP_REVEAL_SECONDS and not _gate_released_emitted
	var player_2d := _player as Node2D
	if player_2d != null:
		record_player_position(player_2d.global_position)
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
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_label_panel.add_child(box)
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
	UiFontRoles.apply_title(_title_label)
	box.add_child(_title_label)
	_body_label = Label.new()
	_body_label.name = "BodyLabel"
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	UiFontRoles.apply_pixel(_body_label)
	box.add_child(_body_label)
	_skip_button = Button.new()
	_skip_button.name = "SkipGuidanceButton"
	_skip_button.text = "안내 건너뛰기"
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.set_meta("test_id", "onboarding.skip_guidance_button")
	_skip_button.set_meta("uat_action", "onboarding.skip_guidance")
	_skip_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_button.offset_left = -SKIP_BUTTON_SIZE.x * 0.5
	_skip_button.offset_top = -SKIP_BUTTON_BOTTOM - SKIP_BUTTON_SIZE.y
	_skip_button.offset_right = SKIP_BUTTON_SIZE.x * 0.5
	_skip_button.offset_bottom = -SKIP_BUTTON_BOTTOM
	MobileSafeArea.apply_edge_offsets(_skip_button, -1.0, -1.0, -1.0, SKIP_BUTTON_BOTTOM)
	_skip_button.add_theme_font_size_override("font_size", 16)
	UiFontRoles.apply_pixel(_skip_button)
	PixelButtonStyle.apply(_skip_button, PixelButtonStyle.VARIANT_COMPACT, SKIP_BUTTON_SIZE)
	_skip_button.pressed.connect(skip_guidance)
	_skip_button.visible = false
	_root.add_child(_skip_button)
	_compact_legend = PanelContainer.new()
	_compact_legend.name = "CompactLegend"
	_compact_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compact_legend.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_compact_legend.offset_left = COMPACT_LEGEND_LEFT
	_compact_legend.offset_top = COMPACT_LEGEND_TOP
	_compact_legend.offset_right = COMPACT_LEGEND_LEFT + COMPACT_LEGEND_SIZE.x
	_compact_legend.offset_bottom = COMPACT_LEGEND_TOP + COMPACT_LEGEND_SIZE.y
	_compact_legend.add_theme_stylebox_override("panel", _hint_panel_style())
	_legend_label = Label.new()
	_legend_label.name = "LegendLabel"
	_legend_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend_label.add_theme_font_size_override("font_size", 14)
	_legend_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 0.96))
	UiFontRoles.apply_pixel(_legend_label)
	_legend_label.text = _compact_legend_text()
	_compact_legend.add_child(_legend_label)
	_compact_legend.visible = false
	_root.add_child(_compact_legend)


func _refresh_step() -> void:
	if not _active or _root == null:
		return
	var step := _current_step()
	_title_label.text = String(step.get("title", ""))
	_body_label.text = String(step.get("body", ""))
	_label_panel.visible = true
	var target_names := _current_target_names()
	if target_names.is_empty() or (not _uses_touch_guidance() and StringName(step.get("id", &"")) != &"minimap"):
		_layout_desktop_hint()
		return
	var focus_rect := _spotlight_rect_for_names(target_names)
	_spotlight_frame.visible = true
	_layout_dim_cutout(focus_rect)
	_layout_spotlight(focus_rect)
	_layout_label(focus_rect)


func _layout_desktop_hint() -> void:
	var viewport_size := _viewport_size()
	_spotlight_frame.visible = false
	for index in range(_dim_rects.size()):
		_dim_rects[index].visible = true
		var rect := Rect2(Vector2.ZERO, viewport_size) if index == 0 else Rect2()
		_apply_control_rect(_dim_rects[index], rect)
	var centered_position := (viewport_size - LABEL_SIZE) * 0.5
	_apply_control_rect(_label_panel, Rect2(centered_position, LABEL_SIZE))


func _layout_dim_cutout(focus_rect: Rect2) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, _viewport_size())
	var safe_focus := focus_rect.intersection(viewport_rect)
	var top_rect := Rect2(Vector2.ZERO, Vector2(viewport_rect.size.x, safe_focus.position.y))
	var bottom_rect := Rect2(Vector2(0.0, safe_focus.end.y), Vector2(viewport_rect.size.x, viewport_rect.size.y - safe_focus.end.y))
	var left_rect := Rect2(Vector2(0.0, safe_focus.position.y), Vector2(safe_focus.position.x, safe_focus.size.y))
	var right_rect := Rect2(Vector2(safe_focus.end.x, safe_focus.position.y), Vector2(viewport_rect.size.x - safe_focus.end.x, safe_focus.size.y))
	var rects := [top_rect, bottom_rect, left_rect, right_rect]
	for index in range(_dim_rects.size()):
		_dim_rects[index].visible = true
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
	for target_name: String in target_names:
		var control: Control = null
		if target_name == "Minimap":
			control = _minimap_target
		elif _touch_controls != null:
			control = _touch_controls.get_node_or_null(NodePath(target_name)) as Control
		if control == null or not control.visible:
			continue
		var control_rect := control.get_global_rect()
		if not found:
			rect = control_rect
			found = true
		else:
			rect = rect.merge(control_rect)
	return rect if found else Rect2()


func _advance_step() -> void:
	_step_index += 1
	if _step_index >= _steps().size():
		_step_index = _steps().size() - 1
		return
	var step_id: StringName = _current_step().get("id", &"")
	if step_id == &"exit":
		_release_gate()
		if _skip_button != null:
			_skip_button.visible = false
	_refresh_step()


func _release_gate() -> void:
	if _gate_released_emitted:
		return
	_gate_released_emitted = true
	gate_released.emit()


func _connect_player_events() -> void:
	_connect_player_event(&"attack_executed", Callable(self, "_on_player_attack_executed"))
	_connect_player_event(&"dash_started", Callable(self, "_on_player_dash_started"))
	_connect_player_event(&"power_attack_executed", Callable(self, "_on_player_power_attack_executed"))


func _disconnect_player_events() -> void:
	_disconnect_player_event(&"attack_executed", Callable(self, "_on_player_attack_executed"))
	_disconnect_player_event(&"dash_started", Callable(self, "_on_player_dash_started"))
	_disconnect_player_event(&"power_attack_executed", Callable(self, "_on_player_power_attack_executed"))


func _connect_player_event(signal_name: StringName, callback: Callable) -> void:
	if _player == null or not _player.has_signal(signal_name):
		return
	if not _player.is_connected(signal_name, callback):
		_player.connect(signal_name, callback)


func _disconnect_player_event(signal_name: StringName, callback: Callable) -> void:
	if _player == null or not _player.has_signal(signal_name):
		return
	if _player.is_connected(signal_name, callback):
		_player.disconnect(signal_name, callback)


func _on_player_attack_executed(payload: Dictionary = {}) -> void:
	record_action(&"attack_executed", payload)


func _on_player_dash_started(payload: Dictionary = {}) -> void:
	record_action(&"dash_started", payload)


func _on_player_power_attack_executed(payload: Dictionary = {}) -> void:
	record_action(&"power_attack_executed", payload)


func _show_step_ui() -> void:
	for dim_rect: ColorRect in _dim_rects:
		dim_rect.visible = true
	if _spotlight_frame != null:
		_spotlight_frame.visible = true
	if _label_panel != null:
		_label_panel.visible = true


func _hide_step_ui() -> void:
	for dim_rect: ColorRect in _dim_rects:
		dim_rect.visible = false
	if _spotlight_frame != null:
		_spotlight_frame.visible = false
	if _label_panel != null:
		_label_panel.visible = false
	if _skip_button != null:
		_skip_button.visible = false


func _compact_legend_text() -> String:
	if _uses_touch_guidance():
		return "조작표\n이동  왼쪽 스틱\n공격  공격 버튼\n대시  대시 버튼\n지도  오른쪽 위 탭"
	return "조작표\n이동  WASD\n공격  좌클릭\n대시  SPACE\n지도  오른쪽 위 클릭"


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
	var steps := _steps()
	if steps.is_empty():
		return {}
	return steps[clampi(_step_index, 0, steps.size() - 1)]


func _current_target_names() -> Array:
	return (_current_step().get("targets", []) as Array).duplicate()


func _step_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for step: Dictionary in _steps():
		ids.append(step.get("id", &""))
	return ids


func _step_target_names() -> Array:
	var target_names := []
	for step: Dictionary in _steps():
		target_names.append((step.get("targets", []) as Array).duplicate())
	return target_names


func _steps() -> Array[Dictionary]:
	return TOUCH_STEPS if _uses_touch_guidance() else DESKTOP_STEPS


func _uses_touch_guidance() -> bool:
	return _touch_guidance_enabled


func _input_mode() -> StringName:
	return &"touch" if _uses_touch_guidance() else &"desktop"


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
