class_name Minimap
extends Control

const MinimapDataScript = preload("res://scripts/systems/minimap_data.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

const GRAPH_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]

@export var room_size := Vector2(34.0, 26.0)
@export var cell_spacing := Vector2(64.0, 48.0)
@export var show_hidden_as_unknown := true

var layout: RoomLayout
var room_manager: RoomManager
var current_room_id: StringName = &""
var cleared_room_ids := {}
var visited_room_ids := {}
var reveal_hidden_rooms := false
var path_room_ids: Array[StringName] = []
var problem_room_ids := {}

var _room_positions := {}
var _minimap_data := {}
var _minimap_rooms_by_id := {}


func _ready() -> void:
	custom_minimum_size = Vector2(300.0, 220.0)
	_connect_event_bus()
	if room_manager != null:
		configure_from_manager(room_manager)


func _exit_tree() -> void:
	_disconnect_event_bus()
	if room_manager != null and room_manager.room_changed.is_connected(_on_manager_room_changed):
		room_manager.room_changed.disconnect(_on_manager_room_changed)


func configure_from_manager(manager: RoomManager) -> void:
	if room_manager != null and room_manager.room_changed.is_connected(_on_manager_room_changed):
		room_manager.room_changed.disconnect(_on_manager_room_changed)
	room_manager = manager
	if room_manager == null:
		return
	if not room_manager.room_changed.is_connected(_on_manager_room_changed):
		room_manager.room_changed.connect(_on_manager_room_changed)
	set_layout(room_manager.layout, room_manager.current_room_id, room_manager.cleared_room_ids)


func set_layout(next_layout: RoomLayout, next_current_room_id: StringName = &"", next_cleared_room_ids: Dictionary = {}) -> void:
	layout = next_layout
	current_room_id = next_current_room_id
	cleared_room_ids = next_cleared_room_ids.duplicate(true)
	visited_room_ids.clear()
	for room_id: Variant in cleared_room_ids.keys():
		visited_room_ids[StringName(room_id)] = true
	if current_room_id != &"":
		visited_room_ids[current_room_id] = true
	_refresh_minimap_data()
	_room_positions = _derive_room_positions()
	queue_redraw()


func set_current_room(room_id: StringName) -> void:
	current_room_id = room_id
	if current_room_id != &"":
		visited_room_ids[current_room_id] = true
	_refresh_minimap_data()
	queue_redraw()


func set_cleared_rooms(next_cleared_room_ids: Dictionary) -> void:
	cleared_room_ids = next_cleared_room_ids.duplicate(true)
	for room_id: Variant in cleared_room_ids.keys():
		visited_room_ids[StringName(room_id)] = true
	_refresh_minimap_data()
	queue_redraw()


func set_reveal_hidden_rooms(should_reveal: bool) -> void:
	reveal_hidden_rooms = should_reveal
	queue_redraw()


func set_path_room_ids(next_path_room_ids: Array[StringName]) -> void:
	path_room_ids = next_path_room_ids.duplicate()
	queue_redraw()


func set_problem_room_ids(next_problem_room_ids: Dictionary) -> void:
	problem_room_ids = next_problem_room_ids.duplicate(true)
	queue_redraw()


func get_room_draw_entries() -> Array[Dictionary]:
	return _build_room_entries()


func get_connection_draw_entries() -> Array[Dictionary]:
	return _build_connection_entries()


func get_room_position(room_id: StringName) -> Vector2:
	if not _room_positions.has(room_id):
		return Vector2.ZERO
	return _grid_to_canvas(_room_positions[room_id])


func _draw() -> void:
	for connection: Dictionary in _build_connection_entries():
		var color := RoomPalette.DOOR_OPEN_COLOR if connection["in_path"] else RoomPalette.DOOR_LOCKED_COLOR
		if not connection["visible"]:
			color.a = 0.45
		draw_line(connection["from_position"], connection["to_position"], color, 3.0 if connection["in_path"] else 2.0)

	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	for entry: Dictionary in _build_room_entries():
		var center: Vector2 = entry["position"]
		var rect := Rect2(center - room_size * 0.5, room_size)
		draw_rect(rect, entry["fill_color"], true)
		draw_rect(rect, entry["border_color"], false, entry["border_width"])
		if entry["label"] != "":
			draw_string(
				font,
				Vector2(rect.position.x, rect.position.y + room_size.y * 0.68),
				entry["label"],
				HORIZONTAL_ALIGNMENT_CENTER,
				room_size.x,
				font_size,
				entry["text_color"]
			)


func _build_room_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if layout == null:
		return entries

	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		var room_id := room_def.room_id
		var room_visible := _is_room_visible(room_def)
		var is_current := room_id == current_room_id
		var is_cleared := bool(cleared_room_ids.get(room_id, false))
		var is_visited := bool(visited_room_ids.get(room_id, false)) or is_cleared or is_current
		var is_problem := bool(problem_room_ids.get(room_id, false))
		var fill_color := _fill_color_for_room(room_def, room_visible, is_visited)
		var border_color := _border_color_for_room(is_current, is_cleared, is_problem)
		var label := _label_for_room(room_def, room_visible)
		entries.append({
			"room_id": room_id,
			"room_type": room_def.room_type,
			"minimap_type": _minimap_type_for_room(room_def),
			"hidden": room_def.hidden,
			"visible": room_visible,
			"layout_visible": _is_layout_visible(room_def),
			"current": is_current,
			"cleared": is_cleared,
			"visited": is_visited,
			"problem": is_problem,
			"in_path": path_room_ids.has(room_id),
			"position": get_room_position(room_id),
			"label": label,
			"fill_color": fill_color,
			"border_color": border_color,
			"border_width": 4.0 if is_current or is_problem else 2.0,
			"text_color": Color.WHITE if room_visible else RoomPalette.REWARD_ROOM_FLOOR_COLOR,
		})
	return entries


func _build_connection_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if layout == null:
		return entries

	var seen := {}
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		for target_room_id: StringName in room_def.connections:
			var target_room := layout.get_room(target_room_id)
			if target_room == null:
				continue
			var key := _connection_key(room_def.room_id, target_room_id)
			if seen.has(key):
				continue
			seen[key] = true
			entries.append({
				"from_room_id": room_def.room_id,
				"to_room_id": target_room_id,
				"from_position": get_room_position(room_def.room_id),
				"to_position": get_room_position(target_room_id),
				"visible": _is_room_visible(room_def) or _is_room_visible(target_room),
				"in_path": _path_has_connection(room_def.room_id, target_room_id),
			})
	return entries


func _connect_event_bus() -> void:
	if not has_node("/root/EventBus"):
		return
	if not EventBus.room_entered.is_connected(_on_event_bus_room_entered):
		EventBus.room_entered.connect(_on_event_bus_room_entered)
	if not EventBus.room_cleared.is_connected(_on_event_bus_room_cleared):
		EventBus.room_cleared.connect(_on_event_bus_room_cleared)


func _disconnect_event_bus() -> void:
	if not has_node("/root/EventBus"):
		return
	if EventBus.room_entered.is_connected(_on_event_bus_room_entered):
		EventBus.room_entered.disconnect(_on_event_bus_room_entered)
	if EventBus.room_cleared.is_connected(_on_event_bus_room_cleared):
		EventBus.room_cleared.disconnect(_on_event_bus_room_cleared)


func _on_event_bus_room_entered(payload: Dictionary) -> void:
	var room_id := StringName(payload.get("room_id", &""))
	if room_id == &"":
		return
	set_current_room(room_id)


func _on_event_bus_room_cleared(payload: Dictionary) -> void:
	var room_id := StringName(payload.get("room_id", &""))
	if room_id == &"":
		return
	cleared_room_ids[room_id] = true
	visited_room_ids[room_id] = true
	_refresh_minimap_data()
	queue_redraw()


func _on_manager_room_changed(room_id: StringName, _room_type: StringName) -> void:
	if room_manager != null:
		set_layout(room_manager.layout, room_id, room_manager.cleared_room_ids)
	else:
		set_current_room(room_id)


func _refresh_minimap_data() -> void:
	_minimap_data.clear()
	_minimap_rooms_by_id.clear()
	if layout == null:
		return
	_minimap_data = MinimapDataScript.build_from_layout(layout, current_room_id, cleared_room_ids)
	var rooms: Array = _minimap_data.get("rooms", [])
	for room_entry: Variant in rooms:
		if room_entry is Dictionary:
			_minimap_rooms_by_id[room_entry.get("room_id", &"")] = room_entry


func _is_room_visible(room_def: RoomDef) -> bool:
	if room_def == null:
		return false
	if reveal_hidden_rooms:
		return true
	return _is_layout_visible(room_def)


func _is_layout_visible(room_def: RoomDef) -> bool:
	var room_entry: Dictionary = _minimap_rooms_by_id.get(room_def.room_id, {})
	if not room_entry.is_empty():
		return bool(room_entry.get("visible", false))
	if layout == null:
		return false
	return layout.is_room_visible(room_def.room_id, cleared_room_ids)


func _minimap_type_for_room(room_def: RoomDef) -> StringName:
	var room_entry: Dictionary = _minimap_rooms_by_id.get(room_def.room_id, {})
	if not room_entry.is_empty():
		return StringName(room_entry.get("minimap_type", room_def.room_type))
	if room_def.room_type == RoomLayout.TYPE_FINAL:
		return &"boss"
	return room_def.room_type


func _fill_color_for_room(room_def: RoomDef, room_visible: bool, is_visited: bool) -> Color:
	var color := RoomPalette.DOOR_LOCKED_COLOR if not room_visible else _color_for_minimap_type(_minimap_type_for_room(room_def))
	if not room_visible:
		color.a = 0.9
		return color
	if not is_visited:
		color = color.darkened(0.45)
		color.a = 0.65
	return color


func _border_color_for_room(is_current: bool, is_cleared: bool, is_problem: bool) -> Color:
	if is_problem:
		return RoomPalette.ACTIVITY_ROOM_FLOOR_COLOR
	if is_current:
		return RoomPalette.DOOR_OPEN_COLOR
	if is_cleared:
		return RoomPalette.STUDENT_MARKER_COLOR
	return RoomPalette.DOOR_LOCKED_COLOR


func _label_for_room(room_def: RoomDef, room_visible: bool) -> String:
	if show_hidden_as_unknown and not room_visible:
		return "?"
	match _minimap_type_for_room(room_def):
		RoomLayout.TYPE_START:
			return "S"
		RoomLayout.TYPE_COMBAT:
			return "C"
		RoomLayout.TYPE_EVENT:
			return "E"
		&"boss":
			return "B"
		&"treasure":
			return "T"
		&"shop":
			return "$"
	return ""


func _color_for_minimap_type(minimap_type: StringName) -> Color:
	if minimap_type == &"shop":
		return RoomPalette.REWARD_ROOM_FLOOR_COLOR.lightened(0.18)
	if minimap_type == &"boss":
		return RoomPalette.FINAL_ROOM_FLOOR_COLOR
	return RoomPalette.get_room_floor_color(minimap_type)


func _derive_room_positions() -> Dictionary:
	var positions := {}
	if layout == null or layout.get_start_room() == null:
		return positions

	var occupied := {}
	var start_room_id := layout.start_room_id
	positions[start_room_id] = Vector2i.ZERO
	occupied[Vector2i.ZERO] = start_room_id

	var queue: Array[StringName] = [start_room_id]
	var cursor := 0
	while cursor < queue.size():
		var room_id := queue[cursor]
		cursor += 1
		var room_def := layout.get_room(room_id)
		if room_def == null:
			continue
		var base_position: Vector2i = positions[room_id]
		for index: int in range(room_def.connections.size()):
			var connected_room_id := room_def.connections[index]
			if positions.has(connected_room_id):
				continue
			var target_position := base_position + GRAPH_DIRECTIONS[index % GRAPH_DIRECTIONS.size()]
			target_position = _find_free_position_near(target_position, base_position, occupied)
			positions[connected_room_id] = target_position
			occupied[target_position] = connected_room_id
			queue.append(connected_room_id)

	return positions


func _find_free_position_near(preferred: Vector2i, origin: Vector2i, occupied: Dictionary) -> Vector2i:
	if not occupied.has(preferred):
		return preferred
	for radius: int in range(1, 8):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				if abs(x) != radius and abs(y) != radius:
					continue
				var candidate := origin + Vector2i(x, y)
				if not occupied.has(candidate):
					return candidate
	return preferred


func _grid_to_canvas(grid_position: Vector2i) -> Vector2:
	var bounds := _grid_bounds()
	var min_position: Vector2i = bounds["min"]
	var max_position: Vector2i = bounds["max"]
	var grid_size := Vector2(max_position - min_position + Vector2i.ONE)
	var map_size := Vector2(
		maxf(grid_size.x * cell_spacing.x, room_size.x),
		maxf(grid_size.y * cell_spacing.y, room_size.y)
	)
	var origin := (size - map_size) * 0.5 + room_size
	var relative := Vector2(grid_position - min_position)
	return origin + relative * cell_spacing


func _grid_bounds() -> Dictionary:
	var min_position := Vector2i.ZERO
	var max_position := Vector2i.ZERO
	var first := true
	for grid_position: Vector2i in _room_positions.values():
		if first:
			min_position = grid_position
			max_position = grid_position
			first = false
		else:
			min_position.x = mini(min_position.x, grid_position.x)
			min_position.y = mini(min_position.y, grid_position.y)
			max_position.x = maxi(max_position.x, grid_position.x)
			max_position.y = maxi(max_position.y, grid_position.y)
	return {"min": min_position, "max": max_position}


func _path_has_connection(from_room_id: StringName, to_room_id: StringName) -> bool:
	for index: int in range(path_room_ids.size() - 1):
		var first := path_room_ids[index]
		var second := path_room_ids[index + 1]
		if first == from_room_id and second == to_room_id:
			return true
		if first == to_room_id and second == from_room_id:
			return true
	return false


func _connection_key(first: StringName, second: StringName) -> String:
	var first_text := String(first)
	var second_text := String(second)
	if first_text < second_text:
		return "%s:%s" % [first_text, second_text]
	return "%s:%s" % [second_text, first_text]
