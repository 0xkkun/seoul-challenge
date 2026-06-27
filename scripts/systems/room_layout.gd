class_name RoomLayout
extends Resource

const TYPE_START := &"start"
const TYPE_COMBAT := &"combat"
const TYPE_EVENT := &"event"
const TYPE_FRIEND := &"friend"
const TYPE_FINAL := &"final"
const TYPE_TREASURE := &"treasure"
const TYPE_SHOP := &"shop"
const MIN_ROOM_COUNT := 5
const MAX_ROOM_COUNT := 64

@export var layout_id: StringName = &"layout"
@export var start_room_id: StringName = TYPE_START
@export var room_defs: Array[RoomDef] = []
@export var required_clears_for_hidden_reveal := 0
@export var allow_short_story_layout := false


func get_room(room_id: StringName) -> RoomDef:
	for room_def: RoomDef in room_defs:
		if room_def != null and room_def.room_id == room_id:
			return room_def
	return null


func has_room(room_id: StringName) -> bool:
	return get_room(room_id) != null


func get_start_room() -> RoomDef:
	return get_room(start_room_id)


func get_room_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for room_def: RoomDef in room_defs:
		if room_def != null:
			ids.append(room_def.room_id)
	return ids


func get_connected_room_ids(room_id: StringName) -> Array[StringName]:
	var room_def := get_room(room_id)
	if room_def == null:
		return []
	return room_def.connections.duplicate()


func get_visible_room_defs(cleared_room_ids: Dictionary = {}) -> Array[RoomDef]:
	var visible: Array[RoomDef] = []
	for room_def: RoomDef in room_defs:
		if room_def == null:
			continue
		if not room_def.hidden or can_reveal_hidden_rooms(cleared_room_ids):
			visible.append(room_def)
	return visible


func is_room_visible(room_id: StringName, cleared_room_ids: Dictionary = {}) -> bool:
	var room_def := get_room(room_id)
	if room_def == null:
		return false
	return not room_def.hidden or can_reveal_hidden_rooms(cleared_room_ids)


func can_reveal_hidden_rooms(cleared_room_ids: Dictionary = {}) -> bool:
	if required_clears_for_hidden_reveal > 0:
		return _cleared_non_hidden_room_count(cleared_room_ids) >= required_clears_for_hidden_reveal
	for room_def: RoomDef in room_defs:
		if room_def == null or room_def.hidden:
			continue
		if not _has_cleared_room(cleared_room_ids, room_def.room_id):
			return false
	return true


func get_next_room_id(
	from_room_id: StringName,
	cleared_room_ids: Dictionary = {},
	preferred_room_id: StringName = &""
) -> StringName:
	var from_room := get_room(from_room_id)
	if from_room == null:
		return &""

	if preferred_room_id != &"" and from_room.has_connection(preferred_room_id):
		if _can_enter_room(preferred_room_id, cleared_room_ids):
			return preferred_room_id

	for connected_room_id: StringName in from_room.connections:
		if not _can_enter_room(connected_room_id, cleared_room_ids):
			continue
		if not _has_cleared_room(cleared_room_ids, connected_room_id):
			return connected_room_id

	return &""


func validate_layout() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	var type_counts := {
		TYPE_START: 0,
		TYPE_COMBAT: 0,
		TYPE_EVENT: 0,
		TYPE_FRIEND: 0,
		TYPE_FINAL: 0,
		TYPE_TREASURE: 0,
		TYPE_SHOP: 0,
	}
	var rooms_by_id := {}
	var grid_positions := {}

	if not allow_short_story_layout and (room_defs.size() < MIN_ROOM_COUNT or room_defs.size() > MAX_ROOM_COUNT):
		errors.append("layout must contain %d to %d rooms" % [MIN_ROOM_COUNT, MAX_ROOM_COUNT])
	elif allow_short_story_layout and room_defs.size() < 1:
		errors.append("layout must contain at least one room")

	for room_def: RoomDef in room_defs:
		if room_def == null:
			errors.append("layout contains an empty room entry")
			continue
		if room_def.room_id == &"":
			errors.append("room id must not be empty")
		elif seen.has(room_def.room_id):
			errors.append("duplicate room id: %s" % room_def.room_id)
		else:
			seen[room_def.room_id] = true
			rooms_by_id[room_def.room_id] = room_def

		if grid_positions.has(room_def.grid_pos):
			errors.append("%s overlaps grid position with %s" % [room_def.room_id, grid_positions[room_def.grid_pos]])
		else:
			grid_positions[room_def.grid_pos] = room_def.room_id

		if room_def.scene_path == "":
			errors.append("%s scene path must not be empty" % room_def.room_id)

		if type_counts.has(room_def.room_type):
			type_counts[room_def.room_type] += 1
		else:
			errors.append("%s has unsupported room type: %s" % [room_def.room_id, room_def.room_type])

	for room_def: RoomDef in room_defs:
		if room_def == null:
			continue
		for connected_room_id: StringName in room_def.connections:
			if not seen.has(connected_room_id):
				errors.append("%s connects to missing room: %s" % [room_def.room_id, connected_room_id])
				continue
			var connected_room := rooms_by_id[connected_room_id] as RoomDef
			var grid_distance := (
				absi(room_def.grid_pos.x - connected_room.grid_pos.x)
				+ absi(room_def.grid_pos.y - connected_room.grid_pos.y)
			)
			if grid_distance != 1:
				errors.append("%s connects to non-adjacent room %s" % [room_def.room_id, connected_room_id])

	if not seen.has(start_room_id):
		errors.append("start room is missing: %s" % start_room_id)
	if type_counts[TYPE_START] != 1:
		errors.append("layout must contain exactly one start room")
	if not allow_short_story_layout and type_counts[TYPE_COMBAT] < 2:
		errors.append("layout must contain at least two combat rooms")
	if not allow_short_story_layout and type_counts[TYPE_EVENT] > 1:
		errors.append("layout must contain at most one event room")
	if not allow_short_story_layout and type_counts[TYPE_FINAL] != 1:
		errors.append("layout must contain exactly one final room")

	return errors


func _can_enter_room(room_id: StringName, cleared_room_ids: Dictionary) -> bool:
	var room_def := get_room(room_id)
	if room_def == null:
		return false
	if room_def.hidden and not can_reveal_hidden_rooms(cleared_room_ids):
		return false
	return true


func _has_cleared_room(cleared_room_ids: Dictionary, room_id: StringName) -> bool:
	return bool(cleared_room_ids.get(room_id, false))


func _cleared_non_hidden_room_count(cleared_room_ids: Dictionary) -> int:
	var count := 0
	for room_def: RoomDef in room_defs:
		if room_def == null or room_def.hidden:
			continue
		if _has_cleared_room(cleared_room_ids, room_def.room_id):
			count += 1
	return count
