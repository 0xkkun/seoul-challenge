extends Node

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

var _source: Node = null
var _scope_root: Node = null
var interaction_count := 0


func configure(source: Node, scope_root: Node = null) -> void:
	_source = source
	_scope_root = scope_root


func check_now(delta: float = 0.0) -> int:
	if _source == null:
		return 0

	var dispatched := 0
	for candidate: Node in get_tree().get_nodes_in_group(TemplateGroups.INTERACTABLE):
		if _scope_root != null and not _scope_root.is_ancestor_of(candidate):
			continue
		if candidate.has_method("check_interaction"):
			candidate.call("check_interaction", _source, delta)
			dispatched += 1

	interaction_count += dispatched
	return dispatched
