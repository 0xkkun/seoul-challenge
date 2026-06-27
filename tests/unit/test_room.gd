extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	get_tree().paused = false
	for child: Node in get_children():
		child.queue_free()


func test_enter_emits_room_entered_and_start_room_clears() -> void:
	var room := _create_room(&"start_unit", &"start", [&"N"])
	var door := room.get_door(&"N")
	var entered_payloads: Array[Dictionary] = []
	var cleared_payloads: Array[Dictionary] = []
	var cleared_rooms: Array[StringName] = []
	var on_room_entered := func(payload: Dictionary) -> void:
		entered_payloads.append(payload)
	var on_room_cleared := func(payload: Dictionary) -> void:
		cleared_payloads.append(payload)
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)

	EventBus.room_entered.connect(on_room_entered)
	EventBus.room_cleared.connect(on_room_cleared)
	room.cleared.connect(on_cleared)

	room.enter()

	_runner.assert_true(room.has_entered(), "enter records lifecycle state")
	_runner.assert_true(room.has_been_cleared(), "start room clears on enter")
	_runner.assert_true(door.is_open(), "cleared room opens its door")
	_runner.assert_eq(cleared_rooms, [&"start_unit"], "room cleared signal includes id")
	_runner.assert_eq(entered_payloads.size(), 1, "room entered event emitted once")
	_runner.assert_eq(cleared_payloads.size(), 1, "room cleared event emitted once")
	if entered_payloads.size() == 1:
		_runner.assert_eq(entered_payloads[0]["room_id"], &"start_unit", "entered payload includes room id")
		_runner.assert_eq(entered_payloads[0]["door_dirs"], [&"N"], "entered payload includes doors")

	EventBus.room_entered.disconnect(on_room_entered)
	EventBus.room_cleared.disconnect(on_room_cleared)


func test_mark_cleared_emits_once_and_opens_locked_doors() -> void:
	var room := _create_room(&"activity_unit", &"combat", [&"E"])
	var door := room.get_door(&"E")
	var cleared_rooms: Array[StringName] = []
	var cleared_payloads: Array[Dictionary] = []
	var door_states: Array[int] = []
	var on_room_cleared := func(payload: Dictionary) -> void:
		cleared_payloads.append(payload)
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)
	var on_door_state_changed := func(_door_dir: StringName, state: int) -> void:
		door_states.append(state)

	EventBus.room_cleared.connect(on_room_cleared)
	room.cleared.connect(on_cleared)
	door.state_changed.connect(on_door_state_changed)

	_runner.assert_true(door.is_locked(), "door starts locked")
	room.mark_cleared()
	room.mark_cleared()

	_runner.assert_true(room.has_been_cleared(), "room records cleared state")
	_runner.assert_true(door.is_open(), "cleared room opens locked door")
	_runner.assert_eq(cleared_rooms, [&"activity_unit"], "mark_cleared is idempotent for local signal")
	_runner.assert_eq(cleared_payloads.size(), 1, "mark_cleared is idempotent for event bus")
	_runner.assert_eq(door_states, [RoomDoor.DoorState.OPEN], "door opens only once")

	EventBus.room_cleared.disconnect(on_room_cleared)


func test_room_cleared_event_fires_before_exit_doors_open() -> void:
	var room := _create_room(&"reward_timing_unit", &"combat", [&"E"])
	var door := room.get_door(&"E")
	var door_open_at_event: Array[bool] = []
	var on_room_cleared := func(_payload: Dictionary) -> void:
		door_open_at_event.append(door.is_open())

	EventBus.room_cleared.connect(on_room_cleared)

	_runner.assert_true(door.is_locked(), "door starts locked before room clear")
	room.mark_cleared()

	_runner.assert_eq(door_open_at_event, [false], "reward listeners see clear before the exit door can transition")
	_runner.assert_true(door.is_open(), "door still opens after clear event dispatch")

	EventBus.room_cleared.disconnect(on_room_cleared)


func test_room_forwards_door_transition_with_room_id() -> void:
	var room := _create_room(&"transition_unit", &"event", [&"E"])
	var floor := room.get_node("Floor") as ColorRect
	var door := room.get_door(&"E")
	var transitions: Array[Dictionary] = []
	var on_transition_requested := func(room_id: StringName, door_dir: StringName) -> void:
		transitions.append({"room_id": room_id, "door_dir": door_dir})

	room.transition_requested.connect(on_transition_requested)
	room.mark_cleared()

	_runner.assert_eq(floor.color, RoomPalette.get_room_floor_color(&"event"), "room floor uses palette color")
	_runner.assert_true(door.request_transition(), "open door accepts transition request")
	_runner.assert_eq(transitions.size(), 1, "room forwards door transition once")
	if transitions.size() == 1:
		_runner.assert_eq(transitions[0]["room_id"], &"transition_unit", "transition includes room id")
		_runner.assert_eq(transitions[0]["door_dir"], &"E", "transition includes door direction")


func test_room_builds_perimeter_walls_with_gap_for_authored_door() -> void:
	var room := _create_room(&"wall_unit", &"combat", [&"N"])
	_runner.assert_true(room.has_method("get_wall_segments"), "room exposes generated wall segments")
	if not room.has_method("get_wall_segments"):
		return
	var wall_segments: Array = room.call("get_wall_segments")
	var north_door := room.get_door(&"N")
	var room_bounds := RoomPalette.get_room_bounds()
	var north_wall := room.get_node("Walls/NorthWallLeft") as StaticBody2D

	_runner.assert_eq(wall_segments.size(), 5, "single north door splits only the north wall")
	_runner.assert_eq(north_wall.position.y, room_bounds.position.y - RoomPalette.WALL_THICKNESS * 0.5, "north wall follows the locked gate lower edge")
	for wall: StaticBody2D in wall_segments:
		_runner.assert_true(wall.get_node_or_null("WallVisual") == null, "generated walls keep collision but hide debug borders")
	_runner.assert_true(north_door.has_method("is_blocking_body_enabled"), "door exposes locked blocker state")
	if not north_door.has_method("is_blocking_body_enabled"):
		return
	_runner.assert_true(north_door.is_blocking_body_enabled(), "locked door blocks the wall gap")

	room.mark_cleared()

	_runner.assert_false(north_door.is_blocking_body_enabled(), "open door releases the wall gap blocker")


func test_room_without_doors_builds_four_solid_walls() -> void:
	var room := _create_room(&"sealed_unit", &"final", [])

	_runner.assert_true(room.has_method("get_wall_segments"), "room exposes generated wall segments")
	if not room.has_method("get_wall_segments"):
		return
	_runner.assert_eq(room.call("get_wall_segments").size(), 4, "sealed room has one wall per side")


func test_room_generated_background_uses_nearest_filtering() -> void:
	var room := _create_room(&"background_unit", &"combat", [])
	var background := room.get_node_or_null("Background") as Sprite2D

	_runner.assert_not_null(background, "room creates a night palace background sprite")
	if background == null:
		return
	_runner.assert_eq(background.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "generated room background keeps pixel filtering")


func test_room_palette_exposes_play_area_and_camera_limits() -> void:
	var room_bounds: Rect2 = RoomPalette.get_room_bounds()
	var wall_bounds: Rect2 = RoomPalette.get_wall_bounds()
	var camera_bounds: Rect2 = RoomPalette.get_camera_bounds()
	var camera_limits: Dictionary = RoomPalette.get_camera_limits()
	var expected_wall_margin := Vector2(RoomPalette.WALL_THICKNESS, RoomPalette.WALL_THICKNESS)

	_runner.assert_eq(room_bounds, RoomPalette.PLAY_BOUNDS, "movement bounds use the authored playable courtyard, not the full background crop")
	_runner.assert_true(room_bounds.position.x > -RoomPalette.ROOM_HALF_SIZE.x, "left edge stops at the haetae side of the map")
	_runner.assert_true(room_bounds.end.x < RoomPalette.ROOM_HALF_SIZE.x, "right edge stops at the haetae side of the map")
	_runner.assert_true(room_bounds.position.y > -RoomPalette.ROOM_HALF_SIZE.y, "top edge stops below the locked palace door")
	_runner.assert_true(room_bounds.size.x > 960.0, "playable courtyard remains wider than one landscape viewport")
	_runner.assert_true(RoomPalette.ROOM_SIZE.x >= 2560.0, "visual room width covers the scaled palace background")
	_runner.assert_true(camera_bounds.position.x < wall_bounds.position.x, "camera keeps visual margin outside the left collision wall")
	_runner.assert_true(camera_bounds.end.x > wall_bounds.end.x, "camera keeps visual margin outside the right collision wall")
	_runner.assert_eq(RoomPalette.NORTH_DOOR_POSITION, Vector2(0.0, room_bounds.position.y), "north portal sits under the locked door")
	_runner.assert_eq(RoomPalette.EAST_DOOR_POSITION, Vector2(room_bounds.end.x, 0.0), "east portal sits on the right haetae boundary")
	_runner.assert_eq(RoomPalette.WEST_DOOR_POSITION, Vector2(room_bounds.position.x, 0.0), "west portal sits on the left haetae boundary")
	_runner.assert_eq(wall_bounds.position, room_bounds.position - expected_wall_margin, "wall bounds include perimeter thickness outside the room")
	_runner.assert_eq(wall_bounds.size, room_bounds.size + expected_wall_margin * 2.0, "wall bounds wrap the full room perimeter")
	_runner.assert_eq(camera_limits["left"], int(floor(camera_bounds.position.x)), "camera left limit follows visual map bounds")
	_runner.assert_eq(camera_limits["top"], int(floor(camera_bounds.position.y)), "camera top limit follows visual map bounds")
	_runner.assert_eq(camera_limits["right"], int(ceil(camera_bounds.end.x)), "camera right limit follows visual map bounds")
	_runner.assert_eq(camera_limits["bottom"], int(ceil(camera_bounds.end.y)), "camera bottom limit follows visual map bounds")


func _create_room(room_id: StringName, room_type: StringName, door_dirs: Array[StringName]) -> Room:
	var room := Room.new()
	room.name = String(room_id)
	room.room_id = room_id
	room.room_type = room_type
	room.door_dirs = door_dirs.duplicate()

	var floor := ColorRect.new()
	floor.name = "Floor"
	room.add_child(floor)

	var doors := Node2D.new()
	doors.name = "Doors"
	room.add_child(doors)
	for door_dir: StringName in door_dirs:
		doors.add_child(_create_door(door_dir))

	add_child(room)
	return room


func _create_door(door_dir: StringName) -> RoomDoor:
	var door := RoomDoor.new()
	door.name = "%sDoor" % String(door_dir)
	door.door_dir = door_dir

	var visual := ColorRect.new()
	visual.name = "DoorVisual"
	door.add_child(visual)

	var transition_area := Area2D.new()
	transition_area.name = "TransitionArea"
	transition_area.collision_layer = 0
	door.add_child(transition_area)

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	transition_area.add_child(collision_shape)

	return door
