class_name RoomDoor
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const PORTAL_TEXTURE = preload("res://assets/effects/portal.png")
const PORTAL_FRAME_COUNT := 5
const PORTAL_FRAME_TIME := 0.08
const PORTAL_DISPLAY_SCALE := Vector2(1.12, 1.12)

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
var _portal_visual: Node2D
var _portal_sprite: Sprite2D
var _portal_frame_timer := 0.0
var _was_actor_overlapping := false


func _ready() -> void:
	_trigger_area = _resolve_trigger_area()
	_visual = _resolve_visual()
	_collision_shape = _resolve_collision_shape()
	_blocker_body = _resolve_blocker_body()
	_blocker_shape = _resolve_blocker_shape()
	_actor = _resolve_actor()
	_portal_visual = _resolve_portal_visual()
	if position == Vector2.ZERO:
		position = RoomPalette.get_door_position(door_dir)
	if _trigger_area != null and not _trigger_area.body_entered.is_connected(_on_body_entered):
		_trigger_area.body_entered.connect(_on_body_entered)
	if _trigger_area != null and not _trigger_area.area_entered.is_connected(_on_area_entered):
		_trigger_area.area_entered.connect(_on_area_entered)
	_apply_visual_layout()
	_apply_portal_layout()
	_apply_collision_shape()
	_apply_blocker_shape()
	_apply_state()
	set_process(_portal_visual != null)
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
	if get_tree().paused:
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


func _process(delta: float) -> void:
	if _portal_visual != null and _portal_visual.visible:
		_advance_portal_sprite(delta)


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
	_portal_visual.scale = Vector2.ONE
	_portal_visual.z_index = 12
	if _portal_sprite == null:
		return
	_portal_sprite.texture = PORTAL_TEXTURE
	_portal_sprite.hframes = PORTAL_FRAME_COUNT
	_portal_sprite.vframes = 1
	_portal_sprite.frame = clampi(_portal_sprite.frame, 0, PORTAL_FRAME_COUNT - 1)
	_portal_sprite.centered = true
	_portal_sprite.position = Vector2.ZERO
	_portal_sprite.scale = PORTAL_DISPLAY_SCALE
	_portal_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portal_sprite.z_index = 1


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


func _resolve_portal_visual() -> Node2D:
	var portal := find_child("PortalVisual", false, false) as Node2D
	if portal == null:
		portal = Node2D.new()
		portal.name = "PortalVisual"
		add_child(portal)
	_remove_legacy_portal_child(portal, "PortalCore")
	_remove_legacy_portal_child(portal, "PortalRing")
	_remove_legacy_portal_child(portal, "PortalSpark")
	_remove_legacy_portal_child(portal, "PortalColumn")
	_remove_legacy_portal_child(portal, "PortalGroundGlow")
	_remove_legacy_portal_child(portal, "PortalStreaks")
	_remove_legacy_portal_child(portal, "PortalSparkles")
	var sprite_node := portal.get_node_or_null("PortalSprite")
	_portal_sprite = sprite_node as Sprite2D
	if sprite_node != null and _portal_sprite == null:
		portal.remove_child(sprite_node)
		sprite_node.queue_free()
	if _portal_sprite == null:
		_portal_sprite = Sprite2D.new()
		_portal_sprite.name = "PortalSprite"
		portal.add_child(_portal_sprite)
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


func _advance_portal_sprite(delta: float) -> void:
	if _portal_sprite == null:
		return
	_portal_frame_timer += delta
	while _portal_frame_timer >= PORTAL_FRAME_TIME:
		_portal_frame_timer -= PORTAL_FRAME_TIME
		_portal_sprite.frame = (_portal_sprite.frame + 1) % PORTAL_FRAME_COUNT


func _remove_legacy_portal_child(parent: Node, child_name: String) -> void:
	var child := parent.get_node_or_null(child_name)
	if child == null:
		return
	parent.remove_child(child)
	child.queue_free()


func _on_body_entered(_body: Node2D) -> void:
	request_transition()


func _on_area_entered(_area: Area2D) -> void:
	request_transition()
