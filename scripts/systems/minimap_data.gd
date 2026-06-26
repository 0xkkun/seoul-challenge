class_name MinimapData
extends RefCounted

const TYPE_BOSS := &"boss"
const TYPE_FINAL := &"final"


static func build_from_manager(manager: RoomManager) -> Dictionary:
	if manager == null:
		return _empty_payload()
	return build_from_layout(manager.layout, manager.current_room_id, manager.cleared_room_ids)


static func build_from_layout(
	layout: RoomLayout,
	current_room_id: StringName = &"",
	cleared_room_ids: Dictionary = {}
) -> Dictionary:
	if layout == null:
		return _empty_payload()

	var rooms: Array[Dictionary] = []
	var connections: Array[Dictionary] = []
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		rooms.append(_build_room_entry(layout, room_def, current_room_id, cleared_room_ids))
		for connected_room_id: StringName in room_def.connections:
			connections.append({
				"from_room_id": room_def.room_id,
				"to_room_id": connected_room_id,
				"visible": _is_room_visible(layout, room_def.room_id, current_room_id, cleared_room_ids)
					and _is_room_visible(layout, connected_room_id, current_room_id, cleared_room_ids),
			})

	return {
		"layout_id": layout.layout_id,
		"current_room_id": current_room_id,
		"rooms": rooms,
		"connections": connections,
	}


static func _build_room_entry(
	layout: RoomLayout,
	room_def: RoomDef,
	current_room_id: StringName,
	cleared_room_ids: Dictionary
) -> Dictionary:
	var minimap_type := get_minimap_type(room_def.room_type)
	return {
		"room_id": room_def.room_id,
		"room_type": room_def.room_type,
		"minimap_type": minimap_type,
		"current": room_def.room_id == current_room_id,
		"cleared": bool(cleared_room_ids.get(room_def.room_id, false)),
		"hidden": room_def.hidden,
		"visible": _is_room_visible(layout, room_def.room_id, current_room_id, cleared_room_ids),
		"connections": room_def.connections.duplicate(),
	}


static func get_minimap_type(room_type: StringName) -> StringName:
	if room_type == TYPE_FINAL:
		return TYPE_BOSS
	return room_type


static func _is_room_visible(
	layout: RoomLayout,
	room_id: StringName,
	current_room_id: StringName,
	cleared_room_ids: Dictionary
) -> bool:
	if room_id == current_room_id:
		return true
	return layout.is_room_visible(room_id, cleared_room_ids)


static func _empty_payload() -> Dictionary:
	return {
		"layout_id": &"",
		"current_room_id": &"",
		"rooms": [],
		"connections": [],
	}
