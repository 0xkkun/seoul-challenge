class_name RoomManager
extends Node

signal room_changed(room_id: StringName, room_type: StringName)
signal layout_completed(layout_id: StringName)

@export var layout: RoomLayout
@export var layout_generator: Resource
@export var room_container_path: NodePath
@export var actor_path: NodePath

var current_room_id: StringName = &""
var current_room_def: RoomDef = null
var current_room: Node2D = null
var cleared_room_ids := {}
var last_entry_door_dir: StringName = &""
var transition_blocked_callable: Callable

var _room_container: Node = null
var _actor: Node2D = null


func _ready() -> void:
	_room_container = _resolve_room_container()
	_actor = _resolve_actor()
	if layout != null and current_room == null:
		start_layout()


func configure(next_layout: RoomLayout, room_container: Node = null, actor: Node2D = null) -> void:
	layout = next_layout
	if room_container != null:
		_room_container = room_container
	if actor != null:
		_actor = actor


func start_layout(next_layout: RoomLayout = null) -> bool:
	if next_layout != null:
		layout = next_layout
	var active_layout := _resolve_layout()
	if active_layout == null:
		push_warning("RoomManager needs a RoomLayout before start")
		return false
	layout = active_layout

	var errors := layout.validate_layout()
	if not errors.is_empty():
		push_error("RoomLayout is invalid: %s" % ", ".join(errors))
		return false

	cleared_room_ids.clear()
	_clear_current_room()
	return enter_room(layout.start_room_id)


func start_layout_from_path(layout_path: String) -> bool:
	var loaded_layout := load(layout_path) as RoomLayout
	if loaded_layout == null:
		push_error("Could not load RoomLayout: %s" % layout_path)
		return false
	return start_layout(loaded_layout)


func enter_room(room_id: StringName, entry_door_dir: StringName = &"") -> bool:
	if layout == null:
		return false

	var room_def := layout.get_room(room_id)
	if room_def == null:
		push_error("Missing room definition: %s" % room_id)
		return false

	var packed := load(room_def.scene_path) as PackedScene
	if packed == null:
		push_error("Could not load room scene: %s" % room_def.scene_path)
		return false

	var instance := packed.instantiate()
	if not instance is Node2D:
		instance.queue_free()
		push_error("Room scene root must be Node2D: %s" % room_def.scene_path)
		return false

	var container := _get_room_container()
	_clear_current_room()
	current_room = instance as Node2D
	current_room_def = room_def
	current_room_id = room_def.room_id
	last_entry_door_dir = entry_door_dir
	# 문 방향을 레이아웃 연결(grid 인접)에서 도출해 미니맵 배치와 항상 일치시킨다.
	current_room.set("door_dirs", _door_dirs_for_room(room_def))
	container.add_child(current_room)
	_apply_room_def(current_room, room_def)
	_configure_actor(current_room)
	_connect_room(current_room)
	_restore_cleared_room_state(current_room, room_def.room_id)

	room_changed.emit(room_def.room_id, room_def.room_type)
	if current_room.has_method("enter"):
		current_room.call("enter")
	elif has_node("/root/EventBus") and EventBus.has_method("emit_room_entered"):
		EventBus.emit_room_entered(room_def.to_payload())
	return true


func request_next_room(preferred_room_id: StringName = &"") -> bool:
	if layout == null or current_room == null:
		return false
	if not is_current_room_cleared():
		return false
	if _is_transition_blocked(preferred_room_id):
		return false

	var next_room_id := layout.get_next_room_id(current_room_id, cleared_room_ids, preferred_room_id)
	if next_room_id == &"":
		layout_completed.emit(layout.layout_id)
		return false
	var next_room_def := layout.get_room(next_room_id)
	return enter_room(next_room_id, _entry_door_dir_for_transition(current_room_def, next_room_def))


func is_current_room_cleared() -> bool:
	if current_room_id == &"":
		return false
	return bool(cleared_room_ids.get(current_room_id, false))


func has_cleared_room(room_id: StringName) -> bool:
	return bool(cleared_room_ids.get(room_id, false))


func get_visible_room_defs() -> Array[RoomDef]:
	if layout == null:
		return []
	return layout.get_visible_room_defs(cleared_room_ids)


func _get_room_container() -> Node:
	if _room_container == null:
		_room_container = _resolve_room_container()
	return _room_container


func _resolve_room_container() -> Node:
	if not room_container_path.is_empty():
		var configured := get_node_or_null(room_container_path)
		if configured != null:
			return configured
	return self


func _resolve_actor() -> Node2D:
	if not actor_path.is_empty():
		return get_node_or_null(actor_path) as Node2D
	return null


func _resolve_layout() -> RoomLayout:
	if layout != null:
		return layout
	if layout_generator != null and layout_generator.has_method("build_layout"):
		return layout_generator.call("build_layout") as RoomLayout
	return null


func _apply_room_def(room: Node2D, room_def: RoomDef) -> void:
	room.set("room_id", room_def.room_id)
	room.set("room_type", room_def.room_type)
	if room.has_method("apply_room_config"):
		room.call("apply_room_config", room_def.room_config.duplicate(true))


## 연결된 방의 grid 위치 차이로 문 방향(N/S/E/W)을 도출한다.
## validate_layout이 연결=인접(거리 1)을 강제하므로 델타는 항상 단위 방향이다.
## 결과적으로 문은 미니맵의 연결 엣지와 정확히 일치한다(상하 연결이면 N/S 문이 생김).
func _door_dirs_for_room(room_def: RoomDef) -> Array[StringName]:
	var dirs: Array[StringName] = []
	if layout == null:
		return dirs
	for connected_id: StringName in room_def.connections:
		var connected := layout.get_room(connected_id)
		if connected == null:
			continue
		var delta := connected.grid_pos - room_def.grid_pos
		var door_dir := _door_dir_for_delta(delta)
		if door_dir != &"":
			dirs.append(door_dir)
	return dirs


func _connected_room_id_for_door_dir(room_def: RoomDef, door_dir: StringName) -> StringName:
	if layout == null:
		return &""
	for connected_id: StringName in room_def.connections:
		var connected := layout.get_room(connected_id)
		if connected == null:
			continue
		if _door_dir_for_delta(connected.grid_pos - room_def.grid_pos) == door_dir:
			return connected_id
	return &""


func _door_dir_for_delta(delta: Vector2i) -> StringName:
	if delta.x > 0:
		return &"E"
	if delta.x < 0:
		return &"W"
	if delta.y > 0:
		return &"S"
	if delta.y < 0:
		return &"N"
	return &""


func _entry_door_dir_for_transition(from_room_def: RoomDef, to_room_def: RoomDef) -> StringName:
	if from_room_def == null or to_room_def == null:
		return &""
	return _door_dir_for_delta(from_room_def.grid_pos - to_room_def.grid_pos)


func _configure_actor(room: Node2D) -> void:
	if _actor != null and room.has_method("configure_actor"):
		room.call("configure_actor", _actor)


func _connect_room(room: Node2D) -> void:
	if room.has_signal("cleared") and not room.is_connected("cleared", _on_room_cleared):
		room.connect("cleared", _on_room_cleared)
	if room.has_signal("transition_requested") and not room.is_connected("transition_requested", _on_room_transition_requested):
		room.connect("transition_requested", _on_room_transition_requested)


func _restore_cleared_room_state(room: Node2D, room_id: StringName) -> void:
	if not has_cleared_room(room_id):
		return
	if room.has_method("restore_cleared_state"):
		room.call("restore_cleared_state")


func _clear_current_room() -> void:
	if current_room != null:
		current_room.queue_free()
	current_room = null
	current_room_def = null
	current_room_id = &""


func _on_room_cleared(room_id: StringName) -> void:
	cleared_room_ids[room_id] = true


func _on_room_transition_requested(room_id: StringName, door_dir: StringName) -> void:
	if room_id != current_room_id:
		return
	var preferred_room_id := _connected_room_id_for_door_dir(current_room_def, door_dir)
	request_next_room(preferred_room_id)


func _is_transition_blocked(preferred_room_id: StringName) -> bool:
	if not transition_blocked_callable.is_valid():
		return false
	return bool(transition_blocked_callable.call(current_room_id, preferred_room_id))
