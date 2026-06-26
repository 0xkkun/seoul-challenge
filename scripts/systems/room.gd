class_name Room
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const BACKGROUND_TEXTURE = preload("res://assets/backgrounds/gyeongbokgung/gyeongbokgung_night.png")
const WALL_THICKNESS := 16.0
const DOOR_GAP := 140.0

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
var _gates := {}


func _ready() -> void:
	_floor = _resolve_floor()
	_build_doors()
	_cache_doors()
	_apply_room_visuals()
	_build_background()
	_build_walls()
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


## door_dirs(레이아웃 연결에서 RoomManager가 주입하거나 씬 기본값)대로 문을 생성한다.
## 이렇게 하면 문 방향이 항상 미니맵(레이아웃 grid 연결)과 일치한다.
func _build_doors() -> void:
	var doors_parent := get_node_or_null("Doors")
	if doors_parent == null:
		doors_parent = Node2D.new()
		doors_parent.name = "Doors"
		add_child(doors_parent)
	for dir: StringName in door_dirs:
		if _has_door_dir(doors_parent, dir):
			continue
		doors_parent.add_child(_make_door(dir))


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
		var gate: CollisionShape2D = _gates.get(door.door_dir)
		if gate != null:
			gate.set_deferred("disabled", door.is_open())


func _apply_room_visuals() -> void:
	if _floor == null:
		return
	_floor.size = RoomPalette.ROOM_SIZE
	_floor.position = -RoomPalette.ROOM_HALF_SIZE
	_floor.color = RoomPalette.get_room_floor_color(room_type)
	# 실제 맵 배경 스프라이트를 쓰므로 placeholder 색 바닥은 숨긴다(색 계약은 유지).
	_floor.visible = false


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


## 방 배경으로 실제 맵 스프라이트를 깐다(placeholder 색 바닥 대체).
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


## 방 둘레에 벽을 세워 플레이어를 가둔다(= 맵 최대 크기/경계). 문 자리엔 게이트를 두고,
## 잠김 시 막고 열리면(클리어) 통과시킨다.
func _build_walls() -> void:
	if get_node_or_null("Walls") != null:
		return
	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	var half := RoomPalette.ROOM_HALF_SIZE
	var t := WALL_THICKNESS
	_build_wall_side(body, &"N", true, -half.y - t * 0.5, half.x, t)
	_build_wall_side(body, &"S", true, half.y + t * 0.5, half.x, t)
	_build_wall_side(body, &"W", false, -half.x - t * 0.5, half.y, t)
	_build_wall_side(body, &"E", false, half.x + t * 0.5, half.y, t)


func _build_wall_side(body: StaticBody2D, dir: StringName, horizontal: bool, offset: float, extent: float, thickness: float) -> void:
	if not door_dirs.has(dir):
		_add_wall_segment(body, horizontal, offset, -extent - thickness, extent + thickness, thickness, false, dir)
		return
	var gap := DOOR_GAP * 0.5
	_add_wall_segment(body, horizontal, offset, -extent - thickness, -gap, thickness, false, dir)
	_add_wall_segment(body, horizontal, offset, gap, extent + thickness, thickness, false, dir)
	_add_wall_segment(body, horizontal, offset, -gap, gap, thickness, true, dir)


func _add_wall_segment(body: StaticBody2D, horizontal: bool, offset: float, lo: float, hi: float, thickness: float, is_gate: bool, dir: StringName) -> void:
	if hi - lo <= 0.0:
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var center := (lo + hi) * 0.5
	var length := hi - lo
	if horizontal:
		rect.size = Vector2(length, thickness)
		shape.position = Vector2(center, offset)
	else:
		rect.size = Vector2(thickness, length)
		shape.position = Vector2(offset, center)
	shape.shape = rect
	body.add_child(shape)
	if is_gate:
		_gates[dir] = shape


func _on_door_transition_requested(door_dir: StringName) -> void:
	transition_requested.emit(room_id, door_dir)
