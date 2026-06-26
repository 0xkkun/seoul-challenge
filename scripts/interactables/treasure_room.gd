class_name TreasureRoom
extends Room

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

signal treasure_picked_up(room_id: StringName, item_id: StringName)

@export var item_id: StringName = &"treasure_stub"
@export var interaction_radius := RoomPalette.DOOR_TRIGGER_SIZE.x
@export var pickup_visual_path: NodePath

var _picked_up := false
var _pickup_visual: CanvasItem


func _ready() -> void:
	room_type = &"treasure"
	super._ready()
	_pickup_visual = _resolve_pickup_visual()
	_apply_pickup_visual()
	_add_interactable_group()


func is_cleared() -> bool:
	return _picked_up


func check_interaction(source: Node, _delta: float) -> void:
	if _picked_up or source == null or not (source is Node2D):
		return
	if get_pickup_position().distance_to((source as Node2D).global_position) > interaction_radius:
		return
	pick_up()


func pick_up() -> bool:
	if _picked_up:
		return false
	_picked_up = true
	remove_from_group(TemplateGroups.INTERACTABLE)
	if _pickup_visual != null:
		_pickup_visual.visible = false
	treasure_picked_up.emit(room_id, item_id)
	if has_node("/root/EventBus"):
		EventBus.emit_interaction_completed({
			"kind": "treasure_picked_up",
			"room_id": room_id,
			"room_type": room_type,
			"item_id": item_id,
		})
	mark_cleared()
	return true


func has_picked_up() -> bool:
	return _picked_up


func get_pickup_position() -> Vector2:
	if _pickup_visual != null:
		return _pickup_visual.global_position
	return global_position


func _add_interactable_group() -> void:
	if not is_in_group(TemplateGroups.INTERACTABLE):
		add_to_group(TemplateGroups.INTERACTABLE)


func _resolve_pickup_visual() -> CanvasItem:
	if not pickup_visual_path.is_empty():
		return get_node_or_null(pickup_visual_path) as CanvasItem
	return find_child("PickupVisual", true, false) as CanvasItem


func _apply_pickup_visual() -> void:
	if not (_pickup_visual is ColorRect):
		return
	var pickup_rect := _pickup_visual as ColorRect
	pickup_rect.size = RoomPalette.DOOR_SIZE
	pickup_rect.position = -RoomPalette.DOOR_SIZE * 0.5
	pickup_rect.color = RoomPalette.REWARD_ROOM_FLOOR_COLOR
