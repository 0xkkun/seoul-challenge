class_name FriendRoom
extends Room

const YOKAI_FRIEND_SCENE = preload("res://scenes/enemies/yokai_friend.tscn")
const FRIEND_SPAWN_FACTOR := Vector2(0.35, 0.0)
const ENTRY_FORWARD_DISTANCE := 260.0
const SPAWN_BOUNDS_INSET := 48.0

signal friend_encounter_started(room_id: StringName)
signal friend_spawned(room_id: StringName, friend_id: StringName, friend: Node)
signal friend_encounter_resolved(room_id: StringName, friend_id: StringName)
signal friend_count_changed(remaining_count: int)

@export var friend_scene: PackedScene = YOKAI_FRIEND_SCENE
@export var friend_id: StringName = &"childhood_friend"

var _encounter_started := false
var _encounter_resolved := false
var _friend_spawned := false
var _active_friends: Array[Node] = []

@onready var _friend_layer: Node2D = _resolve_friend_layer()


func _ready() -> void:
	room_type = &"friend"
	super._ready()


func enter() -> void:
	super.enter()
	if _encounter_resolved:
		return
	if not _encounter_started:
		_encounter_started = true
		friend_encounter_started.emit(room_id)
	if not _friend_spawned:
		_spawn_friend()


func is_cleared() -> bool:
	return _encounter_resolved


func apply_room_config(config: Dictionary) -> void:
	if config.has("friend_id"):
		friend_id = StringName(config.get("friend_id", friend_id))


func get_active_friends() -> Array[Node]:
	_prune_inactive_friends()
	return _active_friends.duplicate()


func get_remaining_friend_count() -> int:
	_prune_inactive_friends()
	return _active_friends.size()


func resolve_friend_encounter(friend: Node = null) -> bool:
	if _encounter_resolved:
		return false
	_encounter_resolved = true
	_active_friends.clear()
	var payload := {
		"kind": "friend_purified",
		"room_id": room_id,
		"room_type": room_type,
		"friend_id": friend_id,
	}
	if friend != null:
		payload["friend_name"] = friend.name
	friend_encounter_resolved.emit(room_id, friend_id)
	friend_count_changed.emit(0)
	if has_node("/root/EventBus"):
		EventBus.emit_friend_purified(payload)
	mark_cleared()
	return true


func restore_cleared_state() -> void:
	_encounter_started = true
	_encounter_resolved = true
	_friend_spawned = true
	for friend: Node in _active_friends:
		if is_instance_valid(friend) and not friend.is_queued_for_deletion():
			friend.queue_free()
	_active_friends.clear()
	super.restore_cleared_state()


func _spawn_friend() -> void:
	_friend_spawned = true
	_active_friends.clear()
	if friend_scene == null:
		friend_count_changed.emit(0)
		return
	var friend := friend_scene.instantiate()
	if not friend is Node2D:
		friend.queue_free()
		friend_count_changed.emit(0)
		return
	_friend_layer.add_child(friend)
	friend.name = String(friend_id)
	(friend as Node2D).position = _friend_spawn_position()
	if friend.has_signal("purified"):
		var callback := Callable(self, "_on_friend_purified")
		if not friend.is_connected("purified", callback):
			friend.connect("purified", callback)
	_active_friends.append(friend)
	friend_spawned.emit(room_id, friend_id, friend)
	friend_count_changed.emit(_active_friends.size())


func _friend_spawn_position() -> Vector2:
	var room_bounds := RoomPalette.get_room_bounds()
	if _actor == null:
		return RoomPalette.ROOM_HALF_SIZE * FRIEND_SPAWN_FACTOR
	var actor_position := to_local(_actor.global_position)
	var forward := (Vector2.ZERO - actor_position).normalized()
	if forward.length() <= 0.001:
		forward = Vector2.RIGHT
	var target := actor_position + forward * ENTRY_FORWARD_DISTANCE
	var safe_bounds := room_bounds.grow(-SPAWN_BOUNDS_INSET)
	return Vector2(
		clampf(target.x, safe_bounds.position.x, safe_bounds.end.x),
		clampf(target.y, safe_bounds.position.y, safe_bounds.end.y)
	)


func _on_friend_purified(friend: Node) -> void:
	if not _active_friends.has(friend):
		return
	_active_friends.erase(friend)
	if is_instance_valid(friend) and not friend.is_queued_for_deletion():
		friend.queue_free()
	resolve_friend_encounter(friend)


func _prune_inactive_friends() -> void:
	for index in range(_active_friends.size() - 1, -1, -1):
		var friend := _active_friends[index]
		if friend == null or not is_instance_valid(friend) or friend.is_queued_for_deletion():
			_active_friends.remove_at(index)


func _resolve_friend_layer() -> Node2D:
	var layer := get_node_or_null("Friends") as Node2D
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Friends"
	add_child(layer)
	return layer
