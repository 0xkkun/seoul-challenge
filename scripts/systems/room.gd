class_name Room
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const BACKGROUND_TEXTURE = preload("res://assets/backgrounds/gyeongbokgung/gyeongbokgung_night.png")

signal cleared(room_id: StringName)
signal transition_requested(room_id: StringName, door_dir: StringName)

@export var room_id: StringName = &"room"
@export var room_type: StringName = &"start"
@export var door_dirs: Array[StringName] = []
@export var floor_path: NodePath

var _entered := false
var _cleared := false
var _doors: Array[RoomDoor] = []
var _wall_segments: Array[StaticBody2D] = []
var _floor: ColorRect
var _actor: Node2D


func _ready() -> void:
	_floor = _resolve_floor()
	_build_doors()
	_cache_doors()
	if door_dirs.is_empty():
		for door: RoomDoor in _doors:
			door_dirs.append(door.door_dir)
	_build_perimeter_walls()
	_apply_room_visuals()
	_build_background()
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


func get_wall_segments() -> Array[StaticBody2D]:
	return _wall_segments.duplicate()


func get_door(door_dir: StringName) -> RoomDoor:
	for door: RoomDoor in _doors:
		if door.door_dir == door_dir:
			return door
	return null


func _build_doors() -> void:
	var doors_parent := get_node_or_null("Doors")
	if doors_parent == null:
		doors_parent = Node2D.new()
		doors_parent.name = "Doors"
		add_child(doors_parent)
	if door_dirs.is_empty():
		return
	_remove_unconfigured_doors(doors_parent)
	for dir: StringName in door_dirs:
		if _has_door_dir(doors_parent, dir):
			continue
		doors_parent.add_child(_make_door(dir))


func _remove_unconfigured_doors(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is RoomDoor and not door_dirs.has((child as RoomDoor).door_dir):
			parent.remove_child(child)
			child.queue_free()


func _has_door_dir(parent: Node, dir: StringName) -> bool:
	for child: Node in parent.get_children():
		if child is RoomDoor and (child as RoomDoor).door_dir == dir:
			return true
	return false


func _make_door(dir: StringName) -> RoomDoor:
	var door := RoomDoor.new()
	door.name = "%sDoor" % String(dir)
	door.door_dir = dir

	var visual := ColorRect.new()
	visual.name = "DoorVisual"
	door.add_child(visual)

	var area := Area2D.new()
	area.name = "TransitionArea"
	area.collision_layer = 0
	door.add_child(area)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	area.add_child(shape)
	return door


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
	_floor.visible = false


func _resolve_floor() -> ColorRect:
	if not floor_path.is_empty():
		return get_node_or_null(floor_path) as ColorRect
	return find_child("Floor", true, false) as ColorRect


func _build_perimeter_walls() -> void:
	var wall_layer := _resolve_wall_layer()
	_wall_segments.clear()

	var half := RoomPalette.ROOM_HALF_SIZE
	var thickness: float = RoomPalette.WALL_THICKNESS
	var gap_length := RoomPalette.DOOR_SIZE.x + RoomPalette.WALL_DOOR_GAP_PADDING * 2.0

	_add_horizontal_walls(wall_layer, "North", -half.y - thickness * 0.5, door_dirs.has(&"N"), gap_length)
	_add_horizontal_walls(wall_layer, "South", half.y + thickness * 0.5, door_dirs.has(&"S"), gap_length)
	_add_vertical_walls(wall_layer, "West", -half.x - thickness * 0.5, door_dirs.has(&"W"), gap_length)
	_add_vertical_walls(wall_layer, "East", half.x + thickness * 0.5, door_dirs.has(&"E"), gap_length)


func _resolve_wall_layer() -> Node2D:
	var layer := get_node_or_null("Walls") as Node2D
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Walls"
	add_child(layer)
	return layer


func _add_horizontal_walls(layer: Node2D, side_name: String, y: float, has_gap: bool, gap_length: float) -> void:
	var half := RoomPalette.ROOM_HALF_SIZE
	var thickness: float = RoomPalette.WALL_THICKNESS
	if not has_gap:
		_add_wall_segment(layer, "%sWall" % side_name, Vector2(0.0, y), Vector2(RoomPalette.ROOM_SIZE.x, thickness))
		return

	var segment_width := maxf(0.0, half.x - gap_length * 0.5)
	_add_wall_segment(
		layer,
		"%sWallLeft" % side_name,
		Vector2(-half.x + segment_width * 0.5, y),
		Vector2(segment_width, thickness)
	)
	_add_wall_segment(
		layer,
		"%sWallRight" % side_name,
		Vector2(gap_length * 0.5 + segment_width * 0.5, y),
		Vector2(segment_width, thickness)
	)


func _add_vertical_walls(layer: Node2D, side_name: String, x: float, has_gap: bool, gap_length: float) -> void:
	var half := RoomPalette.ROOM_HALF_SIZE
	var thickness: float = RoomPalette.WALL_THICKNESS
	if not has_gap:
		_add_wall_segment(layer, "%sWall" % side_name, Vector2(x, 0.0), Vector2(thickness, RoomPalette.ROOM_SIZE.y))
		return

	var segment_height := maxf(0.0, half.y - gap_length * 0.5)
	_add_wall_segment(
		layer,
		"%sWallTop" % side_name,
		Vector2(x, -half.y + segment_height * 0.5),
		Vector2(thickness, segment_height)
	)
	_add_wall_segment(
		layer,
		"%sWallBottom" % side_name,
		Vector2(x, gap_length * 0.5 + segment_height * 0.5),
		Vector2(thickness, segment_height)
	)


func _add_wall_segment(layer: Node2D, segment_name: String, segment_position: Vector2, segment_size: Vector2) -> void:
	if segment_size.x <= 0.0 or segment_size.y <= 0.0:
		return
	var body := StaticBody2D.new()
	body.name = segment_name
	body.position = segment_position
	body.collision_layer = 1
	body.collision_mask = 1

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = segment_size
	shape.shape = rectangle
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.name = "WallVisual"
	visual.color = RoomPalette.WALL_COLOR
	visual.polygon = PackedVector2Array([
		Vector2(-segment_size.x * 0.5, -segment_size.y * 0.5),
		Vector2(segment_size.x * 0.5, -segment_size.y * 0.5),
		Vector2(segment_size.x * 0.5, segment_size.y * 0.5),
		Vector2(-segment_size.x * 0.5, segment_size.y * 0.5),
	])
	body.add_child(visual)

	layer.add_child(body)
	_wall_segments.append(body)


func _build_background() -> void:
	if get_node_or_null("Background") != null:
		return
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.texture = BACKGROUND_TEXTURE
	bg.z_index = -10
	var tex_size := BACKGROUND_TEXTURE.get_size()
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		var fit := maxf(RoomPalette.ROOM_SIZE.x / tex_size.x, RoomPalette.ROOM_SIZE.y / tex_size.y)
		bg.scale = Vector2(fit, fit)
	add_child(bg)


func _build_payload() -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": room_type,
		"door_dirs": door_dirs.duplicate(),
	}


func _on_door_transition_requested(door_dir: StringName) -> void:
	transition_requested.emit(room_id, door_dir)
