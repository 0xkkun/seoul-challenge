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
var _blocker_body: StaticBody2D
var _blocker_shape: CollisionShape2D
var _actor: Node2D
var _ping_marker: Label
var _portal_visual: Node2D
var _portal_core: Polygon2D
var _portal_ring: Line2D
var _portal_spark: Line2D
var _was_actor_overlapping := false


func _ready() -> void:
	_trigger_area = _resolve_trigger_area()
	_visual = _resolve_visual()
	_collision_shape = _resolve_collision_shape()
	_blocker_body = _resolve_blocker_body()
	_blocker_shape = _resolve_blocker_shape()
	_actor = _resolve_actor()
	_ping_marker = _resolve_ping_marker()
	_portal_visual = _resolve_portal_visual()
	if position == Vector2.ZERO:
		position = RoomPalette.get_door_position(door_dir)
	if _trigger_area != null and not _trigger_area.body_entered.is_connected(_on_body_entered):
		_trigger_area.body_entered.connect(_on_body_entered)
	if _trigger_area != null and not _trigger_area.area_entered.is_connected(_on_area_entered):
		_trigger_area.area_entered.connect(_on_area_entered)
	_apply_visual_layout()
	_apply_portal_layout()
	_apply_ping_marker_layout()
	_apply_collision_shape()
	_apply_blocker_shape()
	_apply_state()
	set_process(_ping_marker != null or _portal_visual != null)
	set_physics_process(_actor != null)


func lock() -> void:
	_set_state(DoorState.LOCKED)


func open() -> void:
	_set_state(DoorState.OPEN)


func is_open() -> bool:
	return state == DoorState.OPEN


func is_locked() -> bool:
	return state == DoorState.LOCKED


func is_blocking_body_enabled() -> bool:
	return _blocker_shape != null and not _blocker_shape.disabled


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
	var tick := float(Time.get_ticks_msec())
	if _ping_marker != null and _ping_marker.visible:
		var marker_color := RoomPalette.MINIMAP_PING_COLOR
		marker_color.a = 0.62 + sin(tick / 160.0) * 0.22
		_ping_marker.modulate = marker_color
	if _portal_visual != null and _portal_visual.visible:
		var pulse := 1.0 + sin(tick / 180.0) * 0.08
		_portal_visual.scale = Vector2(pulse, pulse)
		if _portal_spark != null:
			_portal_spark.rotation = tick / 720.0


func _apply_state() -> void:
	if _trigger_area != null:
		_trigger_area.monitoring = is_open()
		_trigger_area.monitorable = is_open()
	if _visual != null:
		if _visual is ColorRect:
			var color := RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR
			color.a = 0.0 if is_open() else color.a
			(_visual as ColorRect).color = color
		else:
			_visual.modulate = RoomPalette.DOOR_OPEN_COLOR if is_open() else RoomPalette.DOOR_LOCKED_COLOR
	if _ping_marker != null:
		_ping_marker.visible = is_open()
	if _portal_visual != null:
		_portal_visual.visible = is_open()
	if _blocker_shape != null:
		_blocker_shape.disabled = is_open()


func _apply_visual_layout() -> void:
	if not (_visual is ColorRect):
		return
	var visual_rect := _visual as ColorRect
	visual_rect.size = RoomPalette.DOOR_SIZE
	visual_rect.position = -RoomPalette.DOOR_SIZE * 0.5


func _apply_portal_layout() -> void:
	if _portal_visual == null:
		return
	var size := _portal_size_for_door_dir(door_dir)
	if _portal_core != null:
		_portal_core.polygon = _ellipse_points(size * 0.42, 20)
		_portal_core.color = Color(RoomPalette.MINIMAP_PING_COLOR.r, RoomPalette.MINIMAP_PING_COLOR.g, RoomPalette.MINIMAP_PING_COLOR.b, 0.58)
	if _portal_ring != null:
		_portal_ring.points = _ellipse_points(size * 0.5, 32)
		_portal_ring.closed = true
		_portal_ring.width = 3.0
		_portal_ring.default_color = Color(0.84, 0.96, 1.0, 0.86)
	if _portal_spark != null:
		_portal_spark.points = _portal_spark_points(size * 0.5)
		_portal_spark.closed = false
		_portal_spark.width = 2.0
		_portal_spark.default_color = Color(0.92, 0.78, 1.0, 0.82)
	_portal_visual.z_index = 12


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


func _apply_blocker_shape() -> void:
	if _blocker_shape == null:
		return
	var rectangle := _blocker_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		_blocker_shape.shape = rectangle
	var gap_length := RoomPalette.DOOR_SIZE.x + RoomPalette.WALL_DOOR_GAP_PADDING * 2.0
	match door_dir:
		&"E", &"W":
			rectangle.size = Vector2(RoomPalette.WALL_THICKNESS, gap_length)
		_:
			rectangle.size = Vector2(gap_length, RoomPalette.WALL_THICKNESS)


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


func _resolve_blocker_body() -> StaticBody2D:
	var body := get_node_or_null("DoorBlocker") as StaticBody2D
	if body != null:
		return body
	body = StaticBody2D.new()
	body.name = "DoorBlocker"
	body.collision_layer = 1
	body.collision_mask = 1
	add_child(body)
	return body


func _resolve_blocker_shape() -> CollisionShape2D:
	if _blocker_body == null:
		return null
	var shape := _blocker_body.get_node_or_null("DoorBlockShape") as CollisionShape2D
	if shape != null:
		return shape
	shape = CollisionShape2D.new()
	shape.name = "DoorBlockShape"
	_blocker_body.add_child(shape)
	return shape


func _resolve_ping_marker() -> Label:
	var marker := find_child("PingMarker", false, false) as Label
	if marker != null:
		return marker
	marker = Label.new()
	marker.name = "PingMarker"
	add_child(marker)
	return marker


func _resolve_portal_visual() -> Node2D:
	var portal := find_child("PortalVisual", false, false) as Node2D
	if portal == null:
		portal = Node2D.new()
		portal.name = "PortalVisual"
		add_child(portal)
	_portal_core = portal.get_node_or_null("PortalCore") as Polygon2D
	if _portal_core == null:
		_portal_core = Polygon2D.new()
		_portal_core.name = "PortalCore"
		portal.add_child(_portal_core)
	_portal_ring = portal.get_node_or_null("PortalRing") as Line2D
	if _portal_ring == null:
		_portal_ring = Line2D.new()
		_portal_ring.name = "PortalRing"
		portal.add_child(_portal_ring)
	_portal_spark = portal.get_node_or_null("PortalSpark") as Line2D
	if _portal_spark == null:
		_portal_spark = Line2D.new()
		_portal_spark.name = "PortalSpark"
		portal.add_child(_portal_spark)
	return portal


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


func _portal_size_for_door_dir(next_door_dir: StringName) -> Vector2:
	match next_door_dir:
		&"E", &"W":
			return Vector2(24.0, 58.0)
		_:
			return Vector2(58.0, 24.0)


func _ellipse_points(size: Vector2, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		points.append(Vector2(cos(angle) * size.x, sin(angle) * size.y))
	return points


func _portal_spark_points(size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-size.x * 0.25, -size.y * 0.55),
		Vector2(size.x * 0.35, -size.y * 0.12),
		Vector2(-size.x * 0.1, size.y * 0.18),
		Vector2(size.x * 0.45, size.y * 0.52),
	])


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
