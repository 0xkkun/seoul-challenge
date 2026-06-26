extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_minimap_marks_current_cleared_unvisited_and_hidden_rooms() -> void:
	var minimap := Minimap.new()
	var layout := _create_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"start", {&"start": true})

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_eq(entries.size(), 5, "minimap draws all graph rooms")
	_runner.assert_true(entries[&"start"]["current"], "current room is highlighted")
	_runner.assert_true(entries[&"start"]["cleared"], "cleared room is marked")
	_runner.assert_false(entries[&"combat_1"]["visited"], "uncleared adjacent room starts unvisited")
	_runner.assert_true(entries[&"combat_1"]["visible"], "adjacent room reveals its type")
	_runner.assert_eq(entries[&"combat_1"]["label"], "C", "adjacent combat room uses combat label")
	_runner.assert_true(entries[&"treasure_1"]["visible"], "treasure room is visible before visit")
	_runner.assert_eq(entries[&"treasure_1"]["label"], "T", "treasure room uses treasure label")
	_runner.assert_false(entries[&"final_1"]["visible"], "hidden boss starts hidden")
	_runner.assert_eq(entries[&"final_1"]["minimap_type"], &"boss", "minimap consumes boss type from minimap data")
	_runner.assert_eq(entries[&"final_1"]["label"], "?", "hidden boss uses unknown label")
	_runner.assert_eq(entries[&"final_1"]["text_color"], RoomPalette.REWARD_ROOM_FLOOR_COLOR, "hidden label uses hidden text color")


func test_minimap_reveals_hidden_boss_after_non_hidden_rooms_clear() -> void:
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
	_runner.assert_true(entries[&"final_1"]["visible"], "boss reveals after visible rooms clear")
	_runner.assert_eq(entries[&"final_1"]["label"], "B", "revealed boss uses boss label")


func test_minimap_uses_minimap_data_types_for_special_rooms() -> void:
	var minimap := Minimap.new()
	var layout := _create_shop_layout()
	add_child(minimap)

	minimap.set_layout(layout, &"start")

	var entries := _entries_by_room_id(minimap.get_room_draw_entries())
	_runner.assert_true(entries[&"treasure_1"]["visible"], "treasure room is visible on minimap")
	_runner.assert_eq(entries[&"treasure_1"]["minimap_type"], &"treasure", "treasure minimap type is preserved")
	_runner.assert_eq(entries[&"treasure_1"]["label"], "T", "treasure room uses treasure label")
	_runner.assert_true(entries[&"shop_1"]["visible"], "shop room is visible on minimap")
	_runner.assert_eq(entries[&"shop_1"]["minimap_type"], &"shop", "shop minimap type is preserved")
	_runner.assert_eq(entries[&"shop_1"]["label"], "$", "shop room uses shop label")
	_runner.assert_eq(entries[&"final_1"]["minimap_type"], &"boss", "final room uses boss minimap type")
	_runner.assert_false(entries[&"final_1"]["visible"], "hidden boss stays hidden")
	_runner.assert_eq(entries[&"final_1"]["label"], "?", "hidden boss remains unknown")


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


func _entries_by_room_id(entries: Array[Dictionary]) -> Dictionary:
	var by_id := {}
	for entry: Dictionary in entries:
		by_id[entry["room_id"]] = entry
	return by_id


func _create_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = &"minimap_test"
	layout.start_room_id = &"start"
	layout.room_defs = [
		_create_room_def(&"start", RoomLayout.TYPE_START, [&"combat_1"]),
		_create_room_def(&"combat_1", RoomLayout.TYPE_COMBAT, [&"start", &"treasure_1", &"event_1"]),
		_create_room_def(&"treasure_1", &"treasure", [&"combat_1"]),
		_create_room_def(&"event_1", RoomLayout.TYPE_EVENT, [&"combat_1", &"final_1"]),
		_create_room_def(&"final_1", RoomLayout.TYPE_FINAL, [&"event_1"], true),
	]
	return layout


func _create_linear_layout(layout_id: StringName, start_room_id: StringName, final_room_id: StringName) -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = layout_id
	layout.start_room_id = start_room_id
	layout.room_defs = [
		_create_room_def(start_room_id, RoomLayout.TYPE_START, [final_room_id]),
		_create_room_def(final_room_id, RoomLayout.TYPE_FINAL, [start_room_id], true),
	]
	return layout


func _create_shop_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = &"minimap_shop_test"
	layout.start_room_id = &"start"
	layout.room_defs = [
		_create_room_def(&"start", RoomLayout.TYPE_START, [&"treasure_1", &"shop_1"]),
		_create_room_def(&"treasure_1", &"treasure", [&"start"]),
		_create_room_def(&"shop_1", &"shop", [&"start", &"final_1"]),
		_create_room_def(&"final_1", RoomLayout.TYPE_FINAL, [&"shop_1"], true),
	]
	return layout


func _create_room_def(
	room_id: StringName,
	room_type: StringName,
	connections: Array[StringName],
	hidden := false
) -> RoomDef:
	var room_def := RoomDef.new()
	room_def.room_id = room_id
	room_def.room_type = room_type
	room_def.scene_path = "res://scenes/session/room_base.tscn"
	room_def.connections = connections
	room_def.hidden = hidden
	return room_def
