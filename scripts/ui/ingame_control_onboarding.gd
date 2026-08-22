class_name IngameControlOnboarding
extends CanvasLayer

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const PixelButtonStyle = preload("res://scripts/ui/pixel_button_style.gd")
const OnboardingCoachMarkScript = preload("res://scripts/ui/onboarding_coach_mark.gd")
const OnboardingVisualTokens = preload("res://scripts/ui/onboarding_visual_tokens.gd")

signal completed
signal skipped
signal gate_released

const FLOW_ID := &"first_ingame_controls"
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
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

const TOUCH_STEPS: Array[Dictionary] = [
	{
		"id": &"move",
		"key_label": "스틱",
		"action": "이동",
		"detail": "96px",
		"targets": ["Joystick"],
	},
	{
		"id": &"attack",
		"key_label": "공격 버튼",
		"action": "공격",
		"detail": "가까운 적",
		"targets": ["AttackButton"],
	},
	{
		"id": &"dash",
		"key_label": "대시 버튼",
		"action": "회피",
		"detail": "짧게",
		"targets": ["SkillButton"],
	},
	{
		"id": &"power_attack",
		"key_label": "대시 → 공격",
		"action": "강공격",
		"detail": "연속 입력",
		"targets": ["SkillButton", "AttackButton"],
	},
	{
		"id": &"minimap",
		"key_label": "미니맵 탭",
		"action": "지도 펼치기",
		"detail": "오른쪽 위",
		"targets": ["Minimap"],
	},
	{
		"id": &"exit",
		"key_label": "",
		"action": "열린 문 통과",
		"detail": "",
		"targets": [],
	},
]

const DESKTOP_STEPS: Array[Dictionary] = [
	{
		"id": &"move",
		"key_label": "WASD",
		"action": "이동",
		"detail": "96px",
		"targets": [],
	},
	{
		"id": &"attack",
		"key_label": "LMB",
		"action": "공격",
		"detail": "가까운 적",
		"targets": [],
	},
	{
		"id": &"dash",
		"key_label": "SPACE",
		"action": "회피",
		"detail": "짧게",
		"targets": [],
	},
	{
		"id": &"power_attack",
		"key_label": "SPACE → LMB",
		"action": "강공격",
		"detail": "연속 입력",
		"targets": [],
	},
	{
		"id": &"minimap",
		"key_label": "미니맵 클릭",
		"action": "지도 펼치기",
		"detail": "오른쪽 위",
		"targets": ["Minimap"],
	},
	{
		"id": &"exit",
		"key_label": "",
		"action": "열린 문 통과",
		"detail": "",
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
var _root: Control = null
var _coach_mark: OnboardingCoachMark = null
var _pending_visual_refresh := false
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
	if _coach_mark != null:
		_coach_mark.configure(_camera, _is_reduced_motion())
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
	_pending_visual_refresh = false
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
		"uses_dim_cutout": false,
		"uses_fullscreen_dim": false,
		"dim_alpha": 0.0,
		"bracket_style": &"corners",
		"screen_coverage_hard_cap": 0.25,
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
	var coach_snapshot := _coach_mark.get_snapshot() if _coach_mark != null else {}
	return {
		"active": _active,
		"input_mode": _input_mode(),
		"step_id": step.get("id", &""),
		"title": String(step.get("action", "")),
		"body": String(step.get("detail", "")),
		"key_label": String(step.get("key_label", "")),
		"action": String(step.get("action", "")),
		"detail": String(step.get("detail", "")),
		"target_names": target_names,
		"target_rect": _target_rect_for_names(target_names),
		"coach_rect": coach_snapshot.get("label_rect", Rect2()),
		"screen_coverage": coach_snapshot.get("screen_coverage", 0.0),
		"bracket_style": coach_snapshot.get("bracket_style", &"corners"),
		"reduced_motion": coach_snapshot.get("reduced_motion", _is_reduced_motion()),
		"dim_alpha": 0.0,
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
	_active_elapsed += maxf(0.0, delta)
	if _skip_button != null:
		_skip_button.visible = _active_elapsed >= SKIP_REVEAL_SECONDS and not _gate_released_emitted
	var player_2d := _player as Node2D
	if player_2d != null:
		record_player_position(player_2d.global_position)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_coach_mark = OnboardingCoachMarkScript.new() as OnboardingCoachMark
	_coach_mark.name = "CoachMark"
	add_child(_coach_mark)
	_coach_mark.exit_finished.connect(_on_coach_exit_finished)
	_coach_mark.configure(_camera, _is_reduced_motion())
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
	_compact_legend.add_theme_stylebox_override("panel", OnboardingVisualTokens.coach_style(&"info"))
	_legend_label = Label.new()
	_legend_label.name = "LegendLabel"
	_legend_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend_label.add_theme_font_size_override("font_size", 14)
	_legend_label.add_theme_color_override("font_color", OnboardingVisualTokens.PAPER_TEXT)
	UiFontRoles.apply_pixel(_legend_label)
	_legend_label.text = _compact_legend_text()
	_compact_legend.add_child(_legend_label)
	_compact_legend.visible = false
	_root.add_child(_compact_legend)


func _refresh_step() -> void:
	if not _active or _coach_mark == null:
		return
	var step := _current_step()
	var target_names := _current_target_names()
	var target_kind: StringName = &"none"
	var target: Node = null
	var targets: Array[Control] = []
	var placement: StringName = &"auto"
	if target_names.size() == 1:
		target = _target_control_for_name(String(target_names[0]))
		target_kind = &"control" if target != null else &"none"
	elif target_names.size() > 1:
		for target_name: Variant in target_names:
			var control := _target_control_for_name(String(target_name))
			if control != null:
				targets.append(control)
	if target_names.is_empty() and StringName(step.get("id", &"")) != &"exit" and _player is Node2D:
		target = _player
		target_kind = &"world"
	if StringName(step.get("id", &"")) == &"exit":
		placement = &"ribbon"
	_coach_mark.configure(_camera, _is_reduced_motion())
	_coach_mark.show_prompt({
		"id": step.get("id", &""),
		"tone": &"info",
		"key_label": String(step.get("key_label", "")),
		"action": String(step.get("action", "")),
		"detail": String(step.get("detail", "")),
		"target_kind": target_kind,
		"target": target,
		"targets": targets,
		"placement": placement,
		"persistent": true,
	})


func _target_rect_for_names(target_names: Array) -> Rect2:
	var rect := Rect2()
	var found := false
	for target_name: String in target_names:
		var control := _target_control_for_name(target_name)
		if control == null:
			continue
		var control_rect := control.get_global_rect()
		if not found:
			rect = control_rect
			found = true
		else:
			rect = rect.merge(control_rect)
	return rect if found else Rect2()


func _target_control_for_name(target_name: String) -> Control:
	if target_name == "Minimap":
		return _minimap_target
	if _touch_controls == null:
		return null
	return _touch_controls.get_node_or_null(NodePath(target_name)) as Control


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
	_pending_visual_refresh = true
	if _coach_mark != null and _coach_mark.is_active():
		_coach_mark.configure(_camera, _is_reduced_motion())
		_coach_mark.complete()
	else:
		_pending_visual_refresh = false
		_refresh_step()


func _on_coach_exit_finished(_prompt_id: StringName, kind: StringName) -> void:
	if kind != &"complete" or not _pending_visual_refresh:
		return
	_pending_visual_refresh = false
	if _active:
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
	pass


func _hide_step_ui() -> void:
	_pending_visual_refresh = false
	if _coach_mark != null:
		_coach_mark.dismiss(true)
	if _skip_button != null:
		_skip_button.visible = false


func _compact_legend_text() -> String:
	if _uses_touch_guidance():
		return "조작표\n스틱  이동\n공격 버튼  공격\n대시 버튼  회피\n미니맵 탭  지도"
	return "조작표\nWASD  이동\nLMB  공격\nSPACE  회피\n미니맵 클릭  지도"


func _apply_camera_zoom() -> void:
	if _camera == null:
		return
	if not _camera_zoom_active:
		_original_camera_zoom = _camera.zoom
	_camera_zoom_active = true
	_camera.zoom = _original_camera_zoom * lerpf(1.0, CAMERA_ZOOM_TARGET, 0.45)
	_kill_camera_tween()
	if _is_reduced_motion():
		_camera.zoom = _original_camera_zoom * CAMERA_ZOOM_TARGET
		return
	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera, ^"zoom", _original_camera_zoom * CAMERA_ZOOM_TARGET, CAMERA_ZOOM_SECONDS)


func _restore_camera_zoom() -> void:
	if _camera == null or not _camera_zoom_active:
		return
	_camera_zoom_active = false
	_kill_camera_tween()
	if _is_reduced_motion():
		_camera.zoom = _original_camera_zoom
		return
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


func _is_reduced_motion() -> bool:
	if not is_inside_tree():
		return false
	return has_node("/root/Settings") and Settings.is_reduced_motion_enabled()
