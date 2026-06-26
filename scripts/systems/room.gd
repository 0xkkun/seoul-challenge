class_name Room
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

signal cleared(room_id: StringName)
signal transition_requested(room_id: StringName, door_dir: StringName)

@export var room_id: StringName = &"room"
@export var room_type: StringName = &"start"
@export var door_dirs: Array[StringName] = []
@export var floor_path: NodePath

var _entered := false
var _cleared := false
var _doors: Array[RoomDoor] = []
var _floor: ColorRect
var _actor: Node2D


func _ready() -> void:
	_floor = _resolve_floor()
	_cache_doors()
	if door_dirs.is_empty():
		for door: RoomDoor in _doors:
			door_dirs.append(door.door_dir)
	_apply_room_visuals()
	_apply_door_state()


func enter() -> void:
	_entered = true
	if has_node("/root/EventBus"):
		EventBus.emit_room_entered(_build_payload())
	if is_cleared():
		mark_cleared()


func is_cleared() -> bool:
	return true


func get_minimap_type() -> StringName:
	return room_type


func configure_actor(actor: Node2D) -> void:
	_actor = actor
	for door: RoomDoor in _doors:
		door.configure_actor(actor)


func check_actor_transitions() -> int:
	if _actor == null:
		return 0
	var transition_count := 0
	for door: RoomDoor in _doors:
		if door.check_transition_for_actor(_actor):
			transition_count += 1
	return transition_count


func mark_cleared() -> void:
	if _cleared:
		return
	_cleared = true
	cleared.emit(room_id)
	_apply_door_state()
	if has_node("/root/EventBus"):
		EventBus.emit_room_cleared(_build_payload())


func has_entered() -> bool:
	return _entered


func has_been_cleared() -> bool:
	return _cleared


func get_doors() -> Array[RoomDoor]:
	return _doors.duplicate()


func get_door(door_dir: StringName) -> RoomDoor:
	for door: RoomDoor in _doors:
		if door.door_dir == door_dir:
			return door
	return null


func _cache_doors() -> void:
	_doors.clear()
	_collect_doors(self)
	for door: RoomDoor in _doors:
		if not door.transition_requested.is_connected(_on_door_transition_requested):
			door.transition_requested.connect(_on_door_transition_requested)
		if _actor != null:
			door.configure_actor(_actor)


func _collect_doors(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is RoomDoor:
			_doors.append(child)
		_collect_doors(child)


func _apply_door_state() -> void:
	for door: RoomDoor in _doors:
		if _cleared:
			door.open()
		else:
			door.lock()


func _apply_room_visuals() -> void:
	if _floor == null:
		return
	_floor.size = RoomPalette.ROOM_SIZE
	_floor.position = -RoomPalette.ROOM_HALF_SIZE
	_floor.color = RoomPalette.get_room_floor_color(room_type)


func _resolve_floor() -> ColorRect:
	if not floor_path.is_empty():
		return get_node_or_null(floor_path) as ColorRect
	return find_child("Floor", true, false) as ColorRect


func _build_payload() -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": room_type,
		"door_dirs": door_dirs.duplicate(),
	}


func _on_door_transition_requested(door_dir: StringName) -> void:
	transition_requested.emit(room_id, door_dir)
