extends Control

const MINIMAP_SCENE = preload("res://scenes/ui/minimap.tscn")
const AUTHORED_LAYOUT_PATH := "res://resources/layouts/gyeongbokgung.tres"

@export var use_generated_layout := true
@export var layout_seed := 40
@export var auto_run := true
@export var quit_on_complete := false

var _minimap: Minimap
var _status_label: Label
var _generated_toggle: CheckButton
var _seed_spin: SpinBox
var _reveal_toggle: CheckBox
var _layout: RoomLayout


func _ready() -> void:
	_build_ui()
	_load_layout()
	if auto_run:
		call_deferred("_run_runtime_check")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12.0
	root.offset_top = 12.0
	root.offset_right = -12.0
	root.offset_bottom = -12.0
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	toolbar.add_theme_constant_override("separation", 8)
	root.add_child(toolbar)

	_generated_toggle = CheckButton.new()
	_generated_toggle.text = "Generated"
	_generated_toggle.button_pressed = use_generated_layout
	_generated_toggle.toggled.connect(_on_generated_toggled)
	toolbar.add_child(_generated_toggle)

	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0.0
	_seed_spin.max_value = 999999.0
	_seed_spin.step = 1.0
	_seed_spin.value = layout_seed
	_seed_spin.custom_minimum_size = Vector2(96.0, 0.0)
	_seed_spin.value_changed.connect(_on_seed_changed)
	toolbar.add_child(_seed_spin)

	var regenerate_button := Button.new()
	regenerate_button.text = "Regenerate"
	regenerate_button.pressed.connect(_load_layout)
	toolbar.add_child(regenerate_button)

	_reveal_toggle = CheckBox.new()
	_reveal_toggle.text = "Reveal boss"
	_reveal_toggle.toggled.connect(_on_reveal_toggled)
	toolbar.add_child(_reveal_toggle)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_status_label)

	_minimap = MINIMAP_SCENE.instantiate() as Minimap
	_minimap.name = "Minimap"
	_minimap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_minimap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_minimap.custom_minimum_size = Vector2(360.0, 680.0)
	root.add_child(_minimap)


func _load_layout() -> void:
	if use_generated_layout:
		var generator := RoomLayoutGenerator.new()
		_layout = generator.generate(layout_seed)
	else:
		_layout = load(AUTHORED_LAYOUT_PATH) as RoomLayout

	var final_room := _final_room(_layout)
	var cleared := {}
	if _reveal_toggle != null and _reveal_toggle.button_pressed:
		for room_def: RoomDef in _layout.room_defs:
			if room_def != null and not room_def.hidden:
				cleared[room_def.room_id] = true

	var path := _path_between(_layout, _layout.start_room_id, final_room.room_id if final_room != null else &"")
	var unreachable := _unreachable_room_ids(_layout)
	_minimap.set_layout(_layout, _layout.start_room_id, cleared)
	_minimap.set_reveal_hidden_rooms(_reveal_toggle != null and _reveal_toggle.button_pressed)
	_minimap.set_path_room_ids(path)
	_minimap.set_problem_room_ids(unreachable)

	var layout_kind := "generated" if use_generated_layout else "authored"
	var status := "%s seed=%d rooms=%d unreachable=%d path=%d" % [
		layout_kind,
		layout_seed,
		_layout.room_defs.size(),
		unreachable.size(),
		path.size(),
	]
	_status_label.text = status
	print("[map_inspector] %s" % status)


func _run_runtime_check() -> void:
	await get_tree().process_frame
	var authored := load(AUTHORED_LAYOUT_PATH) as RoomLayout
	if not _assert_layout_inspectable(authored, "authored"):
		return
	for next_seed: int in [layout_seed, layout_seed + 1, layout_seed + 2]:
		var generator := RoomLayoutGenerator.new()
		if not _assert_layout_inspectable(generator.generate(next_seed), "generated_%d" % next_seed):
			return
	print("[map_inspector] OK: authored and generated layouts inspectable")
	if quit_on_complete or DisplayServer.get_name() == "headless":
		get_tree().quit(0)


func _assert_layout_inspectable(next_layout: RoomLayout, label: String) -> bool:
	if next_layout == null:
		_fail_inspector("%s layout missing" % label)
		return false
	var unreachable := _unreachable_room_ids(next_layout)
	if not unreachable.is_empty():
		_fail_inspector("%s layout has unreachable rooms: %s" % [label, str(unreachable.keys())])
		return false
	var final_room := _final_room(next_layout)
	if final_room == null:
		_fail_inspector("%s layout has no final room" % label)
		return false
	var path := _path_between(next_layout, next_layout.start_room_id, final_room.room_id)
	if path.is_empty() or path[path.size() - 1] != final_room.room_id:
		_fail_inspector("%s layout has no start-to-final path" % label)
		return false
	print("[map_inspector] %s rooms=%d path=%d" % [label, next_layout.room_defs.size(), path.size()])
	return true


func _fail_inspector(message: String) -> void:
	push_error("[map_inspector] FAIL: %s" % message)
	if quit_on_complete or DisplayServer.get_name() == "headless":
		get_tree().quit(1)


func _on_generated_toggled(pressed: bool) -> void:
	use_generated_layout = pressed
	_load_layout()


func _on_seed_changed(value: float) -> void:
	layout_seed = int(value)
	if use_generated_layout:
		_load_layout()


func _on_reveal_toggled(_pressed: bool) -> void:
	_load_layout()


func _final_room(next_layout: RoomLayout) -> RoomDef:
	if next_layout == null:
		return null
	for room_def: RoomDef in next_layout.room_defs:
		if room_def != null and room_def.room_type == RoomLayout.TYPE_FINAL:
			return room_def
	return null


func _unreachable_room_ids(next_layout: RoomLayout) -> Dictionary:
	var unreachable := {}
	if next_layout == null:
		return unreachable
	var reached := _reachable_room_ids(next_layout, next_layout.start_room_id)
	for room_def: RoomDef in next_layout.room_defs:
		if room_def != null and not reached.has(room_def.room_id):
			unreachable[room_def.room_id] = true
	return unreachable


func _reachable_room_ids(next_layout: RoomLayout, start_room_id: StringName) -> Dictionary:
	var reached := {start_room_id: true}
	var queue: Array[StringName] = [start_room_id]
	var cursor := 0
	while cursor < queue.size():
		var room_id := queue[cursor]
		cursor += 1
		var room_def := next_layout.get_room(room_id)
		if room_def == null:
			continue
		for connected_room_id: StringName in room_def.connections:
			if reached.has(connected_room_id):
				continue
			reached[connected_room_id] = true
			queue.append(connected_room_id)
	return reached


func _path_between(next_layout: RoomLayout, start_room_id: StringName, target_room_id: StringName) -> Array[StringName]:
	if next_layout == null or target_room_id == &"":
		return []
	var queue: Array[StringName] = [start_room_id]
	var parent := {start_room_id: &""}
	var cursor := 0
	while cursor < queue.size():
		var room_id := queue[cursor]
		cursor += 1
		if room_id == target_room_id:
			break
		var room_def := next_layout.get_room(room_id)
		if room_def == null:
			continue
		for connected_room_id: StringName in room_def.connections:
			if parent.has(connected_room_id):
				continue
			parent[connected_room_id] = room_id
			queue.append(connected_room_id)

	if not parent.has(target_room_id):
		return []
	var path: Array[StringName] = []
	var current := target_room_id
	while current != &"":
		path.push_front(current)
		current = parent.get(current, &"")
	return path
