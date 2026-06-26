class_name BossRoom
extends Room

signal boss_spawn_requested(room_id: StringName, boss_id: StringName, spawn_position: Vector2)
signal boss_resolved(room_id: StringName, boss_id: StringName)

@export var boss_id: StringName = &"gyeongbokgung_boss"
@export var spawn_anchor_path: NodePath

var _spawn_requested := false
var _boss_resolved := false


func _ready() -> void:
	room_type = &"final"
	super._ready()


func enter() -> void:
	super.enter()
	request_boss_spawn()


func is_cleared() -> bool:
	return _boss_resolved


func get_minimap_type() -> StringName:
	return &"boss"


func request_boss_spawn() -> bool:
	if _spawn_requested or _boss_resolved:
		return false
	_spawn_requested = true
	var spawn_position := get_spawn_position()
	boss_spawn_requested.emit(room_id, boss_id, spawn_position)
	if has_node("/root/EventBus"):
		EventBus.emit_interaction_completed({
			"kind": "boss_spawn_requested",
			"room_id": room_id,
			"room_type": room_type,
			"boss_id": boss_id,
			"spawn_position": spawn_position,
		})
	return true


func complete_boss_encounter() -> bool:
	if _boss_resolved:
		return false
	_boss_resolved = true
	var payload := {
		"room_id": room_id,
		"room_type": room_type,
		"boss_id": boss_id,
	}
	boss_resolved.emit(room_id, boss_id)
	if has_node("/root/EventBus"):
		EventBus.emit_friend_purified(payload)
	mark_cleared()
	if has_node("/root/GameManager") and GameManager.is_session_active():
		GameManager.finish_session({
			"reason": "boss_resolved",
			"room_id": room_id,
			"boss_id": boss_id,
		})
	return true


func has_requested_spawn() -> bool:
	return _spawn_requested


func get_spawn_position() -> Vector2:
	var anchor := _resolve_spawn_anchor()
	if anchor != null:
		return anchor.global_position
	return global_position


func _resolve_spawn_anchor() -> Node2D:
	if not spawn_anchor_path.is_empty():
		return get_node_or_null(spawn_anchor_path) as Node2D
	return find_child("BossSpawnAnchor", true, false) as Node2D
