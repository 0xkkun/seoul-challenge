class_name RoomDoor
extends Node2D

signal state_changed(door_dir: StringName, state: int)
signal transition_requested(door_dir: StringName)

enum DoorState {
	LOCKED,
	OPEN,
}

@export var door_dir: StringName = &"N"
@export var trigger_area_path: NodePath
@export var visual_path: NodePath

var state := DoorState.LOCKED

var _trigger_area: Area2D
var _visual: CanvasItem


func _ready() -> void:
	_trigger_area = _resolve_trigger_area()
	_visual = _resolve_visual()
	if _trigger_area != null and not _trigger_area.body_entered.is_connected(_on_body_entered):
		_trigger_area.body_entered.connect(_on_body_entered)
	_apply_state()


func lock() -> void:
	_set_state(DoorState.LOCKED)


func open() -> void:
	_set_state(DoorState.OPEN)


func is_open() -> bool:
	return state == DoorState.OPEN


func is_locked() -> bool:
	return state == DoorState.LOCKED


func request_transition() -> bool:
	if not is_open():
		return false
	transition_requested.emit(door_dir)
	return true


func _set_state(next_state: int) -> void:
	if state == next_state:
		_apply_state()
		return
	state = next_state
	_apply_state()
	state_changed.emit(door_dir, state)


func _apply_state() -> void:
	if _trigger_area != null:
		_trigger_area.monitoring = is_open()
		_trigger_area.monitorable = is_open()
	if _visual != null:
		_visual.modulate = Color(0.35, 0.95, 0.56, 1.0) if is_open() else Color(0.42, 0.45, 0.50, 1.0)


func _resolve_trigger_area() -> Area2D:
	if not trigger_area_path.is_empty():
		return get_node_or_null(trigger_area_path) as Area2D
	return find_child("TransitionArea", true, false) as Area2D


func _resolve_visual() -> CanvasItem:
	if not visual_path.is_empty():
		return get_node_or_null(visual_path) as CanvasItem
	return find_child("DoorVisual", true, false) as CanvasItem


func _on_body_entered(_body: Node2D) -> void:
	request_transition()
