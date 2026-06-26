extends Node

const TemplateGroups = preload("res://scripts/constants/template_groups.gd")

var _pool_scenes: Dictionary = {}
var _available: Dictionary = {}
var _active: Dictionary = {}
var _default_parents: Dictionary = {}


func register_scene(
	pool_id: StringName, scene: PackedScene, warm_count: int = 0, parent: Node = null
) -> void:
	_pool_scenes[pool_id] = scene
	if not _available.has(pool_id):
		_available[pool_id] = []
	if not _active.has(pool_id):
		_active[pool_id] = []
	if parent != null:
		_default_parents[pool_id] = parent
	for _i in range(warm_count):
		var node := _instantiate(pool_id)
		_deactivate(node)
		_available[pool_id].append(node)


func acquire(pool_id: StringName, parent: Node = null) -> Node:
	if not _pool_scenes.has(pool_id):
		push_error("Pool not registered: %s" % pool_id)
		return null

	var node: Node
	if _available.get(pool_id, []).is_empty():
		node = _instantiate(pool_id)
	else:
		node = _available[pool_id].pop_back()

	var target_parent: Node = parent if parent != null else _default_parents.get(pool_id, null)
	if target_parent != null and node.get_parent() != target_parent:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		target_parent.add_child(node)

	_activate(node)
	_active[pool_id].append(node)
	return node


func release(node: Node) -> void:
	if node == null:
		return
	var pool_id: StringName = node.get_meta("pool_id", &"")
	if pool_id == &"":
		push_error("Node was not acquired from a pool: %s" % node.name)
		return
	var active_nodes: Array = _active.get(pool_id, [])
	if not active_nodes.has(node):
		return
	_deactivate(node)
	active_nodes.erase(node)
	_available.get_or_add(pool_id, []).append(node)


func release_all() -> void:
	for pool_id: StringName in _active.keys():
		var active_nodes: Array = _active[pool_id].duplicate()
		for node: Node in active_nodes:
			release(node)


func get_available_count(pool_id: StringName) -> int:
	return _available.get(pool_id, []).size()


func get_active_count(pool_id: StringName) -> int:
	return _active.get(pool_id, []).size()


func clear_all() -> void:
	for node_list: Array in _available.values():
		for node: Node in node_list:
			if is_instance_valid(node):
				node.free()
	for node_list: Array in _active.values():
		for node: Node in node_list:
			if is_instance_valid(node):
				node.free()
	_pool_scenes.clear()
	_available.clear()
	_active.clear()
	_default_parents.clear()


func _instantiate(pool_id: StringName) -> Node:
	var scene: PackedScene = _pool_scenes[pool_id]
	var node := scene.instantiate()
	node.set_meta("pool_id", pool_id)
	node.add_to_group(TemplateGroups.POOLED_OBJECT)
	return node


func _activate(node: Node) -> void:
	if node.has_method("activate_from_pool"):
		node.call("activate_from_pool")
	if node is CanvasItem:
		(node as CanvasItem).visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT


func _deactivate(node: Node) -> void:
	if node.has_method("reset_for_pool"):
		node.call("reset_for_pool")
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
