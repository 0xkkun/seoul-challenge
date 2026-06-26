extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_minimap_marks_current_cleared_adjacent_unknown_and_hidden_rooms() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"start", {&"start": true})

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_eq(entries.size(), 5, "minimap draws all graph rooms")
	_runner.assert_true(entries[&"start"]["current"], "current room is highlighted")
	_runner.assert_true(entries[&"start"]["cleared"], "cleared room is marked")
	_runner.assert_false(entries[&"combat_1"]["visited"], "uncleared adjacent room starts unvisited")
	_runner.assert_false(entries[&"combat_1"]["visible"], "adjacent room stays fogged until visited")
	_runner.assert_eq(entries[&"combat_1"]["minimap_type"], &"unknown", "fogged adjacent room hides its type")
	_runner.assert_eq(entries[&"combat_1"]["actual_minimap_type"], &"combat", "draw entry keeps source type for diagnostics")
	_runner.assert_eq(entries[&"combat_1"]["label"], "?", "fogged adjacent room uses unknown label")
	_runner.assert_false(entries[&"treasure_1"]["visible"], "non-adjacent treasure starts unknown")
	_runner.assert_eq(entries[&"treasure_1"]["minimap_type"], &"unknown", "non-adjacent treasure hides its type")
	_runner.assert_eq(entries[&"treasure_1"]["label"], "?", "unknown room uses question label")
	_runner.assert_false(entries[&"final_1"]["visible"], "hidden boss starts hidden")
	_runner.assert_eq(entries[&"final_1"]["minimap_type"], &"unknown", "hidden boss hides its type")
	_runner.assert_eq(entries[&"final_1"]["actual_minimap_type"], &"boss", "source boss type remains available for diagnostics")
	_runner.assert_eq(entries[&"final_1"]["label"], "?", "hidden boss uses unknown label")
	_runner.assert_eq(entries[&"final_1"]["icon_path"], "", "hidden boss does not expose its boss icon")


func test_minimap_keeps_boss_unknown_until_explicit_reveal() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"event_1", {
		&"start": true,
		&"combat_1": true,
		&"treasure_1": true,
		&"event_1": true,
	})

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_false(entries[&"final_1"]["visible"], "boss stays unknown even when reachable")
	_runner.assert_eq(entries[&"final_1"]["label"], "?", "reachable boss still uses unknown label")
	_runner.assert_eq(entries[&"final_1"]["icon_path"], "", "reachable hidden boss still hides its icon")

	var frontier := _frontier_by_room_id(minimap.get_frontier_draw_entries())
	_runner.assert_true(frontier.has(&"final_1"), "reachable hidden boss is still pinged")
	_runner.assert_eq(frontier[&"final_1"]["from_room_id"], &"event_1", "boss ping points from the open exit")

	minimap.set_reveal_hidden_rooms(true)
	entries = _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_true(entries[&"final_1"]["visible"], "explicit reveal shows boss room")
	_runner.assert_eq(entries[&"final_1"]["minimap_type"], &"boss", "revealed boss exposes boss type")
	_runner.assert_eq(entries[&"final_1"]["label"], "", "revealed boss replaces text label with icon")
	_runner.assert_eq(
		entries[&"final_1"]["icon_path"],
		Minimap.BOSS_ROOM_ICON_PATH,
		"revealed boss uses the skull boss icon"
	)
	_runner.assert_not_null(entries[&"final_1"]["icon_texture"], "revealed boss icon texture is loaded")


func test_minimap_uses_minimap_data_types_for_special_rooms() -> void:
	var minimap := Minimap.new()
	var layout := _create_shop_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"shop_1", {&"start": true, &"treasure_1": true})

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_true(entries[&"treasure_1"]["visible"], "cleared treasure room is visible on minimap")
	_runner.assert_eq(entries[&"treasure_1"]["minimap_type"], &"treasure", "treasure minimap type is preserved")
	_runner.assert_eq(entries[&"treasure_1"]["label"], "T", "treasure room uses treasure label")
	_runner.assert_true(entries[&"shop_1"]["visible"], "current shop room is visible on minimap")
	_runner.assert_eq(entries[&"shop_1"]["minimap_type"], &"shop", "shop minimap type is preserved")
	_runner.assert_eq(entries[&"shop_1"]["label"], "$", "shop room uses shop label")
	_runner.assert_eq(entries[&"final_1"]["minimap_type"], &"unknown", "unvisited final room hides boss type")
	_runner.assert_false(entries[&"final_1"]["visible"], "hidden boss stays hidden")
	_runner.assert_eq(entries[&"final_1"]["label"], "?", "hidden boss remains unknown")
	_runner.assert_eq(entries[&"final_1"]["icon_path"], "", "hidden boss does not expose its boss icon")


func test_minimap_frontier_ping_tracks_current_and_cleared_connections() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"start", {&"start": true})

	var frontier := _frontier_by_room_id(minimap.get_frontier_draw_entries())
	_runner.assert_eq(frontier.size(), 1, "only the start exit is initially pinged")
	_runner.assert_eq(frontier[&"combat_1"]["from_room_id"], &"start", "ping starts from current room")
	_runner.assert_eq(frontier[&"combat_1"]["direction"], &"E", "ping keeps grid direction")
	_runner.assert_eq(frontier[&"combat_1"]["arrow"], ">", "east ping uses arrow")

	minimap.set_current_room(&"combat_1")
	minimap.set_cleared_rooms({&"start": true, &"combat_1": true})

	frontier = _frontier_by_room_id(minimap.get_frontier_draw_entries())
	_runner.assert_false(frontier.has(&"start"), "known room is not pinged")
	_runner.assert_true(frontier.has(&"treasure_1"), "uncleared treasure exit is pinged")
	_runner.assert_true(frontier.has(&"event_1"), "uncleared event exit is pinged")
	_runner.assert_eq(frontier[&"treasure_1"]["from_room_id"], &"combat_1", "treasure ping points from open room")

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_true(entries[&"treasure_1"]["frontier"], "frontier room draw entry is marked")
	_runner.assert_false(entries[&"treasure_1"]["visible"], "frontier treasure stays fogged before visit")
	_runner.assert_eq(entries[&"treasure_1"]["minimap_type"], &"unknown", "frontier treasure hides its type")
	_runner.assert_eq(entries[&"treasure_1"]["label"], "?", "frontier treasure uses unknown label")
	_runner.assert_eq(entries[&"treasure_1"]["fill_color"], Minimap.UNKNOWN_ROOM_COLOR, "frontier uses fog palette")


func test_minimap_updates_from_event_bus_room_events() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)
	minimap.set_layout(layout, &"start")

	EventBus.emit_room_entered({"room_id": &"combat_1"})
	EventBus.emit_room_cleared({"room_id": &"combat_1"})

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_true(entries[&"combat_1"]["current"], "room entered event updates current room")
	_runner.assert_true(entries[&"combat_1"]["cleared"], "room cleared event updates cleared state")
	_runner.assert_true(entries[&"combat_1"]["visited"], "event updates visited state")


func test_minimap_refreshes_layout_from_room_manager_changes() -> void:
	var minimap := Minimap.new()
	var manager := RoomManager.new()
	var first_layout := _create_linear_layout(&"first_layout", &"first_start", &"first_final")
	var second_layout := _create_linear_layout(&"second_layout", &"second_start", &"second_final")
	add_child(minimap)

	manager.layout = first_layout
	manager.current_room_id = &"first_start"
	minimap.configure_from_manager(manager)
	manager.layout = second_layout
	manager.current_room_id = &"second_start"
	manager.room_changed.emit(&"second_start", RoomLayout.TYPE_START)

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_false(entries.has(&"first_start"), "stale manager layout rooms are removed")
	_runner.assert_true(entries.has(&"second_start"), "new manager layout rooms are drawn")
	_runner.assert_true(entries[&"second_start"]["current"], "new manager current room is highlighted")
	minimap.configure_from_manager(null)
	manager.free()


func test_minimap_connection_entries_are_deduplicated_and_path_marked() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)
	minimap.set_layout(layout, &"start")
	minimap.set_path_room_ids([&"start", &"combat_1", &"event_1", &"final_1"])

	var connections := minimap.get_connection_draw_entries()
	var path_count := 0
	for connection: Dictionary in connections:
		if connection["in_path"]:
			path_count += 1

	_runner.assert_eq(connections.size(), 4, "bidirectional room graph draws each edge once")
	_runner.assert_eq(path_count, 3, "path highlights start-to-boss edges")


func test_minimap_uses_room_grid_positions_without_overlap() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)
	minimap.custom_minimum_size = Vector2(240.0, 180.0)
	minimap.set_layout(layout, &"start")

	var occupied := {}
	for entry: Dictionary in minimap.get_room_draw_entries():
		var grid_pos: Vector2i = entry["grid_pos"]
		_runner.assert_false(occupied.has(grid_pos), "grid position is unique")
		occupied[grid_pos] = entry["room_id"]

	_runner.assert_eq(occupied[Vector2i.ZERO], &"start", "start room is normalized to grid origin")

	for connection: Dictionary in minimap.get_connection_draw_entries():
		var from_position: Vector2 = connection["from_position"]
		var to_position: Vector2 = connection["to_position"]
		var same_x := is_equal_approx(from_position.x, to_position.x)
		var same_y := is_equal_approx(from_position.y, to_position.y)
		_runner.assert_true(same_x != same_y, "grid connections render as straight orthogonal lines")


func test_minimap_handles_fifteen_room_generated_layout() -> void:
	var minimap := Minimap.new()
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 15})
	add_child(minimap)
	minimap.custom_minimum_size = Vector2(520.0, 420.0)
	minimap.set_layout(layout, layout.start_room_id, {layout.start_room_id: true})

	var entries := minimap.get_room_draw_entries()
	_runner.assert_eq(entries.size(), 15, "minimap draws every generated room")
	_runner.assert_true(minimap.get_frontier_draw_entries().size() > 0, "large generated layout exposes frontier pings")

	var occupied := {}
	var fogged_count := 0
	for entry: Dictionary in entries:
		var grid_pos: Vector2i = entry["grid_pos"]
		_runner.assert_false(occupied.has(grid_pos), "generated minimap grid position is unique")
		occupied[grid_pos] = entry["room_id"]
		if not entry["visited"]:
			fogged_count += 1
			_runner.assert_false(entry["visible"], "unvisited generated room stays fogged")
			_runner.assert_eq(entry["minimap_type"], &"unknown", "unvisited generated room hides its type")
			_runner.assert_eq(entry["label"], "?", "unvisited generated room uses unknown label")

	_runner.assert_eq(fogged_count, 14, "only the start room is known initially")

	for connection: Dictionary in minimap.get_connection_draw_entries():
		var from_position: Vector2 = connection["from_position"]
		var to_position: Vector2 = connection["to_position"]
		var same_x := is_equal_approx(from_position.x, to_position.x)
		var same_y := is_equal_approx(from_position.y, to_position.y)
		_runner.assert_true(same_x != same_y, "large generated layout connections remain orthogonal")


func _entries_by_room_id(entries: Array[Dictionary]) -> Dictionary:
	var by_id := {}
	for entry: Dictionary in entries:
		by_id[entry["room_id"]] = entry
	return by_id


func _frontier_by_room_id(entries: Array[Dictionary]) -> Dictionary:
	var by_id := {}
	for entry: Dictionary in entries:
		by_id[entry["room_id"]] = entry
	return by_id


func _create_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = &"minimap_test"
	layout.start_room_id = &"start"
	layout.room_defs = [
		_create_room_def(&"start", RoomLayout.TYPE_START, [&"combat_1"], Vector2i(0, 0)),
		_create_room_def(&"combat_1", RoomLayout.TYPE_COMBAT, [&"start", &"treasure_1", &"event_1"], Vector2i(1, 0)),
		_create_room_def(&"treasure_1", RoomLayout.TYPE_TREASURE, [&"combat_1"], Vector2i(2, 0)),
		_create_room_def(&"event_1", RoomLayout.TYPE_EVENT, [&"combat_1", &"final_1"], Vector2i(1, 1)),
		_create_room_def(&"final_1", RoomLayout.TYPE_FINAL, [&"event_1"], Vector2i(1, 2), true),
	]
	return layout


func _create_linear_layout(layout_id: StringName, start_room_id: StringName, final_room_id: StringName) -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = layout_id
	layout.start_room_id = start_room_id
	layout.room_defs = [
		_create_room_def(start_room_id, RoomLayout.TYPE_START, [final_room_id], Vector2i(0, 0)),
		_create_room_def(final_room_id, RoomLayout.TYPE_FINAL, [start_room_id], Vector2i(1, 0), true),
	]
	return layout


func _create_shop_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = &"minimap_shop_test"
	layout.start_room_id = &"start"
	layout.room_defs = [
		_create_room_def(&"start", RoomLayout.TYPE_START, [&"treasure_1"], Vector2i(0, 0)),
		_create_room_def(&"treasure_1", RoomLayout.TYPE_TREASURE, [&"start", &"shop_1"], Vector2i(1, 0)),
		_create_room_def(&"shop_1", RoomLayout.TYPE_SHOP, [&"treasure_1", &"final_1"], Vector2i(2, 0)),
		_create_room_def(&"final_1", RoomLayout.TYPE_FINAL, [&"shop_1"], Vector2i(3, 0), true),
	]
	return layout


func _create_room_def(
	room_id: StringName,
	room_type: StringName,
	connections: Array[StringName],
	grid_pos: Vector2i,
	hidden := false
) -> RoomDef:
	var room_def := RoomDef.new()
	room_def.room_id = room_id
	room_def.room_type = room_type
	room_def.scene_path = "res://scenes/session/room_base.tscn"
	room_def.connections = connections
	room_def.grid_pos = grid_pos
	room_def.hidden = hidden
	return room_def
