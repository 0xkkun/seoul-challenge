class_name RoomDoor
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

signal state_changed(door_dir: StringName, state: int)
signal transition_requested(door_dir: StringName)

enum DoorState {
	LOCKED,
	OPEN,
}

@export var door_dir: StringName = &"N"
@export var trigger_area_path: NodePath
@export var visual_path: NodePath
@export var collision_shape_path: NodePath

var state := DoorState.LOCKED

var _trigger_area: Area2D
var _visual: CanvasItem
var _collision_shape: CollisionShape2D


func _ready() -> void:
	_trigger_area = _resolve_trigger_area()
	_visual = _resolve_visual()
	_collision_shape = _resolve_collision_shape()
	if position == Vector2.ZERO:
		position = RoomPalette.get_door_position(door_dir)
	if _trigger_area != null and not _trigger_area.body_entered.is_connected(_on_body_entered):
		_trigger_area.body_entered.connect(_on_body_entered)
	_apply_visual_layout()
	_apply_collision_shape()
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
		if _visual is ColorRect:
			(_visual as ColorRect).color = RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR
		else:
			_visual.modulate = RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR


func _apply_visual_layout() -> void:
	if not (_visual is ColorRect):
		return
	var visual_rect := _visual as ColorRect
	visual_rect.size = RoomPalette.DOOR_SIZE
	visual_rect.position = -RoomPalette.DOOR_SIZE * 0.5


func _apply_collision_shape() -> void:
	if _collision_shape == null:
		return
	var rectangle := _collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		_collision_shape.shape = rectangle
	rectangle.size = RoomPalette.DOOR_TRIGGER_SIZE


func _resolve_trigger_area() -> Area2D:
	if not trigger_area_path.is_empty():
		return get_node_or_null(trigger_area_path) as Area2D
	return find_child("TransitionArea", true, false) as Area2D


func _resolve_visual() -> CanvasItem:
	if not visual_path.is_empty():
		return get_node_or_null(visual_path) as CanvasItem
	return find_child("DoorVisual", true, false) as CanvasItem


func _resolve_collision_shape() -> CollisionShape2D:
	if not collision_shape_path.is_empty():
		return get_node_or_null(collision_shape_path) as CollisionShape2D
	return find_child("CollisionShape2D", true, false) as CollisionShape2D


func _on_body_entered(_body: Node2D) -> void:
	request_transition()
