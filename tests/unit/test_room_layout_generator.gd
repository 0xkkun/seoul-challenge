extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_same_seed_generates_identical_layout() -> void:
	var generator := RoomLayoutGenerator.new()
	var first := generator.generate(734)
	var second := generator.generate(734)

	_runner.assert_eq(_layout_signature(first), _layout_signature(second), "same seed is deterministic")
	_assert_layout_invariants(first, 15)


func test_generated_layout_consumes_room_manager_to_final_room() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(42)
	var manager := RoomManager.new()
	var container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D

	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "manager starts generated layout")
	_runner.assert_eq(manager.current_room_id, &"start", "generated layout starts at start")

	var route := _route_that_clears_non_final_then_final(layout)
	for next_room_id: StringName in route:
		_runner.assert_true(manager.request_next_room(next_room_id), "manager enters %s" % next_room_id)

	_runner.assert_eq(manager.current_room_def.room_type, RoomLayout.TYPE_FINAL, "runtime route reaches final room")
	_runner.assert_false(manager.current_room_def.hidden, "final room is a normal discoverable node")


func test_room_count_param_expands_connected_layout() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(91, {"room_count": 8})
	_runner.assert_eq(layout.room_defs.size(), 8, "room count param expands layout")
	_assert_layout_invariants(layout, 8)


func test_fifteen_room_layout_preserves_generation_contracts() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 15})

	_assert_layout_invariants(layout, 15)


func test_fifteen_room_layout_has_branching_boss_route() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 15})
	var final_room := _final_room(layout)
	_runner.assert_not_null(final_room, "generated layout has a final room")
	if final_room == null:
		return

	_runner.assert_true(
		_shortest_path_length(layout, layout.start_room_id, final_room.room_id) >= 6,
		"boss route is long enough to avoid a trivial beeline"
	)
	_runner.assert_true(_junction_count(layout) >= 2, "layout has at least two branching junctions")
	_runner.assert_true(
		_undirected_edge_count(layout) >= layout.room_defs.size(),
		"layout has an alternate route beyond a pure tree"
	)


func test_generated_layout_allows_boss_entry_when_discovered() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 15})
	var final_room := _final_room(layout)
	_runner.assert_not_null(final_room, "generated layout has a final room")
	if final_room == null:
		return
	_runner.assert_false(final_room.hidden, "generated boss room is not hidden behind a clear count")
	_runner.assert_eq(layout.required_clears_for_hidden_reveal, 0, "generated layout has no boss reveal threshold")
	_runner.assert_true(layout.is_room_visible(final_room.room_id), "boss room is layout-visible from run start")
	_runner.assert_false(final_room.connections.is_empty(), "boss room has at least one discoverable entrance")

	var entrance_room_id := final_room.connections[0]
	var cleared_before_boss := _cleared_rooms_along_path(layout, layout.start_room_id, entrance_room_id)
	_runner.assert_true(cleared_before_boss.size() < layout.room_defs.size() - 1, "test reaches boss entrance before full clear")
	_runner.assert_eq(
		layout.get_next_room_id(entrance_room_id, cleared_before_boss, final_room.room_id),
		final_room.room_id,
		"discovered boss entrance can be taken without clearing unrelated rooms"
	)


func test_generated_combat_room_configs_scale_by_route_distance() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 15})
	var nearest_combat := _nearest_combat_room(layout)
	var farthest_combat := _farthest_combat_room(layout)
	_runner.assert_not_null(nearest_combat, "generated layout has a nearest combat room")
	_runner.assert_not_null(farthest_combat, "generated layout has a farthest combat room")
	if nearest_combat == null or farthest_combat == null:
		return

	var nearest_config_value: Variant = nearest_combat.get("room_config")
	var farthest_config_value: Variant = farthest_combat.get("room_config")

	_runner.assert_true(nearest_config_value is Dictionary, "nearest combat exposes room_config")
	_runner.assert_true(farthest_config_value is Dictionary, "farthest combat exposes room_config")
	if not (nearest_config_value is Dictionary and farthest_config_value is Dictionary):
		return
	var nearest_config := nearest_config_value as Dictionary
	var farthest_config := farthest_config_value as Dictionary
	_runner.assert_true(nearest_config.size() > 0, "nearest combat gets encounter config")
	_runner.assert_true(farthest_config.size() > 0, "farthest combat gets encounter config")
	_runner.assert_eq(_encounter_total(nearest_config), 4, "nearest combat starts at the early encounter budget")
	_runner.assert_eq(_encounter_total(farthest_config), 6, "late generated combat rooms use the mobile-friendly encounter budget")
	_runner.assert_eq(int(nearest_config.get("wolf_count", 0)), 1, "nearest generated combat includes a wolf dash enemy")
	_runner.assert_eq(int(farthest_config.get("wolf_count", 0)), 1, "late generated combat keeps one wolf dash enemy")
	_runner.assert_eq(int(nearest_config.get("wave_count", 0)), 1, "nearest combat starts in one wave")
	_runner.assert_eq(int(farthest_config.get("wave_count", 0)), 2, "late generated combat rooms split into two waves")
	_runner.assert_true(
		_encounter_total(farthest_config) > _encounter_total(nearest_config),
		"combat rooms farther from start get larger encounters"
	)
	_runner.assert_eq(_elite_total(farthest_config), 0, "late generated combat rooms avoid elite pressure while player growth is shallow")


func test_sixty_four_room_layout_preserves_requested_count() -> void:
	var generator := RoomLayoutGenerator.new()
	var layout := generator.generate(40, {"room_count": 64})

	_assert_layout_invariants(layout, 64)


func test_two_hundred_seed_fuzz_preserves_layout_invariants() -> void:
	var generator := RoomLayoutGenerator.new()
	for layout_seed: int in range(200):
		var layout := generator.generate(layout_seed)
		_assert_layout_invariants(layout, 15)


func test_fifty_seed_fuzz_preserves_fifteen_room_layout_invariants() -> void:
	var generator := RoomLayoutGenerator.new()
	for layout_seed: int in range(50):
		var layout := generator.generate(layout_seed, {"room_count": 15})
		_assert_layout_invariants(layout, 15)


func test_twenty_seed_fuzz_preserves_sixty_four_room_layout_invariants() -> void:
	var generator := RoomLayoutGenerator.new()
	for layout_seed: int in range(20):
		var layout := generator.generate(layout_seed, {"room_count": 64})
		_assert_layout_invariants(layout, 64)


func _assert_layout_invariants(layout: RoomLayout, expected_count: int) -> void:
	_runner.assert_not_null(layout, "layout exists")
	_runner.assert_eq(layout.room_defs.size(), expected_count, "room count matches")
	_runner.assert_eq(layout.validate_layout().size(), 0, "layout validates")

	var ids := {}
	var type_counts := {
		RoomLayout.TYPE_START: 0,
		RoomLayout.TYPE_COMBAT: 0,
		RoomLayout.TYPE_EVENT: 0,
		RoomLayout.TYPE_FRIEND: 0,
		RoomLayout.TYPE_FINAL: 0,
		RoomLayout.TYPE_TREASURE: 0,
		RoomLayout.TYPE_SHOP: 0,
	}
	var final_rooms: Array[RoomDef] = []
	var friend_rooms: Array[RoomDef] = []

	for room_def: RoomDef in layout.room_defs:
		_runner.assert_false(ids.has(room_def.room_id), "room id is unique")
		ids[room_def.room_id] = true
		_runner.assert_false(String(room_def.room_id).begins_with("event"), "generated layout does not assign event/info room ids")
		_runner.assert_false(String(room_def.room_id).begins_with("shop"), "generated layout does not assign shop room ids")
		if type_counts.has(room_def.room_type):
			type_counts[room_def.room_type] += 1
		if room_def.room_type == RoomLayout.TYPE_FINAL:
			final_rooms.append(room_def)
		if room_def.room_type == RoomLayout.TYPE_FRIEND:
			friend_rooms.append(room_def)

	_assert_reachable_and_bidirectional(layout)
	_assert_grid_positions_unique_and_adjacent(layout)

	_runner.assert_eq(type_counts[RoomLayout.TYPE_START], 1, "one start room")
	_runner.assert_true(type_counts[RoomLayout.TYPE_COMBAT] >= 2, "at least two combat rooms")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_COMBAT], expected_count - 4, "disabled special room slots become combat rooms")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_EVENT], 0, "generated layouts do not expose event/info rooms")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_FRIEND], 1, "one friend room")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_TREASURE], 1, "one treasure room")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_SHOP], 0, "generated layouts do not expose shop rooms")
	_runner.assert_eq(type_counts[RoomLayout.TYPE_FINAL], 1, "one final room")
	_runner.assert_eq(final_rooms.size(), 1, "final room exists")
	if final_rooms.size() == 1:
		_runner.assert_false(final_rooms[0].hidden, "final room is not hidden")
	_runner.assert_eq(friend_rooms.size(), 1, "friend room exists")
	if final_rooms.size() == 1 and friend_rooms.size() == 1:
		_runner.assert_true(final_rooms[0].connections.has(friend_rooms[0].room_id), "final room is reached through friend room")
		_runner.assert_true(friend_rooms[0].connections.has(final_rooms[0].room_id), "friend room leads to final room")
		_runner.assert_true(friend_rooms[0].scene_path != "", "friend room has a scene path")

	var reachable := _reachable_room_ids(layout, layout.start_room_id)
	_runner.assert_eq(reachable.size(), layout.room_defs.size(), "all rooms reachable from start")
	if final_rooms.size() == 1:
		_runner.assert_true(reachable.has(final_rooms[0].room_id), "final room is reachable")

	var cleared := {}
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type != RoomLayout.TYPE_FINAL:
			cleared[room_def.room_id] = true

	if final_rooms.size() == 1:
		_runner.assert_true(layout.is_room_visible(final_rooms[0].room_id), "final visible without clear gate")
		_runner.assert_true(layout.is_room_visible(final_rooms[0].room_id, cleared), "final stays visible after clears")


func _assert_reachable_and_bidirectional(layout: RoomLayout) -> void:
	for room_def: RoomDef in layout.room_defs:
		for connected_room_id: StringName in room_def.connections:
			var connected_room := layout.get_room(connected_room_id)
			_runner.assert_not_null(connected_room, "connection target exists")
			if connected_room != null:
				_runner.assert_true(
					connected_room.connections.has(room_def.room_id),
					"connection is bidirectional"
				)

	var reachable := _reachable_room_ids(layout, layout.start_room_id)
	_runner.assert_eq(reachable.size(), layout.room_defs.size(), "all rooms reachable from start")


func _assert_grid_positions_unique_and_adjacent(layout: RoomLayout) -> void:
	var positions := {}
	var start_room := layout.get_start_room()
	_runner.assert_not_null(start_room, "start room exists")
	if start_room != null:
		_runner.assert_eq(start_room.grid_pos, Vector2i.ZERO, "generated start grid position is normalized")

	for room_def: RoomDef in layout.room_defs:
		_runner.assert_false(positions.has(room_def.grid_pos), "%s grid position is unique" % room_def.room_id)
		positions[room_def.grid_pos] = room_def.room_id

	for room_def: RoomDef in layout.room_defs:
		for connected_room_id: StringName in room_def.connections:
			var connected_room := layout.get_room(connected_room_id)
			_runner.assert_not_null(connected_room, "connection target exists for grid check")
			if connected_room == null:
				continue
			var grid_distance := (
				absi(room_def.grid_pos.x - connected_room.grid_pos.x)
				+ absi(room_def.grid_pos.y - connected_room.grid_pos.y)
			)
			_runner.assert_eq(
				grid_distance,
				1,
				"%s connects to grid-adjacent %s" % [room_def.room_id, connected_room_id]
			)


func _layout_signature(layout: RoomLayout) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("%s|%s" % [layout.layout_id, layout.start_room_id])
	for room_def: RoomDef in layout.room_defs:
		lines.append(
			"%s|%s|%s|%s|%s|%s" % [
				room_def.room_id,
				room_def.room_type,
				room_def.scene_path,
				str(room_def.hidden),
				str(room_def.grid_pos),
				",".join(room_def.connections),
			]
		)
	return lines


func _reachable_room_ids(layout: RoomLayout, start_room_id: StringName) -> Dictionary:
	var reached := {start_room_id: true}
	var queue: Array[StringName] = [start_room_id]
	var cursor := 0

	while cursor < queue.size():
		var current_room_id := queue[cursor]
		cursor += 1
		var current_room := layout.get_room(current_room_id)
		if current_room == null:
			continue
		for connected_room_id: StringName in current_room.connections:
			if reached.has(connected_room_id):
				continue
			reached[connected_room_id] = true
			queue.append(connected_room_id)

	return reached


func _route_that_clears_non_final_then_final(layout: RoomLayout) -> Array[StringName]:
	var route: Array[StringName] = []
	var current_room_id := layout.start_room_id

	for room_def: RoomDef in layout.room_defs:
		if room_def.room_id == layout.start_room_id or room_def.room_type == RoomLayout.TYPE_FINAL:
			continue
		var path := _path_between(layout, current_room_id, room_def.room_id)
		_append_path_steps(route, path)
		current_room_id = room_def.room_id

	var final_room := _final_room(layout)
	var final_path := _path_between(layout, current_room_id, final_room.room_id)
	_append_path_steps(route, final_path)
	return route


func _append_path_steps(route: Array[StringName], path: Array[StringName]) -> void:
	for index: int in range(1, path.size()):
		route.append(path[index])


func _path_between(layout: RoomLayout, start_room_id: StringName, target_room_id: StringName) -> Array[StringName]:
	var queue: Array[StringName] = [start_room_id]
	var parent := {start_room_id: &""}
	var cursor := 0

	while cursor < queue.size():
		var current_room_id := queue[cursor]
		cursor += 1
		if current_room_id == target_room_id:
			break
		var current_room := layout.get_room(current_room_id)
		if current_room == null:
			continue
		for connected_room_id: StringName in current_room.connections:
			if parent.has(connected_room_id):
				continue
			parent[connected_room_id] = current_room_id
			queue.append(connected_room_id)

	var path: Array[StringName] = []
	var current := target_room_id
	while current != &"":
		path.push_front(current)
		current = parent.get(current, &"")
	return path


func _final_room(layout: RoomLayout) -> RoomDef:
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type == RoomLayout.TYPE_FINAL:
			return room_def
	return null


func _shortest_path_length(layout: RoomLayout, start_room_id: StringName, target_room_id: StringName) -> int:
	var path := _path_between(layout, start_room_id, target_room_id)
	if path.is_empty():
		return -1
	return path.size() - 1


func _nearest_combat_room(layout: RoomLayout) -> RoomDef:
	var best_room: RoomDef = null
	var best_distance := 999999
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type != RoomLayout.TYPE_COMBAT:
			continue
		var distance := _shortest_path_length(layout, layout.start_room_id, room_def.room_id)
		if distance < best_distance:
			best_room = room_def
			best_distance = distance
	return best_room


func _farthest_combat_room(layout: RoomLayout) -> RoomDef:
	var best_room: RoomDef = null
	var best_distance := -1
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type != RoomLayout.TYPE_COMBAT:
			continue
		var distance := _shortest_path_length(layout, layout.start_room_id, room_def.room_id)
		if distance > best_distance:
			best_room = room_def
			best_distance = distance
	return best_room


func _encounter_total(config: Dictionary) -> int:
	return (
		int(config.get("chaser_count", 0))
		+ int(config.get("ranged_count", 0))
		+ int(config.get("wolf_count", 0))
		+ int(config.get("elite_chaser_count", 0))
		+ int(config.get("elite_ranged_count", 0))
		+ int(config.get("elite_wolf_count", 0))
	)


func _elite_total(config: Dictionary) -> int:
	return (
		int(config.get("elite_chaser_count", 0))
		+ int(config.get("elite_ranged_count", 0))
		+ int(config.get("elite_wolf_count", 0))
	)


func _junction_count(layout: RoomLayout) -> int:
	var count := 0
	for room_def: RoomDef in layout.room_defs:
		if room_def.connections.size() >= 3:
			count += 1
	return count


func _undirected_edge_count(layout: RoomLayout) -> int:
	var seen := {}
	var count := 0
	for room_def: RoomDef in layout.room_defs:
		for connected_room_id: StringName in room_def.connections:
			var left := String(room_def.room_id)
			var right := String(connected_room_id)
			var edge_key := "%s|%s" % [left, right] if left < right else "%s|%s" % [right, left]
			if seen.has(edge_key):
				continue
			seen[edge_key] = true
			count += 1
	return count


func _cleared_rooms_along_path(layout: RoomLayout, start_room_id: StringName, target_room_id: StringName) -> Dictionary:
	var cleared := {}
	var path := _path_between(layout, start_room_id, target_room_id)
	for room_id: StringName in path:
		if room_id == target_room_id:
			break
		cleared[room_id] = true
	cleared[target_room_id] = true
	return cleared
