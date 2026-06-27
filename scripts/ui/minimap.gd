class_name Minimap
extends Control

const MinimapDataScript = preload("res://scripts/systems/minimap_data.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

const BOSS_ROOM_ICON_PATH := "res://assets/ui/minimap/boss_skull.png"
const START_ROOM_ICON_PATH := "res://assets/ui/minimap/nodes/start_home.png"
const COMBAT_ROOM_ICON_PATH := "res://assets/ui/minimap/nodes/combat_target.png"
const EVENT_ROOM_ICON_PATH := "res://assets/ui/minimap/nodes/event_info.png"
const TREASURE_ROOM_ICON_PATH := "res://assets/ui/minimap/nodes/treasure_key.png"
const SHOP_ROOM_ICON_PATH := "res://assets/ui/minimap/nodes/shop_trophy.png"
const BOSS_ROOM_ICON = preload(BOSS_ROOM_ICON_PATH)
const START_ROOM_ICON = preload(START_ROOM_ICON_PATH)
const COMBAT_ROOM_ICON = preload(COMBAT_ROOM_ICON_PATH)
const EVENT_ROOM_ICON = preload(EVENT_ROOM_ICON_PATH)
const TREASURE_ROOM_ICON = preload(TREASURE_ROOM_ICON_PATH)
const SHOP_ROOM_ICON = preload(SHOP_ROOM_ICON_PATH)
const GRAPH_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
]
const PANEL_COLOR := Color(0.035294, 0.047059, 0.070588, 0.78)
const PANEL_BORDER_COLOR := Color(0.145098, 0.172549, 0.219608, 0.9)
const UNKNOWN_ROOM_COLOR := Color(0.12549, 0.145098, 0.180392, 0.92)
const UNKNOWN_TEXT_COLOR := Color(0.564706, 0.615686, 0.694118, 1.0)
const CONNECTION_COLOR := Color(0.266667, 0.305882, 0.364706, 0.78)
const UNKNOWN_MINIMAP_TYPE := &"unknown"
const ROOM_GAP_MIN := 4.0
const ROOM_SIZE_MIN := Vector2(12.0, 12.0)

@export var room_size := Vector2(34.0, 34.0)
@export var cell_spacing := Vector2(44.0, 44.0)
@export var panel_padding := 12.0
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
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(196.0, 144.0)
	_connect_event_bus()
	set_process(true)
	if room_manager != null:
		configure_from_manager(room_manager)


func _process(_delta: float) -> void:
	if not _build_frontier_entries().is_empty():
		queue_redraw()


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


func get_frontier_draw_entries() -> Array[Dictionary]:
	return _build_frontier_entries()


func get_room_position(room_id: StringName) -> Vector2:
	if not _room_positions.has(room_id):
		return Vector2.ZERO
	return _grid_to_canvas(_room_positions[room_id])


func _draw() -> void:
	var canvas_size := _canvas_size()
	draw_rect(Rect2(Vector2.ZERO, canvas_size), PANEL_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, canvas_size), PANEL_BORDER_COLOR, false, 1.0)

	for connection: Dictionary in _build_connection_entries():
		var color := RoomPalette.MINIMAP_PING_COLOR if connection["frontier"] else CONNECTION_COLOR
		if connection["in_path"]:
			color = RoomPalette.DOOR_OPEN_COLOR
		if not connection["visible"]:
			color.a = 0.34
		draw_line(connection["from_position"], connection["to_position"], color, 3.0 if connection["frontier"] else 2.0)

	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var room_entries := _build_room_entries()
	for entry: Dictionary in room_entries:
		var rect: Rect2 = entry["rect"]
		if entry["frontier"]:
			var pulse := 0.55 + sin(float(Time.get_ticks_msec()) / 150.0) * 0.25
			var ping_color := RoomPalette.MINIMAP_PING_COLOR
			ping_color.a = pulse
			var ping_margin := maxf(2.0, minf(rect.size.x, rect.size.y) * 0.12)
			draw_rect(rect.grow(ping_margin), ping_color, false, 2.0)
		draw_rect(rect, entry["fill_color"], true)
		draw_rect(rect, entry["border_color"], false, entry["border_width"])
		var icon_texture := entry["icon_texture"] as Texture2D
		if icon_texture != null:
			var icon_margin := minf(rect.size.x, rect.size.y) * 0.18
			draw_texture_rect(icon_texture, rect.grow(-icon_margin), false, entry["icon_color"])
		elif entry["label"] != "":
			var label_font := maxi(8, int(minf(float(font_size), rect.size.y * 0.7)))
			draw_string(
				font,
				Vector2(rect.position.x, rect.position.y + rect.size.y * 0.66),
				entry["label"],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				label_font,
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
		var is_frontier := _is_frontier_room(room_id)
		var center := get_room_position(room_id)
		var draw_room_size := _effective_room_size()
		var rect := Rect2(center - draw_room_size * 0.5, draw_room_size)
		var actual_minimap_type := _minimap_type_for_room(room_def)
		var display_minimap_type := actual_minimap_type if room_visible else UNKNOWN_MINIMAP_TYPE
		var fill_color := _fill_color_for_room(room_def, room_visible, is_visited)
		var border_color := _border_color_for_room(is_current, is_cleared, is_problem)
		var icon_path := _icon_path_for_room(room_def, room_visible)
		var icon_texture := _icon_texture_for_room(room_def, room_visible)
		var label := "" if icon_texture != null else _label_for_room(room_def, room_visible)
		entries.append({
			"room_id": room_id,
			"room_type": room_def.room_type,
			"minimap_type": display_minimap_type,
			"actual_minimap_type": actual_minimap_type,
			"icon_path": icon_path,
			"icon_texture": icon_texture,
			"icon_color": Color.WHITE if room_visible else UNKNOWN_TEXT_COLOR,
			"hidden": room_def.hidden,
			"visible": room_visible,
			"layout_visible": _is_layout_visible(room_def),
			"current": is_current,
			"cleared": is_cleared,
			"visited": is_visited,
			"frontier": is_frontier,
			"ping": is_frontier,
			"problem": is_problem,
			"in_path": path_room_ids.has(room_id),
			"grid_pos": _room_positions.get(room_id, Vector2i.ZERO),
			"position": center,
			"rect": rect,
			"label": label,
			"fill_color": fill_color,
			"border_color": border_color,
			"border_width": 4.0 if is_current or is_problem else 2.0,
			"text_color": Color.WHITE if room_visible else UNKNOWN_TEXT_COLOR,
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
			var frontier := _is_frontier_connection(room_def.room_id, target_room_id)
			entries.append({
				"from_room_id": room_def.room_id,
				"to_room_id": target_room_id,
				"from_position": get_room_position(room_def.room_id),
				"to_position": get_room_position(target_room_id),
				"visible": _should_show_connection(room_def, target_room),
				"frontier": frontier,
				"in_path": _path_has_connection(room_def.room_id, target_room_id),
			})
	return entries


func _build_frontier_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if layout == null:
		return entries
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		var source_room_id := _frontier_source_for_room(room_def.room_id)
		if source_room_id == &"":
			continue
		var direction := _direction_between(source_room_id, room_def.room_id)
		var source_position := get_room_position(source_room_id)
		var target_position := get_room_position(room_def.room_id)
		entries.append({
			"room_id": room_def.room_id,
			"from_room_id": source_room_id,
			"direction": direction,
			"position": target_position,
			"from_position": source_position,
			"color": RoomPalette.MINIMAP_PING_COLOR,
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
	if _is_known_room(room_def.room_id):
		return true
	return false


func _is_layout_visible(room_def: RoomDef) -> bool:
	if layout == null:
		return false
	return layout.is_room_visible(room_def.room_id, cleared_room_ids)


func _is_known_room(room_id: StringName) -> bool:
	if room_id == &"":
		return false
	if room_id == current_room_id:
		return true
	if bool(visited_room_ids.get(room_id, false)):
		return true
	if bool(cleared_room_ids.get(room_id, false)):
		return true
	return layout != null and room_id == layout.start_room_id


func _is_frontier_room(room_id: StringName) -> bool:
	return _frontier_source_for_room(room_id) != &""


func _frontier_source_for_room(room_id: StringName) -> StringName:
	if layout == null or _is_known_room(room_id):
		return &""
	var room_def := layout.get_room(room_id)
	if room_def == null:
		return &""
	if not _is_layout_visible(room_def):
		return &""
	if current_room_id == &"" or not bool(cleared_room_ids.get(current_room_id, false)):
		return &""
	var source_room := layout.get_room(current_room_id)
	if source_room == null:
		return &""
	if source_room.connections.has(room_id) or room_def.connections.has(current_room_id):
		return current_room_id
	return &""


func _is_frontier_connection(first_room_id: StringName, second_room_id: StringName) -> bool:
	return (
		_frontier_source_for_room(first_room_id) == second_room_id
		or _frontier_source_for_room(second_room_id) == first_room_id
	)


func _should_show_connection(first_room: RoomDef, second_room: RoomDef) -> bool:
	return (
		_is_room_visible(first_room)
		or _is_room_visible(second_room)
		or _is_frontier_connection(first_room.room_id, second_room.room_id)
	)


func _minimap_type_for_room(room_def: RoomDef) -> StringName:
	var room_entry: Dictionary = _minimap_rooms_by_id.get(room_def.room_id, {})
	if not room_entry.is_empty():
		return StringName(room_entry.get("minimap_type", room_def.room_type))
	if room_def.room_type == RoomLayout.TYPE_FINAL:
		return &"boss"
	return room_def.room_type


func _fill_color_for_room(room_def: RoomDef, room_visible: bool, is_visited: bool) -> Color:
	if not room_visible:
		return UNKNOWN_ROOM_COLOR
	var color := _color_for_minimap_type(_minimap_type_for_room(room_def))
	if not is_visited:
		color = color.darkened(0.42)
		color.a = 0.82
	return color


func _border_color_for_room(is_current: bool, is_cleared: bool, is_problem: bool) -> Color:
	if is_problem:
		return RoomPalette.ACTIVITY_ROOM_FLOOR_COLOR
	if is_current:
		return Color.WHITE
	if is_cleared:
		return RoomPalette.STUDENT_MARKER_COLOR
	return Color(0.247059, 0.286275, 0.34902, 1.0)


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
		RoomLayout.TYPE_TREASURE:
			return "T"
		RoomLayout.TYPE_SHOP:
			return "$"
	return ""


func _color_for_minimap_type(minimap_type: StringName) -> Color:
	if minimap_type == &"boss":
		return RoomPalette.FINAL_ROOM_FLOOR_COLOR
	return RoomPalette.get_room_floor_color(minimap_type)


func _icon_texture_for_room(room_def: RoomDef, room_visible: bool) -> Texture2D:
	if not room_visible:
		return null
	match _minimap_type_for_room(room_def):
		RoomLayout.TYPE_START:
			return START_ROOM_ICON
		RoomLayout.TYPE_COMBAT:
			return COMBAT_ROOM_ICON
		RoomLayout.TYPE_EVENT, RoomLayout.TYPE_FRIEND:
			return EVENT_ROOM_ICON
		RoomLayout.TYPE_TREASURE:
			return TREASURE_ROOM_ICON
		RoomLayout.TYPE_SHOP:
			return SHOP_ROOM_ICON
		&"boss":
			return BOSS_ROOM_ICON
	return null


func _icon_path_for_room(room_def: RoomDef, room_visible: bool) -> String:
	if not room_visible:
		return ""
	match _minimap_type_for_room(room_def):
		RoomLayout.TYPE_START:
			return START_ROOM_ICON_PATH
		RoomLayout.TYPE_COMBAT:
			return COMBAT_ROOM_ICON_PATH
		RoomLayout.TYPE_EVENT, &"friend":
			return EVENT_ROOM_ICON_PATH
		RoomLayout.TYPE_TREASURE:
			return TREASURE_ROOM_ICON_PATH
		RoomLayout.TYPE_SHOP:
			return SHOP_ROOM_ICON_PATH
		&"boss":
			return BOSS_ROOM_ICON_PATH
	return ""


func _derive_room_positions() -> Dictionary:
	var grid_positions := _positions_from_room_grid()
	if not grid_positions.is_empty():
		return grid_positions
	return _derive_graph_positions()


func _positions_from_room_grid() -> Dictionary:
	var positions := {}
	if layout == null or layout.get_start_room() == null:
		return positions
	var occupied := {}
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		if occupied.has(room_def.grid_pos):
			return {}
		positions[room_def.room_id] = room_def.grid_pos
		occupied[room_def.grid_pos] = room_def.room_id
	if positions.size() != layout.room_defs.size():
		return {}
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		for connected_room_id: StringName in room_def.connections:
			if not positions.has(connected_room_id):
				return {}
			var connected_position: Vector2i = positions[connected_room_id]
			var grid_distance := (
				absi(room_def.grid_pos.x - connected_position.x)
				+ absi(room_def.grid_pos.y - connected_position.y)
			)
			if grid_distance != 1:
				return {}
	return positions


func _derive_graph_positions() -> Dictionary:
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
	var draw_room_size := _effective_room_size()
	var step := _effective_cell_spacing(draw_room_size)
	var map_size := Vector2(
		(grid_size.x - 1.0) * step.x + draw_room_size.x,
		(grid_size.y - 1.0) * step.y + draw_room_size.y
	)
	var origin := (_canvas_size() - map_size) * 0.5 + draw_room_size * 0.5
	var relative := Vector2(grid_position - min_position)
	return origin + relative * step


func _effective_room_size() -> Vector2:
	var bounds := _grid_bounds()
	var min_position: Vector2i = bounds["min"]
	var max_position: Vector2i = bounds["max"]
	var grid_size := Vector2(max_position - min_position + Vector2i.ONE)
	var available := _canvas_size() - Vector2(panel_padding * 2.0, panel_padding * 2.0)
	var max_width := room_size.x
	var max_height := room_size.y
	if grid_size.x > 1.0:
		max_width = minf(max_width, (available.x - ROOM_GAP_MIN * (grid_size.x - 1.0)) / grid_size.x)
	else:
		max_width = minf(max_width, available.x)
	if grid_size.y > 1.0:
		max_height = minf(max_height, (available.y - ROOM_GAP_MIN * (grid_size.y - 1.0)) / grid_size.y)
	else:
		max_height = minf(max_height, available.y)
	var room_scale := minf(minf(max_width / room_size.x, max_height / room_size.y), 1.0)
	return Vector2(
		maxf(room_size.x * room_scale, ROOM_SIZE_MIN.x),
		maxf(room_size.y * room_scale, ROOM_SIZE_MIN.y)
	)


func _effective_cell_spacing(draw_room_size: Vector2) -> Vector2:
	var bounds := _grid_bounds()
	var min_position: Vector2i = bounds["min"]
	var max_position: Vector2i = bounds["max"]
	var grid_size := Vector2(max_position - min_position + Vector2i.ONE)
	var available := _canvas_size() - Vector2(panel_padding * 2.0, panel_padding * 2.0)
	var step := cell_spacing
	if grid_size.x > 1.0:
		step.x = minf(
			cell_spacing.x,
			maxf(draw_room_size.x + ROOM_GAP_MIN, (available.x - draw_room_size.x) / (grid_size.x - 1.0))
		)
	if grid_size.y > 1.0:
		step.y = minf(
			cell_spacing.y,
			maxf(draw_room_size.y + ROOM_GAP_MIN, (available.y - draw_room_size.y) / (grid_size.y - 1.0))
		)
	return step


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


func _canvas_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	return custom_minimum_size


func _direction_between(from_room_id: StringName, to_room_id: StringName) -> StringName:
	if not _room_positions.has(from_room_id) or not _room_positions.has(to_room_id):
		return &""
	var delta: Vector2i = _room_positions[to_room_id] - _room_positions[from_room_id]
	if delta == Vector2i(1, 0):
		return &"E"
	if delta == Vector2i(-1, 0):
		return &"W"
	if delta == Vector2i(0, 1):
		return &"S"
	if delta == Vector2i(0, -1):
		return &"N"
	return &""


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
