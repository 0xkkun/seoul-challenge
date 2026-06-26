extends Node2D

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

signal interaction_triggered(source: Node, target: Node)

@export var interaction_radius := 72.0

var interaction_count := 0


func _ready() -> void:
	add_to_group(TemplateGroups.INTERACTABLE)


func check_interaction(source: Node, _delta: float) -> void:
	if source == null or not (source is Node2D):
		return
	var source_position := (source as Node2D).global_position
	if global_position.distance_to(source_position) > interaction_radius:
		return
	interaction_count += 1
	interaction_triggered.emit(source, self)
