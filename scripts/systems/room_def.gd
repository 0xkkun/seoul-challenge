class_name RoomDef
extends Resource

@export var room_id: StringName = &""
@export var room_type: StringName = &""
@export_file("*.tscn") var scene_path := ""
@export var connections: Array[StringName] = []
@export var grid_pos := Vector2i.ZERO
@export var hidden := false


func has_connection(target_room_id: StringName) -> bool:
	return connections.has(target_room_id)


func to_payload() -> Dictionary:
	return {
		"room_id": room_id,
		"room_type": room_type,
		"connections": connections.duplicate(),
		"grid_pos": grid_pos,
		"hidden": hidden,
	}
