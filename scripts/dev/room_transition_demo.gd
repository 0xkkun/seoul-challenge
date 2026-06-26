extends Node2D

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

@export var auto_run := true
@export var quit_on_complete := true

var _room_layer: Node2D
var _actor: Node2D
var _current_room: Room
var _room_specs := {}
var _route := {}


func _ready() -> void:
	_build_specs()
	_build_scene_nodes()
	EventBus.room_entered.connect(_on_event_bus_room_entered)
	EventBus.room_cleared.connect(_on_event_bus_room_cleared)
	_enter_room(&"demo_start")
	if auto_run:
		call_deferred("_run_demo_chain")


func _exit_tree() -> void:
	if EventBus.room_entered.is_connected(_on_event_bus_room_entered):
		EventBus.room_entered.disconnect(_on_event_bus_room_entered)
	if EventBus.room_cleared.is_connected(_on_event_bus_room_cleared):
		EventBus.room_cleared.disconnect(_on_event_bus_room_cleared)


func _run_demo_chain() -> void:
	await get_tree().process_frame
	var guard := 0
	while _current_room != null and not _current_room.get_doors().is_empty():
		guard += 1
		if guard > 4:
			_fail_demo("transition guard exceeded")
			return
		var source_room_id := _current_room.room_id
		var door := _current_room.get_doors()[0]
		_actor.global_position = door.global_position
		var transition_count := _current_room.check_actor_transitions()
		print("[room_transition_demo] requested transition from %s via %s count=%d" % [source_room_id, door.door_dir, transition_count])
		if transition_count != 1:
			_fail_demo("expected one transition from %s" % source_room_id)
			return
		await get_tree().process_frame

	if _current_room != null and _current_room.room_id == &"demo_final":
		print("[room_transition_demo] OK: Room/RoomDoor chain reached demo_final")
		if quit_on_complete:
			get_tree().quit(0)
		return
	_fail_demo("demo did not reach demo_final")


func _build_specs() -> void:
	_room_specs = {
		&"demo_start": {"room_type": &"start", "door_dirs": [&"E"]},
		&"demo_event": {"room_type": &"event", "door_dirs": [&"E"]},
		&"demo_final": {"room_type": &"final", "door_dirs": []},
	}
	_route = {
		&"demo_start": {&"E": &"demo_event"},
		&"demo_event": {&"E": &"demo_final"},
	}


func _build_scene_nodes() -> void:
	_room_layer = Node2D.new()
	_room_layer.name = "RoomLayer"
	add_child(_room_layer)

	_actor = Node2D.new()
	_actor.name = "DemoActor"
	add_child(_actor)

	var marker := ColorRect.new()
	marker.name = "Marker"
	marker.size = Vector2(14.0, 14.0)
	marker.position = -marker.size * 0.5
	marker.color = RoomPalette.STUDENT_MARKER_COLOR
	_actor.add_child(marker)


func _enter_room(room_id: StringName) -> void:
	if _current_room != null:
		_current_room.queue_free()
	var spec: Dictionary = _room_specs.get(room_id, {})
	if spec.is_empty():
		_fail_demo("missing demo room spec: %s" % room_id)
		return
	_current_room = _create_room(room_id, spec["room_type"], spec["door_dirs"])
	_current_room.position = Vector2(200.0, 240.0)
	_room_layer.add_child(_current_room)
	_current_room.configure_actor(_actor)
	_current_room.transition_requested.connect(_on_room_transition_requested)
	_actor.global_position = _current_room.global_position
	_current_room.enter()


func _on_room_transition_requested(room_id: StringName, door_dir: StringName) -> void:
	print("[room_transition_demo] transition_requested room=%s door=%s" % [room_id, door_dir])
	var room_route: Dictionary = _route.get(room_id, {})
	var next_room_id: StringName = room_route.get(door_dir, &"")
	if next_room_id == &"":
		return
	_enter_room(next_room_id)


func _on_event_bus_room_entered(payload: Dictionary) -> void:
	print("[room_transition_demo] room_entered %s type=%s" % [payload["room_id"], payload["room_type"]])


func _on_event_bus_room_cleared(payload: Dictionary) -> void:
	print("[room_transition_demo] room_cleared %s" % payload["room_id"])


func _fail_demo(message: String) -> void:
	push_error("[room_transition_demo] FAIL: %s" % message)
	if quit_on_complete:
		get_tree().quit(1)


func _create_room(room_id: StringName, room_type: StringName, door_dirs: Array) -> Room:
	var room := Room.new()
	room.name = String(room_id)
	room.room_id = room_id
	room.room_type = room_type
	var typed_door_dirs: Array[StringName] = []
	for door_dir: StringName in door_dirs:
		typed_door_dirs.append(door_dir)
	room.door_dirs = typed_door_dirs

	var floor := ColorRect.new()
	floor.name = "Floor"
	room.add_child(floor)

	var label := Label.new()
	label.name = "RoomLabel"
	label.text = String(room_id)
	label.position = Vector2(-104.0, -82.0)
	room.add_child(label)

	var doors := Node2D.new()
	doors.name = "Doors"
	room.add_child(doors)
	for door_dir: StringName in typed_door_dirs:
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
