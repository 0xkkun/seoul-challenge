class_name RescueStudent
extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

signal rescued(student: Node, source: Node)

@export var student_id: StringName = &"student"
@export var interaction_radius := 72.0
@export var reward_amount := 1

var _rescued := false


func _ready() -> void:
	_apply_palette()
	_add_interactable_group()


func configure_rescue(next_student_id: StringName, next_reward_amount: int) -> void:
	student_id = next_student_id
	reward_amount = next_reward_amount


func activate_from_pool() -> void:
	_rescued = false
	_add_interactable_group()


func activate_at(target_position: Vector2) -> void:
	position = target_position
	visible = true


func reset_for_pool() -> void:
	_rescued = false
	position = Vector2.ZERO
	remove_from_group(TemplateGroups.INTERACTABLE)


func check_interaction(source: Node, _delta: float) -> void:
	if _rescued or source == null or not (source is Node2D):
		return
	var source_position := (source as Node2D).global_position
	if global_position.distance_to(source_position) > interaction_radius:
		return
	rescue(source)


func rescue(source: Node = null) -> bool:
	if _rescued:
		return false
	_rescued = true
	remove_from_group(TemplateGroups.INTERACTABLE)
	if has_node("/root/EventBus"):
		EventBus.emit_student_rescued({"student_id": student_id})
		EventBus.emit_currency_changed({"kind": "permanent", "amount": reward_amount})
	rescued.emit(self, source)
	return true


func is_rescued() -> bool:
	return _rescued


func _add_interactable_group() -> void:
	if not is_in_group(TemplateGroups.INTERACTABLE):
		add_to_group(TemplateGroups.INTERACTABLE)


func _apply_palette() -> void:
	var visual := find_child("Visual", true, false) as Polygon2D
	if visual == null:
		return
	var half_width := RoomPalette.DOOR_SIZE.x / 4.5
	var half_height := RoomPalette.DOOR_SIZE.y * 0.625
	visual.polygon = PackedVector2Array([
		Vector2(-half_width, half_height),
		Vector2(0.0, -half_height),
		Vector2(half_width, half_height),
	])
	visual.color = RoomPalette.STUDENT_MARKER_COLOR
