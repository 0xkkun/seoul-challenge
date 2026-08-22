class_name OnboardingCoachMark
extends CanvasLayer

signal exit_finished(prompt_id: StringName, kind: StringName)

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const Tokens = preload("res://scripts/ui/onboarding_visual_tokens.gd")

const DEFAULT_TARGET_SIZE := Vector2(96.0, 112.0)
const DEFAULT_TARGET_OFFSET := Vector2(0.0, -34.0)
const TARGET_GAP := 12.0
const BRACKET_GROW := 10.0
const VIEWPORT_FALLBACK := MobileSafeArea.DESIGN_VIEWPORT

var _camera: Camera2D = null
var _reduced_motion := false
var _model := {}
var _active := false
var _generation := 0
var _motion_tween: Tween = null
var _pending_exit_generations := {}
var _pending_exit_kinds := {}
var _last_enter_duration := 0.0
var _root: Control = null
var _panel: PanelContainer = null
var _key_panel: PanelContainer = null
var _key_label: Label = null
var _action_label: Label = null
var _detail_label: Label = null
var _bracket_parts: Array[ColorRect] = []


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	set_process(false)


func configure(camera: Camera2D, reduced_motion: bool = false) -> void:
	_camera = camera
	_reduced_motion = reduced_motion


func show_prompt(model: Dictionary) -> void:
	_generation += 1
	_kill_motion()
	_model = model.duplicate(true)
	_active = true
	visible = true
	set_process(true)
	_refresh_content()
	_refresh_layout()
	_play_enter()


func complete() -> void:
	if not _active:
		return
	_play_exit(&"complete")


func dismiss(immediate: bool = false) -> void:
	if not _active:
		return
	if immediate:
		_register_pending_exit(&"dismiss")
		_finish_exit(_generation)
		return
	_play_exit(&"dismiss")


func is_active() -> bool:
	return _active


func get_snapshot() -> Dictionary:
	var label_rect := _panel.get_global_rect() if _panel != null else Rect2()
	var bracket_rects: Array[Rect2] = []
	for part: ColorRect in _bracket_parts:
		if part.visible:
			bracket_rects.append(part.get_global_rect())
	var coverage_rects: Array[Rect2] = [label_rect]
	coverage_rects.append_array(bracket_rects)
	var target := _model.get("target") as Node
	return {
		"active": _active,
		"id": StringName(_model.get("id", &"")),
		"tone": StringName(_model.get("tone", &"info")),
		"tone_color": Tokens.tone_color(StringName(_model.get("tone", &"info"))),
		"action": String(_model.get("action", "")),
		"key_label": String(_model.get("key_label", "")),
		"detail": String(_model.get("detail", "")),
		"target_name": target.name if target != null and is_instance_valid(target) else "",
		"target_rect": _target_rect(),
		"label_rect": label_rect,
		"bracket_style": &"corners",
		"screen_coverage": Tokens.screen_coverage(coverage_rects, _viewport_size()),
		"mouse_filter": _root.mouse_filter if _root != null else Control.MOUSE_FILTER_IGNORE,
		"reduced_motion": _reduced_motion,
		"enter_duration": _last_enter_duration,
		"generation": _generation,
	}


func get_visual_contract() -> Dictionary:
	return {
		"max_label_size": Tokens.MAX_LABEL_SIZE,
		"max_ribbon_size": Tokens.MAX_RIBBON_SIZE,
		"bracket_style": &"corners",
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
		"screen_coverage_hard_cap": 0.25,
	}


func finish_motion_for_tests(prompt_id: StringName) -> void:
	if not _pending_exit_generations.has(prompt_id):
		return
	var generation := int(_pending_exit_generations[prompt_id])
	_finish_exit(generation)


func _process(_delta: float) -> void:
	if not _active:
		return
	var target := _model.get("target") as Node
	if target != null and (not is_instance_valid(target) or target.is_queued_for_deletion()):
		dismiss(true)
		return
	_refresh_layout()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	for index: int in range(8):
		var part := ColorRect.new()
		part.name = "BracketPart%d" % index
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		part.visible = false
		_root.add_child(part)
		_bracket_parts.append(part)

	_panel = PanelContainer.new()
	_panel.name = "CoachPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	var stack := VBoxContainer.new()
	stack.name = "CoachStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 2)
	_panel.add_child(stack)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	stack.add_child(action_row)
	_key_panel = PanelContainer.new()
	_key_panel.name = "KeyChip"
	_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_panel.custom_minimum_size.y = Tokens.KEY_CHIP_HEIGHT
	action_row.add_child(_key_panel)
	_key_label = Label.new()
	_key_label.name = "KeyLabel"
	_key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_label.add_theme_font_size_override("font_size", 16)
	UiFontRoles.apply_pixel(_key_label)
	_key_panel.add_child(_key_label)
	_action_label = Label.new()
	_action_label.name = "ActionLabel"
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 22)
	UiFontRoles.apply_title(_action_label)
	action_row.add_child(_action_label)
	_detail_label = Label.new()
	_detail_label.name = "DetailLabel"
	_detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Tokens.PAPER_TEXT)
	UiFontRoles.apply_pixel(_detail_label)
	stack.add_child(_detail_label)


func _refresh_content() -> void:
	var tone := StringName(_model.get("tone", &"info"))
	var tone_color := Tokens.tone_color(tone)
	_panel.add_theme_stylebox_override("panel", Tokens.coach_style(tone))
	_key_panel.add_theme_stylebox_override("panel", Tokens.key_chip_style(tone))
	_key_label.text = String(_model.get("key_label", ""))
	_key_label.add_theme_color_override("font_color", tone_color)
	_key_panel.visible = not _key_label.text.is_empty()
	_action_label.text = String(_model.get("action", ""))
	_action_label.add_theme_color_override("font_color", tone_color)
	_detail_label.text = String(_model.get("detail", ""))
	_detail_label.visible = not _detail_label.text.is_empty()
	for part: ColorRect in _bracket_parts:
		part.color = tone_color


func _refresh_layout() -> void:
	if _panel == null:
		return
	var viewport_size := _viewport_size()
	var panel_size := _desired_panel_size()
	var target_rect := _target_rect()
	var desired := Vector2((viewport_size.x - panel_size.x) * 0.5, MobileSafeArea.MIN_TOP)
	var placement := StringName(_model.get("placement", &"auto"))
	if target_rect.size != Vector2.ZERO and placement != &"ribbon":
		desired = Vector2(target_rect.get_center().x - panel_size.x * 0.5, target_rect.position.y - panel_size.y - TARGET_GAP)
		if desired.y < MobileSafeArea.MIN_TOP:
			desired.y = target_rect.end.y + TARGET_GAP
	desired.x = clampf(desired.x, MobileSafeArea.MIN_LEFT, viewport_size.x - MobileSafeArea.MIN_RIGHT - panel_size.x)
	desired.y = clampf(desired.y, MobileSafeArea.MIN_TOP, viewport_size.y - MobileSafeArea.MIN_BOTTOM - panel_size.y)
	_apply_rect(_panel, Rect2(desired, panel_size))
	_layout_brackets(target_rect)


func _desired_panel_size() -> Vector2:
	if StringName(_model.get("placement", &"auto")) == &"ribbon":
		return Tokens.MAX_RIBBON_SIZE
	var height := Tokens.MAX_LABEL_SIZE.y if not String(_model.get("detail", "")).is_empty() else 54.0
	return Vector2(Tokens.MAX_LABEL_SIZE.x, height)


func _target_rect() -> Rect2:
	var raw_targets: Variant = _model.get("targets", [])
	if raw_targets is Array:
		var merged := Rect2()
		var found := false
		for value: Variant in raw_targets as Array:
			var control := value as Control
			if control == null or not is_instance_valid(control):
				continue
			if not found:
				merged = control.get_global_rect()
				found = true
			else:
				merged = merged.merge(control.get_global_rect())
		if found:
			return merged
	var rect_override: Variant = _model.get("target_rect")
	if rect_override is Rect2 and (rect_override as Rect2).size != Vector2.ZERO:
		return rect_override as Rect2
	var target := _model.get("target") as Node
	if target == null or not is_instance_valid(target):
		return Rect2()
	var target_kind := StringName(_model.get("target_kind", &"none"))
	if target_kind == &"control" and target is Control:
		return (target as Control).get_global_rect()
	if target_kind != &"world" or not target is Node2D:
		return Rect2()
	var world_target := target as Node2D
	var world_size := _model.get("target_size", DEFAULT_TARGET_SIZE) as Vector2
	var world_offset := _model.get("target_offset", DEFAULT_TARGET_OFFSET) as Vector2
	var zoom := _camera.zoom if _camera != null else Vector2.ONE
	var center := _world_to_screen(world_target.global_position + world_offset)
	return Rect2(center - world_size * zoom * 0.5, world_size * zoom)


func _world_to_screen(world_position: Vector2) -> Vector2:
	var viewport_size := _viewport_size()
	if _camera == null:
		return viewport_size * 0.5
	return viewport_size * 0.5 + (world_position - _camera.get_screen_center_position()) * _camera.zoom


func _layout_brackets(target_rect: Rect2) -> void:
	var show_brackets := target_rect.size != Vector2.ZERO
	for part: ColorRect in _bracket_parts:
		part.visible = show_brackets
	if not show_brackets:
		return
	var rect := target_rect.grow(BRACKET_GROW)
	var length := Tokens.TARGET_BRACKET_LENGTH
	var width := Tokens.TARGET_BRACKET_WIDTH
	var rects: Array[Rect2] = [
		Rect2(rect.position, Vector2(length, width)),
		Rect2(rect.position, Vector2(width, length)),
		Rect2(Vector2(rect.end.x - length, rect.position.y), Vector2(length, width)),
		Rect2(Vector2(rect.end.x - width, rect.position.y), Vector2(width, length)),
		Rect2(Vector2(rect.position.x, rect.end.y - width), Vector2(length, width)),
		Rect2(Vector2(rect.position.x, rect.end.y - length), Vector2(width, length)),
		Rect2(Vector2(rect.end.x - length, rect.end.y - width), Vector2(length, width)),
		Rect2(Vector2(rect.end.x - width, rect.end.y - length), Vector2(width, length)),
	]
	for index: int in range(_bracket_parts.size()):
		_apply_rect(_bracket_parts[index], rects[index])


func _play_enter() -> void:
	_last_enter_duration = Tokens.motion_duration(&"enter", _reduced_motion)
	_panel.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	for part: ColorRect in _bracket_parts:
		part.modulate = Color.WHITE
	if _last_enter_duration <= 0.0 or not is_inside_tree():
		return
	_panel.pivot_offset = _panel.size * 0.5
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.94, 0.94)
	for part: ColorRect in _bracket_parts:
		part.modulate.a = 0.0
	_motion_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_motion_tween.tween_property(_panel, ^"modulate:a", 1.0, _last_enter_duration)
	_motion_tween.tween_property(_panel, ^"scale", Vector2.ONE, _last_enter_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for part: ColorRect in _bracket_parts:
		_motion_tween.tween_property(part, ^"modulate:a", 1.0, Tokens.motion_duration(&"bracket", false))


func _play_exit(kind: StringName) -> void:
	_kill_motion()
	var generation := _generation
	_register_pending_exit(kind)
	var duration := Tokens.motion_duration(kind, _reduced_motion)
	if duration <= 0.0 or not is_inside_tree():
		_finish_exit(generation)
		return
	_motion_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_motion_tween.tween_property(_panel, ^"modulate:a", 0.0, duration)
	if kind == &"complete":
		_motion_tween.tween_property(_panel, ^"scale", Vector2(0.88, 0.88), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_motion_tween.chain().tween_callback(_finish_exit.bind(generation))


func _finish_exit(generation: int) -> void:
	var prompt_id := _prompt_id_for_generation(generation)
	var kind := StringName(_pending_exit_kinds.get(prompt_id, &"dismiss"))
	if generation != _generation:
		_clear_pending_exit(prompt_id)
		return
	_kill_motion()
	_active = false
	visible = false
	set_process(false)
	_panel.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	_clear_pending_exit(prompt_id)
	exit_finished.emit(prompt_id, kind)


func _register_pending_exit(kind: StringName) -> void:
	var prompt_id := StringName(_model.get("id", &""))
	_pending_exit_generations[prompt_id] = _generation
	_pending_exit_kinds[prompt_id] = kind


func _prompt_id_for_generation(generation: int) -> StringName:
	for prompt_id: Variant in _pending_exit_generations.keys():
		if int(_pending_exit_generations[prompt_id]) == generation:
			return StringName(prompt_id)
	return StringName(_model.get("id", &""))


func _clear_pending_exit(prompt_id: StringName) -> void:
	_pending_exit_generations.erase(prompt_id)
	_pending_exit_kinds.erase(prompt_id)


func _kill_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return VIEWPORT_FALLBACK
	var size := viewport.get_visible_rect().size
	return size if size.x > 0.0 and size.y > 0.0 else VIEWPORT_FALLBACK


func _apply_rect(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size


func _exit_tree() -> void:
	_kill_motion()
