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
var _portal_column: Polygon2D
var _portal_ground_glow: Polygon2D
var _portal_streaks: Node2D
var _portal_sparkles: Node2D
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
		if _portal_ground_glow != null:
			_portal_ground_glow.scale = Vector2(1.0 + sin(tick / 140.0) * 0.08, 1.0)
		if _portal_streaks != null:
			var index := 0
			for child: Node in _portal_streaks.get_children():
				var streak := child as Line2D
				if streak == null:
					continue
				var alpha := 0.48 + sin(tick / 150.0 + float(index) * 0.9) * 0.24
				streak.default_color = Color(0.84, 0.94, 1.0, alpha)
				streak.position.y = sin(tick / 230.0 + float(index)) * 3.0
				index += 1
		if _portal_sparkles != null:
			_portal_sparkles.rotation = sin(tick / 520.0) * 0.06


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
	if _portal_column != null:
		_portal_column.polygon = _portal_column_points(size, 12)
		_portal_column.color = Color(0.66, 0.83, 1.0, 0.28)
		_portal_column.z_index = 1
	if _portal_ground_glow != null:
		_portal_ground_glow.position = Vector2(0.0, size.y * 0.38)
		_portal_ground_glow.polygon = _ellipse_points(Vector2(size.x * 0.78, size.y * 0.12), 28)
		_portal_ground_glow.color = Color(0.86, 0.94, 1.0, 0.62)
		_portal_ground_glow.z_index = 3
	_apply_portal_streak_layout(size)
	_apply_portal_sparkle_layout(size)
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
	_remove_legacy_portal_child(portal, "PortalCore")
	_remove_legacy_portal_child(portal, "PortalRing")
	_remove_legacy_portal_child(portal, "PortalSpark")
	_portal_column = portal.get_node_or_null("PortalColumn") as Polygon2D
	if _portal_column == null:
		_portal_column = Polygon2D.new()
		_portal_column.name = "PortalColumn"
		portal.add_child(_portal_column)
	_portal_streaks = portal.get_node_or_null("PortalStreaks") as Node2D
	if _portal_streaks == null:
		_portal_streaks = Node2D.new()
		_portal_streaks.name = "PortalStreaks"
		portal.add_child(_portal_streaks)
	_ensure_line_children(_portal_streaks, "Streak", 7)
	_portal_ground_glow = portal.get_node_or_null("PortalGroundGlow") as Polygon2D
	if _portal_ground_glow == null:
		_portal_ground_glow = Polygon2D.new()
		_portal_ground_glow.name = "PortalGroundGlow"
		portal.add_child(_portal_ground_glow)
	_portal_sparkles = portal.get_node_or_null("PortalSparkles") as Node2D
	if _portal_sparkles == null:
		_portal_sparkles = Node2D.new()
		_portal_sparkles.name = "PortalSparkles"
		portal.add_child(_portal_sparkles)
	_ensure_line_children(_portal_sparkles, "Sparkle", 4)
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
		&"N":
			return Vector2(58.0, 124.0)
		&"S":
			return Vector2(54.0, 116.0)
		_:
			return Vector2(50.0, 108.0)


func _ellipse_points(size: Vector2, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(segment_count):
		var angle := TAU * float(index) / float(segment_count)
		points.append(Vector2(cos(angle) * size.x, sin(angle) * size.y))
	return points


func _portal_column_points(size: Vector2, arc_segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_width := size.x * 0.42
	var arc_center_y := -size.y * 0.28
	var arc_height := size.y * 0.24
	var bottom_y := size.y * 0.38
	points.append(Vector2(-half_width, bottom_y))
	points.append(Vector2(half_width, bottom_y))
	for index: int in range(arc_segments + 1):
		var angle := PI * float(index) / float(arc_segments)
		points.append(Vector2(cos(angle) * half_width, arc_center_y - sin(angle) * arc_height))
	return points


func _apply_portal_streak_layout(size: Vector2) -> void:
	if _portal_streaks == null:
		return
	var children := _portal_streaks.get_children()
	var count := children.size()
	if count <= 0:
		return
	for index: int in range(count):
		var streak := children[index] as Line2D
		if streak == null:
			continue
		var ratio := 0.0 if count == 1 else float(index) / float(count - 1)
		var x := lerpf(-size.x * 0.28, size.x * 0.28, ratio)
		var top_y := -size.y * (0.46 + 0.05 * float(index % 2))
		var bottom_y := size.y * (0.26 + 0.04 * float((index + 1) % 3))
		streak.points = PackedVector2Array([
			Vector2(x, top_y),
			Vector2(x + sin(float(index) * 1.7) * 2.0, bottom_y),
		])
		streak.width = 1.0 + float(index % 3) * 0.4
		streak.default_color = Color(0.84, 0.94, 1.0, 0.62)
		streak.z_index = 2


func _apply_portal_sparkle_layout(size: Vector2) -> void:
	if _portal_sparkles == null:
		return
	var points := [
		Vector2(-size.x * 0.52, -size.y * 0.18),
		Vector2(size.x * 0.48, -size.y * 0.06),
		Vector2(-size.x * 0.36, size.y * 0.12),
		Vector2(size.x * 0.38, size.y * 0.24),
	]
	var index := 0
	for child: Node in _portal_sparkles.get_children():
		var sparkle := child as Line2D
		if sparkle == null:
			continue
		var center: Vector2 = points[index % points.size()]
		var radius := 2.6 + float(index % 2)
		sparkle.points = PackedVector2Array([
			center + Vector2(-radius, 0.0),
			center + Vector2(radius, 0.0),
			center,
			center + Vector2(0.0, -radius),
			center + Vector2(0.0, radius),
		])
		sparkle.width = 1.2
		sparkle.default_color = Color(0.96, 0.98, 1.0, 0.78)
		sparkle.z_index = 4
		index += 1


func _ensure_line_children(parent: Node2D, prefix: String, count: int) -> void:
	for index: int in range(count):
		var line := parent.get_node_or_null("%s%d" % [prefix, index]) as Line2D
		if line == null:
			line = Line2D.new()
			line.name = "%s%d" % [prefix, index]
			parent.add_child(line)


func _remove_legacy_portal_child(parent: Node, child_name: String) -> void:
	var child := parent.get_node_or_null(child_name)
	if child == null:
		return
	parent.remove_child(child)
	child.queue_free()


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
