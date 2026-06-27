extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	GameManager.reset_session()
	for child: Node in get_children():
		child.queue_free()


func test_gyeongbokgung_layout_validates_fixed_route() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	_runner.assert_not_null(layout, "layout resource loads")

	var errors := layout.validate_layout()
	_runner.assert_eq(errors.size(), 0, "layout passes its own rules")
	_runner.assert_eq(layout.get_room_ids(), [&"start", &"combat_1", &"treasure_1", &"combat_2", &"friend_1", &"final_1"])
	_runner.assert_eq(layout.get_connected_room_ids(&"start"), [&"combat_1"])
	_runner.assert_eq(layout.get_room(&"start").grid_pos, Vector2i.ZERO, "authored start grid position is normalized")
	_runner.assert_eq(layout.get_room(&"final_1").grid_pos, Vector2i(5, 0), "authored final grid position is stable")
	_runner.assert_eq(layout.get_room(&"combat_1").scene_path, "res://scenes/interactables/combat_room.tscn", "combat rooms use combat scene")
	_runner.assert_eq(layout.get_room(&"treasure_1").scene_path, "res://scenes/interactables/treasure_room.tscn", "treasure room uses treasure scene")
	_runner.assert_eq(layout.get_room(&"combat_2").scene_path, "res://scenes/interactables/combat_room.tscn", "second combat room uses combat scene")
	var friend_def := layout.get_room(&"friend_1")
	_runner.assert_not_null(friend_def, "layout includes friend room before final")
	if friend_def == null:
		return
	_runner.assert_eq(friend_def.scene_path, "res://scenes/interactables/friend_room.tscn", "friend room uses yokai friend scene")
	_runner.assert_eq(layout.get_room(&"final_1").scene_path, "res://scenes/interactables/boss_room.tscn", "final room uses boss scene")
	_assert_grid_connections_are_adjacent(layout)

	var cleared := {}
	var initially_visible := layout.get_visible_room_defs(cleared)
	_runner.assert_eq(initially_visible.size(), 6, "final room is visible without a clear gate")
	_runner.assert_false(layout.get_room(&"final_1").hidden, "final room is not hidden")

	for room_id: StringName in [&"start", &"combat_1", &"treasure_1", &"combat_2", &"friend_1"]:
		cleared[room_id] = true

	_runner.assert_true(layout.is_room_visible(&"final_1"), "final room is visible before required rooms clear")
	_runner.assert_eq(layout.get_next_room_id(&"combat_1", {&"start": true, &"combat_1": true}), &"treasure_1", "route must pass treasure room")
	_runner.assert_eq(layout.get_next_room_id(&"treasure_1", {&"start": true, &"combat_1": true, &"treasure_1": true}), &"combat_2", "treasure room leads to second combat")
	_runner.assert_eq(layout.get_next_room_id(&"combat_2", {&"start": true, &"combat_1": true, &"treasure_1": true, &"combat_2": true}), &"friend_1", "second combat leads to friend room")
	_runner.assert_eq(layout.get_next_room_id(&"friend_1", {&"friend_1": true}, &"final_1"), &"final_1", "discovered final room is enterable without unrelated clears")


func test_gyeongbokgung_combat_rooms_apply_distinct_encounter_configs() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var first_config_value: Variant = layout.get_room(&"combat_1").get("room_config")
	var second_config_value: Variant = layout.get_room(&"combat_2").get("room_config")
	var container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var manager := RoomManager.new()

	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.configure(layout, container, actor)

	_runner.assert_true(first_config_value is Dictionary, "first combat room exposes room_config")
	_runner.assert_true(second_config_value is Dictionary, "second combat room exposes room_config")
	if not (first_config_value is Dictionary and second_config_value is Dictionary):
		return
	var first_config := first_config_value as Dictionary
	var second_config := second_config_value as Dictionary
	_runner.assert_true(first_config.size() > 0, "first combat room has authored encounter config")
	_runner.assert_true(second_config.size() > 0, "second combat room has authored encounter config")
	_runner.assert_eq(_encounter_total(first_config), 4, "first authored combat room starts at the early encounter budget")
	_runner.assert_eq(_encounter_total(second_config), 6, "second authored combat room uses the mobile-friendly late encounter budget")
	_runner.assert_eq(int(first_config.get("wolf_count", 0)), 1, "first authored combat room includes a wolf dash enemy")
	_runner.assert_eq(int(second_config.get("wolf_count", 0)), 1, "second authored combat room keeps one wolf dash enemy")
	_runner.assert_eq(int(first_config.get("wave_count", 0)), 1, "first authored combat room uses one wave")
	_runner.assert_eq(int(second_config.get("wave_count", 0)), 2, "second authored combat room uses two waves")
	_runner.assert_true(_encounter_total(second_config) > _encounter_total(first_config), "second combat room is configured stronger")

	_runner.assert_true(manager.start_layout(), "manager starts fixed layout")
	_runner.assert_true(manager.request_next_room(), "manager enters first combat room")
	_runner.assert_eq(manager.current_room_id, &"combat_1", "first combat room entered")
	_runner.assert_true(manager.current_room.has_method("get_encounter_summary"), "combat room exposes applied summary")
	if not manager.current_room.has_method("get_encounter_summary"):
		return
	var first_summary: Dictionary = manager.current_room.call("get_encounter_summary")
	_resolve_current_room(manager, actor)
	_runner.assert_true(manager.request_next_room(), "manager enters treasure bridge room")
	_runner.assert_eq(manager.current_room_id, &"treasure_1", "treasure room sits between combat rooms")
	_resolve_current_room(manager, actor)
	_runner.assert_true(manager.request_next_room(), "manager enters second combat room")
	_runner.assert_eq(manager.current_room_id, &"combat_2", "second combat room entered")
	var second_summary: Dictionary = manager.current_room.call("get_encounter_summary")

	_runner.assert_eq(first_summary["total_count"], _encounter_total(first_config), "first room applies layout config")
	_runner.assert_eq(second_summary["total_count"], _encounter_total(second_config), "second room applies layout config")
	_runner.assert_eq(
		first_summary["wolf_count"],
		int(first_config.get("wolf_count", 0)),
		"first room applies wolf encounter config"
	)
	_runner.assert_eq(
		second_summary["wolf_count"],
		int(second_config.get("wolf_count", 0)),
		"second room applies wolf encounter config"
	)
	_runner.assert_true(second_summary["total_count"] > first_summary["total_count"], "runtime encounter curve gets stronger")
	_runner.assert_eq(
		second_summary["elite_chaser_count"] + second_summary["elite_ranged_count"] + second_summary["elite_wolf_count"],
		0,
		"second room avoids elite pressure while player growth is shallow"
	)


func test_room_manager_runs_layout_with_interactive_rooms() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var manager := RoomManager.new()
	var entered_rooms: Array[StringName] = []
	var on_room_changed := func(room_id: StringName, _room_type: StringName) -> void:
		entered_rooms.append(room_id)

	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.room_changed.connect(on_room_changed)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "manager starts fixed layout")
	_runner.assert_eq(manager.current_room_id, &"start")
	_runner.assert_true(manager.has_cleared_room(&"start"), "start clears on entry")
	_runner.assert_eq(manager.get_visible_room_defs().size(), 6, "final room starts visible in layout data")

	for expected_room_id: StringName in [&"combat_1", &"treasure_1", &"combat_2", &"friend_1"]:
		_runner.assert_true(manager.request_next_room(), "manager advances to %s" % expected_room_id)
		_runner.assert_eq(manager.current_room_id, expected_room_id)
		_resolve_current_room(manager, actor)
		_runner.assert_true(manager.has_cleared_room(expected_room_id), "%s clears after its room objective" % expected_room_id)

	_runner.assert_eq(manager.get_visible_room_defs().size(), 6, "final room remains visible after required rooms clear")
	_runner.assert_true(manager.request_next_room(), "manager advances to final room")
	_runner.assert_eq(manager.current_room_id, &"final_1")
	_resolve_current_room(manager, actor)
	_runner.assert_true(manager.has_cleared_room(&"final_1"), "final room clears after boss completion")
	_runner.assert_false(manager.request_next_room(), "route has no room after final")
	_runner.assert_eq(entered_rooms, [&"start", &"combat_1", &"treasure_1", &"combat_2", &"friend_1", &"final_1"])

	manager.room_changed.disconnect(on_room_changed)


func test_room_manager_uses_door_direction_for_transition_target() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var manager := RoomManager.new()
	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "manager starts fixed layout")
	_runner.assert_true(manager.request_next_room(), "manager advances to first combat room")
	_runner.assert_eq(manager.current_room_id, &"combat_1", "manager enters combat_1")
	_resolve_current_room(manager, actor)

	var west_door: RoomDoor = manager.current_room.get_door(&"W")
	_runner.assert_not_null(west_door, "combat_1 exposes a west door back to start")
	if west_door == null:
		return
	_runner.assert_true(west_door.request_transition(), "west door requests transition")
	_runner.assert_eq(manager.current_room_id, &"start", "west door returns to connected start room")


func test_room_manager_restores_cleared_room_state_on_revisit() -> void:
	var generator := RoomLayoutGenerator.new()
	generator.start_scene_path = "res://scenes/interactables/start_room.tscn"
	generator.combat_scene_path = "res://scenes/interactables/combat_room.tscn"
	generator.event_scene_path = "res://scenes/interactables/rescue_room.tscn"
	generator.final_scene_path = "res://scenes/interactables/boss_room.tscn"
	var layout := generator.generate(40, {"room_count": 15})
	var container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var manager := RoomManager.new()
	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "manager starts generated layout")
	var first_combat_id := _first_connected_combat_room_id(layout, layout.start_room_id)
	_runner.assert_true(manager.request_next_room(first_combat_id), "manager enters first combat branch")
	_resolve_current_room(manager, actor)
	_runner.assert_true(manager.has_cleared_room(first_combat_id), "first combat clears")
	_runner.assert_true(manager.request_next_room(layout.start_room_id), "manager returns to start")
	_runner.assert_true(manager.request_next_room(first_combat_id), "manager revisits cleared combat")
	_runner.assert_true(manager.current_room.has_been_cleared(), "revisited room restores local cleared state")
	_runner.assert_eq(manager.current_room.call("get_remaining_enemy_count"), 0, "revisited combat does not respawn enemies")


func test_session_root_mounts_room_manager() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var entered_payloads: Array[Dictionary] = []
	var on_room_entered := func(payload: Dictionary) -> void:
		entered_payloads.append(payload)

	EventBus.room_entered.connect(on_room_entered)
	GameManager.start_session({
		"source": "seeded_session_root_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})

	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var room_layer := session.get_node("%RoomLayer")
	_runner.assert_not_null(manager, "session root owns room manager")
	_runner.assert_eq(manager.current_room_id, &"start", "session starts run layout")
	_runner.assert_eq(manager.layout.room_defs.size(), 15, "session uses the branching run map room count")
	_runner.assert_eq(manager.layout.required_clears_for_hidden_reveal, 0, "session run map has no boss reveal threshold")
	_runner.assert_eq(_first_room_of_type(manager.layout, RoomLayout.TYPE_SHOP), null, "session run map does not expose unfinished shop rooms")
	_runner.assert_eq(_first_room_of_type(manager.layout, RoomLayout.TYPE_EVENT), null, "session run map does not expose unfinished event/info rooms")
	_runner.assert_true(_junction_count(manager.layout) >= 2, "session run map has multiple branching junctions")
	_runner.assert_true(
		_undirected_edge_count(manager.layout) >= manager.layout.room_defs.size(),
		"session run map includes an alternate route beyond a pure tree"
	)
	var treasure_defs := _room_defs_of_type(manager.layout, RoomLayout.TYPE_TREASURE)
	_runner.assert_eq(treasure_defs.size(), 0, "session run map does not expose treasure/key rooms")
	var friend_defs := _room_defs_of_type(manager.layout, RoomLayout.TYPE_FRIEND)
	_runner.assert_eq(friend_defs.size(), 1, "session run map includes one friend room")
	if friend_defs.size() == 1:
		_runner.assert_eq(friend_defs[0].scene_path, "res://scenes/interactables/friend_room.tscn", "session friend room uses friend scene")
	_runner.assert_eq(manager.current_room.get_parent(), room_layer, "room manager mounts rooms under room layer")
	_runner.assert_true(manager.has_cleared_room(&"start"), "start room clears")
	_runner.assert_true(session.advance_room(), "session can advance through room manager")
	_runner.assert_eq(manager.current_room_def.room_type, RoomLayout.TYPE_COMBAT, "session advances to first combat room")
	_runner.assert_true(manager.current_room.has_method("get_remaining_enemy_count"), "session mounts combat room implementation")
	_runner.assert_not_null(session.get_node_or_null("%CombatHud"), "session mounts combat HUD")
	_runner.assert_not_null(session.get_node_or_null("%TouchControls"), "session mounts touch controls")
	_runner.assert_not_null(session.get_node_or_null("%DeathReturnController"), "session mounts death return controller")
	var player_camera := session.get_node_or_null("%PlayerCamera") as Camera2D
	_runner.assert_not_null(player_camera, "session mounts player camera")
	if player_camera != null:
		_runner.assert_eq(player_camera.zoom, Vector2.ONE, "session camera uses native mobile viewport scale for corridor scrolling")
		_runner.assert_false(player_camera.position_smoothing_enabled, "session camera follows player immediately to avoid smoothing afterimage")
		_runner.assert_true(RoomPalette.ROOM_SIZE.x > float(ProjectSettings.get_setting("display/window/size/viewport_width")), "room is wider than one mobile viewport")
	_runner.assert_eq(entered_payloads.size(), 2, "room enter events fire for mounted rooms")

	EventBus.room_entered.disconnect(on_room_entered)
	GameManager.reset_session()


func test_session_root_finish_requires_final_room_clear_on_branching_map() -> void:
	# 고정 시드로 결정적 분기 레이아웃 생성(랜덤 시드는 non-final leaf 없는 맵을 만들어 flaky).
	# 시드 7은 room_count 15 에서 항상 non-final 막다른 분기를 포함한다.
	GameManager.start_session({
		"source": "branching_seed_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 7,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	GameManager.start_session({
		"source": "seeded_branching_finish_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var branch_tip := _non_final_leaf_room(manager.layout)
	_runner.assert_not_null(branch_tip, "generated layout has a non-final branch tip")
	if branch_tip == null:
		GameManager.reset_session()
		return
	var path := _path_between(manager.layout, manager.current_room_id, branch_tip.room_id)
	_runner.assert_true(path.size() > 1, "branch tip is reachable from current room")
	for index: int in range(1, path.size()):
		_resolve_current_room(manager, actor, session)
		_runner.assert_true(manager.request_next_room(path[index]), "manager walks to %s" % path[index])
	_resolve_current_room(manager, actor, session)

	var result: Dictionary = session.finish_session()
	_runner.assert_false(result["completed"], "cleared non-final branch tip does not complete the run")
	GameManager.reset_session()


func _resolve_current_room(manager: RoomManager, actor: Node2D, session: Node = null) -> void:
	var room := manager.current_room
	if room == null or manager.is_current_room_cleared():
		return
	if room.has_method("get_active_enemies"):
		_defeat_all_combat_waves(room)
		_resolve_pending_session_reward(session)
	elif room.has_method("get_active_students"):
		for student: Node in room.call("get_active_students"):
			if student.has_method("rescue"):
				student.call("rescue", actor)
	elif room.has_method("pick_up"):
		room.call("pick_up", actor)
	elif room.has_method("get_active_friends"):
		for friend: Node in room.call("get_active_friends"):
			if friend.has_signal("purified"):
				friend.emit_signal("purified", friend)
	elif room.has_method("complete_boss_encounter"):
		room.call("complete_boss_encounter")


func _resolve_pending_session_reward(session: Node) -> void:
	if session == null or not session.has_method("flush_pending_reward_choice_for_tests"):
		return
	if not bool(session.call("flush_pending_reward_choice_for_tests")):
		return
	var session_ui := session.get_node_or_null("%SessionUIRoot")
	if session_ui == null or not session_ui.has_method("get_reward_choice_ids"):
		return
	var choice_ids: Array = session_ui.call("get_reward_choice_ids")
	if choice_ids.is_empty():
		return
	session_ui.call("select_reward_choice", choice_ids[0])


func _encounter_total(config: Dictionary) -> int:
	return (
		int(config.get("chaser_count", 0))
		+ int(config.get("ranged_count", 0))
		+ int(config.get("wolf_count", 0))
		+ int(config.get("elite_chaser_count", 0))
		+ int(config.get("elite_ranged_count", 0))
		+ int(config.get("elite_wolf_count", 0))
	)


func _defeat_all_combat_waves(room: Node) -> void:
	var guard := 0
	while room.has_method("get_active_enemies") and room.has_method("is_cleared") and not room.call("is_cleared"):
		var enemies: Array = room.call("get_active_enemies")
		if enemies.is_empty():
			return
		for enemy: Node in enemies:
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", 99)
		guard += 1
		if guard > 8:
			return


func _assert_grid_connections_are_adjacent(layout: RoomLayout) -> void:
	var occupied := {}
	for room_def: RoomDef in layout.room_defs:
		_runner.assert_false(occupied.has(room_def.grid_pos), "%s grid position is unique" % room_def.room_id)
		occupied[room_def.grid_pos] = room_def.room_id
		for connected_room_id: StringName in room_def.connections:
			var connected_room := layout.get_room(connected_room_id)
			_runner.assert_not_null(connected_room, "connection target exists")
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


func _first_connected_combat_room_id(layout: RoomLayout, room_id: StringName) -> StringName:
	var room := layout.get_room(room_id)
	if room == null:
		return &""
	for connected_id: StringName in room.connections:
		var connected := layout.get_room(connected_id)
		if connected != null and connected.room_type == RoomLayout.TYPE_COMBAT:
			return connected_id
	return &""


func _first_room_of_type(layout: RoomLayout, room_type: StringName) -> RoomDef:
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type == room_type:
			return room_def
	return null


func _non_final_leaf_room(layout: RoomLayout) -> RoomDef:
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type != RoomLayout.TYPE_FINAL and room_def.room_id != layout.start_room_id and room_def.connections.size() == 1:
			return room_def
	return null


func _room_defs_of_type(layout: RoomLayout, room_type: StringName) -> Array[RoomDef]:
	var matches: Array[RoomDef] = []
	for room_def: RoomDef in layout.room_defs:
		if room_def != null and room_def.room_type == room_type:
			matches.append(room_def)
	return matches


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
