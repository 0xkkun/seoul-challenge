class_name TreasureRoom
extends Room

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")
const MapItemCatalog = preload("res://scripts/items/map_item_catalog.gd")

signal treasure_picked_up(room_id: StringName, item_id: StringName)

@export var item_id: StringName = MapItemCatalog.DEFAULT_ITEM_ID
@export var randomize_item := false
@export var interaction_radius := RoomPalette.DOOR_TRIGGER_SIZE.x
@export var pickup_visual_path: NodePath
@export var pickup_label_path: NodePath

var _picked_up := false
var _pickup_visual: CanvasItem
var _pickup_label: Label
var _resolved_item_id: StringName = &""


func _ready() -> void:
	room_type = &"treasure"
	super._ready()
	_resolved_item_id = _resolve_item_id()
	_pickup_visual = _resolve_pickup_visual()
	_pickup_label = _resolve_pickup_label()
	_apply_pickup_visual()
	_apply_pickup_label()
	_add_interactable_group()


func enter() -> void:
	super.enter()
	if not _picked_up:
		pick_up(_actor)


func is_cleared() -> bool:
	return _picked_up


func check_interaction(source: Node, _delta: float) -> void:
	if _picked_up or source == null or not (source is Node2D):
		return
	if get_pickup_position().distance_to((source as Node2D).global_position) > interaction_radius:
		return
	pick_up(source)


func pick_up(source: Node = null) -> bool:
	if _picked_up:
		return false
	_picked_up = true
	remove_from_group(TemplateGroups.INTERACTABLE)
	if _pickup_visual != null:
		_pickup_visual.visible = false
	if _pickup_label != null:
		_pickup_label.visible = false
	var resolved_item_id := get_resolved_item_id()
	var applied := _apply_item_to_source(source, resolved_item_id)
	treasure_picked_up.emit(room_id, resolved_item_id)
	if has_node("/root/EventBus"):
		EventBus.emit_interaction_completed({
			"kind": "treasure_picked_up",
			"room_id": room_id,
			"room_type": room_type,
			"item_id": resolved_item_id,
			"item_display_name": MapItemCatalog.get_display_name(resolved_item_id),
			"item_flavor": MapItemCatalog.get_flavor(resolved_item_id),
			"applied": applied,
		})
	mark_cleared()
	return true


func restore_cleared_state() -> void:
	_picked_up = true
	remove_from_group(TemplateGroups.INTERACTABLE)
	if _pickup_visual != null:
		_pickup_visual.visible = false
	if _pickup_label != null:
		_pickup_label.visible = false
	super.restore_cleared_state()


func has_picked_up() -> bool:
	return _picked_up


func get_resolved_item_id() -> StringName:
	if _resolved_item_id == &"":
		_resolved_item_id = _resolve_item_id()
	return _resolved_item_id


func get_item_display_name() -> String:
	return MapItemCatalog.get_display_name(get_resolved_item_id())


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


func _resolve_pickup_label() -> Label:
	if not pickup_label_path.is_empty():
		return get_node_or_null(pickup_label_path) as Label
	return find_child("PickupLabel", true, false) as Label


func _apply_pickup_visual() -> void:
	if not (_pickup_visual is ColorRect):
		return
	var pickup_rect := _pickup_visual as ColorRect
	pickup_rect.size = RoomPalette.DOOR_SIZE
	pickup_rect.position = -RoomPalette.DOOR_SIZE * 0.5
	pickup_rect.color = RoomPalette.REWARD_ROOM_FLOOR_COLOR


func _apply_pickup_label() -> void:
	if _pickup_label == null:
		return
	_pickup_label.text = get_item_display_name()
	_pickup_label.position = Vector2(-64.0, 20.0)
	_pickup_label.size = Vector2(128.0, 28.0)
	_pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _resolve_item_id() -> StringName:
	if randomize_item or item_id == &"":
		return MapItemCatalog.resolve_item_id(&"", room_id)
	return MapItemCatalog.resolve_item_id(item_id, room_id)


func _apply_item_to_source(source: Node, resolved_item_id: StringName) -> bool:
	if source == null or not source.has_method("apply_run_modifier"):
		return false
	return bool(source.call("apply_run_modifier", resolved_item_id))
