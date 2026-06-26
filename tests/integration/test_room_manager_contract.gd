extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_gyeongbokgung_layout_validates_fixed_route() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	_runner.assert_not_null(layout, "layout resource loads")

	var errors := layout.validate_layout()
	_runner.assert_eq(errors.size(), 0, "layout passes its own rules")
	_runner.assert_eq(layout.get_room_ids(), [&"start", &"combat_1", &"combat_2", &"event_1", &"final_1"])
	_runner.assert_eq(layout.get_connected_room_ids(&"start"), [&"combat_1"])
	_runner.assert_eq(layout.get_room(&"start").grid_pos, Vector2i.ZERO, "authored start grid position is normalized")
	_runner.assert_eq(layout.get_room(&"final_1").grid_pos, Vector2i(4, 0), "authored final grid position is stable")
	_runner.assert_eq(layout.get_room(&"combat_1").scene_path, "res://scenes/interactables/combat_room.tscn", "combat rooms use combat scene")
	_runner.assert_eq(layout.get_room(&"combat_2").scene_path, "res://scenes/interactables/combat_room.tscn", "second combat room uses combat scene")
	_runner.assert_eq(layout.get_room(&"event_1").scene_path, "res://scenes/interactables/rescue_room.tscn", "event room uses rescue scene")
	_runner.assert_eq(layout.get_room(&"final_1").scene_path, "res://scenes/interactables/boss_room.tscn", "final room uses boss scene")
	_assert_grid_connections_are_adjacent(layout)

	var cleared := {}
	var initially_visible := layout.get_visible_room_defs(cleared)
	_runner.assert_eq(initially_visible.size(), 4, "hidden final room is not visible at start")

	for room_id: StringName in [&"start", &"combat_1", &"combat_2", &"event_1"]:
		cleared[room_id] = true

	_runner.assert_true(layout.is_room_visible(&"final_1", cleared), "final room is revealed after required rooms clear")
	_runner.assert_eq(layout.get_next_room_id(&"event_1", cleared), &"final_1", "route can finish")


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
	_runner.assert_eq(manager.get_visible_room_defs().size(), 4, "hidden final room starts hidden")

	for expected_room_id: StringName in [&"combat_1", &"combat_2", &"event_1"]:
		_runner.assert_true(manager.request_next_room(), "manager advances to %s" % expected_room_id)
		_runner.assert_eq(manager.current_room_id, expected_room_id)
		_resolve_current_room(manager, actor)
		_runner.assert_true(manager.has_cleared_room(expected_room_id), "%s clears after its room objective" % expected_room_id)

	_runner.assert_eq(manager.get_visible_room_defs().size(), 5, "final room is visible after required rooms clear")
	_runner.assert_true(manager.request_next_room(), "manager advances to final room")
	_runner.assert_eq(manager.current_room_id, &"final_1")
	_resolve_current_room(manager, actor)
	_runner.assert_true(manager.has_cleared_room(&"final_1"), "final room clears after boss completion")
	_runner.assert_false(manager.request_next_room(), "route has no room after final")
	_runner.assert_eq(entered_rooms, [&"start", &"combat_1", &"combat_2", &"event_1", &"final_1"])

	manager.room_changed.disconnect(on_room_changed)


func test_session_root_mounts_room_manager() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var entered_payloads: Array[Dictionary] = []
	var on_room_entered := func(payload: Dictionary) -> void:
		entered_payloads.append(payload)

	EventBus.room_entered.connect(on_room_entered)

	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var room_layer := session.get_node("%RoomLayer")
	_runner.assert_not_null(manager, "session root owns room manager")
	_runner.assert_eq(manager.current_room_id, &"start", "session starts fixed layout")
	_runner.assert_eq(manager.current_room.get_parent(), room_layer, "room manager mounts rooms under room layer")
	_runner.assert_true(manager.has_cleared_room(&"start"), "placeholder start room clears")
	_runner.assert_true(session.advance_room(), "session can advance through room manager")
	_runner.assert_eq(manager.current_room_id, &"combat_1", "session advances to first combat room")
	_runner.assert_true(manager.current_room.has_method("get_remaining_enemy_count"), "session mounts combat room implementation")
	_runner.assert_not_null(session.get_node_or_null("%CombatHud"), "session mounts combat HUD")
	_runner.assert_not_null(session.get_node_or_null("%TouchControls"), "session mounts touch controls")
	_runner.assert_not_null(session.get_node_or_null("%DeathReturnController"), "session mounts death return controller")
	_runner.assert_not_null(session.get_node_or_null("%PlayerCamera"), "session mounts player camera")
	_runner.assert_eq(entered_payloads.size(), 2, "room enter events fire for mounted rooms")

	EventBus.room_entered.disconnect(on_room_entered)


func _resolve_current_room(manager: RoomManager, actor: Node2D) -> void:
	var room := manager.current_room
	if room == null or manager.is_current_room_cleared():
		return
	if room.has_method("get_active_enemies"):
		for enemy: Node in room.call("get_active_enemies"):
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", 99)
	elif room.has_method("get_active_students"):
		for student: Node in room.call("get_active_students"):
			if student.has_method("rescue"):
				student.call("rescue", actor)
	elif room.has_method("complete_boss_encounter"):
		room.call("complete_boss_encounter")


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
