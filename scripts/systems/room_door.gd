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
@export var actor_path: NodePath

var state := DoorState.LOCKED

var _trigger_area: Area2D
var _visual: CanvasItem
var _collision_shape: CollisionShape2D
var _actor: Node2D
var _ping_marker: Label
var _was_actor_overlapping := false


func _ready() -> void:
	_trigger_area = _resolve_trigger_area()
	_visual = _resolve_visual()
	_collision_shape = _resolve_collision_shape()
	_actor = _resolve_actor()
	_ping_marker = _resolve_ping_marker()
	if position == Vector2.ZERO:
		position = RoomPalette.get_door_position(door_dir)
	if _trigger_area != null and not _trigger_area.body_entered.is_connected(_on_body_entered):
		_trigger_area.body_entered.connect(_on_body_entered)
	if _trigger_area != null and not _trigger_area.area_entered.is_connected(_on_area_entered):
		_trigger_area.area_entered.connect(_on_area_entered)
	_apply_visual_layout()
	_apply_ping_marker_layout()
	_apply_collision_shape()
	_apply_state()
	set_process(_ping_marker != null)
	set_physics_process(_actor != null)


func lock() -> void:
	_set_state(DoorState.LOCKED)


func open() -> void:
	_set_state(DoorState.OPEN)


func is_open() -> bool:
	return state == DoorState.OPEN


func is_locked() -> bool:
	return state == DoorState.LOCKED


func configure_actor(actor: Node2D) -> void:
	_actor = actor
	_was_actor_overlapping = false
	set_physics_process(_actor != null)


func check_transition_for_actor(actor: Node2D) -> bool:
	if actor == null:
		_was_actor_overlapping = false
		return false

	var is_overlapping := _contains_global_point(actor.global_position)
	if not is_open():
		_was_actor_overlapping = is_overlapping
		return false
	if not is_overlapping:
		_was_actor_overlapping = false
		return false
	if _was_actor_overlapping:
		return false

	_was_actor_overlapping = true
	return request_transition()


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
	_was_actor_overlapping = false
	_apply_state()
	state_changed.emit(door_dir, state)


func _physics_process(_delta: float) -> void:
	check_transition_for_actor(_actor)


func _process(_delta: float) -> void:
	if _ping_marker == null or not _ping_marker.visible:
		return
	var marker_color := RoomPalette.MINIMAP_PING_COLOR
	marker_color.a = 0.62 + sin(float(Time.get_ticks_msec()) / 160.0) * 0.22
	_ping_marker.modulate = marker_color


func _apply_state() -> void:
	if _trigger_area != null:
		_trigger_area.monitoring = is_open()
		_trigger_area.monitorable = is_open()
	if _visual != null:
		if _visual is ColorRect:
			(_visual as ColorRect).color = RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR
		else:
			_visual.modulate = RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR
	if _ping_marker != null:
		_ping_marker.visible = is_open()


func _apply_visual_layout() -> void:
	if not (_visual is ColorRect):
		return
	var visual_rect := _visual as ColorRect
	visual_rect.size = RoomPalette.DOOR_SIZE
	visual_rect.position = -RoomPalette.DOOR_SIZE * 0.5


func _apply_ping_marker_layout() -> void:
	if _ping_marker == null:
		return
	_ping_marker.text = _ping_arrow_for_door_dir(door_dir)
	_ping_marker.custom_minimum_size = Vector2(20.0, 20.0)
	_ping_marker.size = Vector2(20.0, 20.0)
	_ping_marker.position = _ping_marker_position_for_door_dir(door_dir)
	_ping_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ping_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ping_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ping_marker.z_index = 20


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


func _resolve_ping_marker() -> Label:
	var marker := find_child("PingMarker", false, false) as Label
	if marker != null:
		return marker
	marker = Label.new()
	marker.name = "PingMarker"
	add_child(marker)
	return marker


func _resolve_actor() -> Node2D:
	if not actor_path.is_empty():
		return get_node_or_null(actor_path) as Node2D
	return null


func _contains_global_point(global_point: Vector2) -> bool:
	if _collision_shape == null or _collision_shape.shape == null:
		return false
	var rectangle := _collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return false
	var local_point := _collision_shape.to_local(global_point)
	var half_size := rectangle.size * 0.5
	return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y


func _ping_arrow_for_door_dir(next_door_dir: StringName) -> String:
	match next_door_dir:
		&"N":
			return "^"
		&"S":
			return "v"
		&"E":
			return ">"
		&"W":
			return "<"
	return "."


func _ping_marker_position_for_door_dir(next_door_dir: StringName) -> Vector2:
	match next_door_dir:
		&"N":
			return Vector2(-10.0, -38.0)
		&"S":
			return Vector2(-10.0, 18.0)
		&"E":
			return Vector2(22.0, -10.0)
		&"W":
			return Vector2(-42.0, -10.0)
	return Vector2(-10.0, -10.0)


func _on_body_entered(_body: Node2D) -> void:
	request_transition()


func _on_area_entered(_area: Area2D) -> void:
	request_transition()
