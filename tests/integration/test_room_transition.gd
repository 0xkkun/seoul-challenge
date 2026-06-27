extends Node

var _runner: Node
var _container: Node2D
var _actor: Node2D
var _current_room: Room
var _route := {}
var _entered_payloads: Array[Dictionary] = []
var _cleared_payloads: Array[Dictionary] = []
var _transition_events: Array[Dictionary] = []


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	get_tree().paused = false
	_container = Node2D.new()
	_actor = Node2D.new()
	_current_room = null
	_route = {
		&"start": {&"E": &"event_1"},
		&"event_1": {&"E": &"final_1"},
	}
	_entered_payloads.clear()
	_cleared_payloads.clear()
	_transition_events.clear()
	add_child(_container)
	add_child(_actor)
	EventBus.room_entered.connect(_on_event_bus_room_entered)
	EventBus.room_cleared.connect(_on_event_bus_room_cleared)


func after_each() -> void:
	get_tree().paused = false
	if EventBus.room_entered.is_connected(_on_event_bus_room_entered):
		EventBus.room_entered.disconnect(_on_event_bus_room_entered)
	if EventBus.room_cleared.is_connected(_on_event_bus_room_cleared):
		EventBus.room_cleared.disconnect(_on_event_bus_room_cleared)
	for child: Node in get_children():
		child.queue_free()


func test_placeholder_rooms_transition_from_enter_to_final_room() -> void:
	var room := _mount_room(&"start")

	_runner.assert_eq(room.room_id, &"start", "chain starts in start room")
	_runner.assert_true(room.has_been_cleared(), "start room clears during enter")
	_runner.assert_true(room.get_door(&"E").is_open(), "cleared start room opens door")

	_request_current_door_transition(&"E")
	_runner.assert_eq(_current_room.room_id, &"event_1", "east transition mounts event room")
	_runner.assert_true(_current_room.has_been_cleared(), "event room clears during enter")
	_runner.assert_true(_current_room.get_door(&"E").is_open(), "event room opens its door")

	_request_current_door_transition(&"E")
	_runner.assert_eq(_current_room.room_id, &"final_1", "second transition mounts final room")
	_runner.assert_true(_current_room.has_been_cleared(), "final room clears during enter")
	_runner.assert_eq(_current_room.get_doors().size(), 0, "final placeholder has no outgoing door")

	_runner.assert_eq(_transition_events, [
		{"room_id": &"start", "door_dir": &"E"},
		{"room_id": &"event_1", "door_dir": &"E"},
	], "room transition signals carry source room and door")
	_runner.assert_eq(_payload_room_ids(_entered_payloads), [&"start", &"event_1", &"final_1"], "room entered events cover full chain")
	_runner.assert_eq(_payload_room_ids(_cleared_payloads), [&"start", &"event_1", &"final_1"], "room cleared events cover full chain")


func _mount_room(room_id: StringName) -> Room:
	if _current_room != null:
		_current_room.queue_free()
	_current_room = _create_room(room_id, _room_type_for(room_id), _door_dirs_for(room_id))
	_current_room.position = Vector2(200.0, 220.0)
	_container.add_child(_current_room)
	_current_room.configure_actor(_actor)
	_current_room.transition_requested.connect(_on_room_transition_requested)
	_current_room.enter()
	return _current_room


func _request_current_door_transition(door_dir: StringName) -> void:
	var door := _current_room.get_door(door_dir)
	_runner.assert_not_null(door, "current room has requested door")
	if door == null:
		return
	_actor.global_position = door.global_position
	_runner.assert_eq(_current_room.check_actor_transitions(), 1, "actor overlap requests exactly one transition")


func _on_room_transition_requested(room_id: StringName, door_dir: StringName) -> void:
	_transition_events.append({"room_id": room_id, "door_dir": door_dir})
	var room_route: Dictionary = _route.get(room_id, {})
	var next_room_id: StringName = room_route.get(door_dir, &"")
	if next_room_id != &"":
		_mount_room(next_room_id)


func _on_event_bus_room_entered(payload: Dictionary) -> void:
	_entered_payloads.append(payload)


func _on_event_bus_room_cleared(payload: Dictionary) -> void:
	_cleared_payloads.append(payload)


func _room_type_for(room_id: StringName) -> StringName:
	match room_id:
		&"start":
			return &"start"
		&"event_1":
			return &"event"
		&"final_1":
			return &"final"
	return &"start"


func _door_dirs_for(room_id: StringName) -> Array[StringName]:
	match room_id:
		&"start", &"event_1":
			return [&"E"]
	return []


func _payload_room_ids(payloads: Array[Dictionary]) -> Array[StringName]:
	var room_ids: Array[StringName] = []
	for payload: Dictionary in payloads:
		room_ids.append(payload["room_id"])
	return room_ids


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
