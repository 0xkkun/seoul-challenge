class_name RunController
extends Node

signal run_started(payload: Dictionary)
signal run_completed(result: Dictionary)
signal room_changed(room_id: StringName, room_type: StringName)

@export var layout: RoomLayout
@export var room_container_path: NodePath
@export var actor_path: NodePath
@export var auto_start := false
@export var emit_session_finished_event := true

var room_manager: RoomManager
var visited_room_ids: Array[StringName] = []

var _room_container: Node
var _actor: Node2D
var _running := false
var _completed := false


func _ready() -> void:
	_room_container = _resolve_room_container()
	_actor = _resolve_actor()
	if auto_start:
		start_run()


func configure(next_layout: RoomLayout, room_container: Node = null, actor: Node2D = null) -> void:
	layout = next_layout
	if room_container != null:
		_room_container = room_container
	if actor != null:
		_actor = actor


func start_run(next_layout: RoomLayout = null) -> bool:
	if next_layout != null:
		layout = next_layout
	if layout == null:
		push_warning("RunController needs a RoomLayout before start")
		return false

	_ensure_room_manager()
	visited_room_ids.clear()
	_completed = false
	_running = true

	room_manager.configure(layout, _room_container, _actor)
	var did_start := room_manager.start_layout()
	if not did_start:
		_running = false
		return false

	var payload := {
		"layout_id": layout.layout_id,
		"start_room_id": layout.start_room_id,
	}
	run_started.emit(payload.duplicate(true))
	return true


func advance_room(preferred_room_id: StringName = &"") -> bool:
	if not _running or _completed or room_manager == null:
		return false
	return room_manager.request_next_room(preferred_room_id)


func is_running() -> bool:
	return _running


func is_completed() -> bool:
	return _completed


func get_current_room_id() -> StringName:
	if room_manager == null:
		return &""
	return room_manager.current_room_id


func get_current_room() -> Node2D:
	if room_manager == null:
		return null
	return room_manager.current_room


func get_visible_room_defs() -> Array[RoomDef]:
	if room_manager == null:
		return []
	return room_manager.get_visible_room_defs()


func _ensure_room_manager() -> void:
	if room_manager != null:
		return
	room_manager = RoomManager.new()
	room_manager.name = "RoomManager"
	add_child(room_manager)
	room_manager.room_changed.connect(_on_room_manager_room_changed)
	room_manager.layout_completed.connect(_on_room_manager_layout_completed)


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


func _on_room_manager_room_changed(room_id: StringName, room_type: StringName) -> void:
	visited_room_ids.append(room_id)
	_configure_run_controlled_room(room_manager.current_room)
	room_changed.emit(room_id, room_type)


func _on_room_manager_layout_completed(layout_id: StringName) -> void:
	if _completed:
		return
	_completed = true
	_running = false

	var result := {
		"layout_id": layout_id,
		"completed": true,
		"current_room_id": room_manager.current_room_id,
		"visited_room_ids": visited_room_ids.duplicate(),
		"cleared_room_ids": room_manager.cleared_room_ids.keys(),
	}
	if emit_session_finished_event:
		if has_node("/root/GameManager") and GameManager.is_session_active():
			GameManager.finish_session(result)
		elif has_node("/root/EventBus"):
			EventBus.emit_session_finished(result)
	run_completed.emit(result.duplicate(true))


func _configure_run_controlled_room(room: Node) -> void:
	if room == null:
		return
	if room.has_method("set_finish_session_on_resolve"):
		room.call("set_finish_session_on_resolve", false)
