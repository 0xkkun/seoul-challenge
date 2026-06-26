extends Node

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()
	GameManager.reset_session()


func after_each() -> void:
	get_tree().paused = false
	PoolManager.clear_all()
	GameManager.reset_session()


func test_session_interaction_and_summary() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var dispatched: int = session.trigger_sample_interaction()
	_runner.assert_eq(dispatched, 1, "one interactable receives interaction check")
	_runner.assert_eq(session.completed_interactions, 1, "interaction updates session count")
	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 1, "interaction spawns pooled marker")

	var result: Dictionary = session.finish_session()
	_runner.assert_eq(result["interactions"], 1)
	_runner.assert_false(GameManager.is_session_active(), "session is no longer active")

	session.queue_free()


func test_session_root_preserves_existing_config() -> void:
	GameManager.start_session({"source": "preconfigured"})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	_runner.assert_eq(GameManager.get_active_config()["source"], "preconfigured")

	session.queue_free()


func test_session_ui_can_resume_while_tree_is_paused() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var resume_button: Button = session_ui.get_node("%ResumeButton")

	session._on_pause_requested()
	_runner.assert_true(get_tree().paused, "pause request pauses scene tree")
	_runner.assert_eq(session_ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	_runner.assert_true(session_ui.can_process(), "session UI still processes while paused")
	_runner.assert_true(resume_button.can_process(), "resume button still processes while paused")

	session._on_resume_requested()
	_runner.assert_false(get_tree().paused, "resume request unpauses scene tree")

	session.queue_free()


func test_session_render_layer_contract() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var world_layer := session.get_node("WorldLayer") as Node2D
	var room_layer := session.get_node("%RoomLayer") as Node2D
	var actor_layer := session.get_node("ActorLayer") as Node2D
	var interactable_layer := session.get_node("%InteractableLayer") as Node2D
	var pooled_object_layer := session.get_node("%PooledObjectLayer") as Node2D
	var session_ui := session.get_node("%SessionUIRoot") as CanvasLayer

	_runner.assert_eq(world_layer.z_index, RenderLayers.WORLD_BACKGROUND_Z)
	_runner.assert_eq(room_layer.z_index, RenderLayers.WORLD_BACKGROUND_Z)
	_runner.assert_eq(actor_layer.z_index, RenderLayers.WORLD_ACTOR_Z)
	_runner.assert_eq(interactable_layer.z_index, RenderLayers.WORLD_INTERACTABLE_Z)
	_runner.assert_eq(pooled_object_layer.z_index, RenderLayers.WORLD_EFFECT_Z)
	_runner.assert_eq(session_ui.layer, RenderLayers.UI_SESSION_LAYER)

	session.queue_free()


func test_room_base_lifecycle_opens_door_and_requests_transition() -> void:
	var packed := load("res://scenes/session/room_base.tscn") as PackedScene
	var room := packed.instantiate() as Room
	var entered_payloads: Array[Dictionary] = []
	var cleared_payloads: Array[Dictionary] = []
	var cleared_rooms: Array[StringName] = []
	var transitions: Array[Dictionary] = []
	var on_room_entered := func(payload: Dictionary) -> void:
		entered_payloads.append(payload)
	var on_room_cleared := func(payload: Dictionary) -> void:
		cleared_payloads.append(payload)
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)
	var on_transition_requested := func(room_id: StringName, door_dir: StringName) -> void:
		transitions.append({"room_id": room_id, "door_dir": door_dir})

	EventBus.room_entered.connect(on_room_entered)
	EventBus.room_cleared.connect(on_room_cleared)
	room.cleared.connect(on_cleared)
	room.transition_requested.connect(on_transition_requested)
	add_child(room)
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	add_child(actor)

	var north_door := room.get_door(&"N")
	var floor := room.get_node("Floor") as ColorRect
	var door_visual := north_door.get_node("DoorVisual") as ColorRect
	var door_shape := north_door.get_node("TransitionArea/CollisionShape2D") as CollisionShape2D
	var door_rectangle := door_shape.shape as RectangleShape2D

	_runner.assert_not_null(north_door, "base room exposes north door")
	_runner.assert_not_null(door_rectangle, "base room door configures collision shape")
	_runner.assert_eq(floor.size, RoomPalette.ROOM_SIZE, "room floor uses palette size")
	_runner.assert_eq(floor.color, RoomPalette.START_ROOM_FLOOR_COLOR, "room floor uses palette color")
	_runner.assert_eq(north_door.position, RoomPalette.NORTH_DOOR_POSITION, "door uses palette position")
	_runner.assert_eq(door_visual.size, RoomPalette.DOOR_SIZE, "door visual uses palette size")
	_runner.assert_eq(door_rectangle.size, RoomPalette.DOOR_TRIGGER_SIZE, "door trigger uses palette size")
	_runner.assert_true(north_door.is_locked(), "door starts locked")
	_runner.assert_eq(door_visual.color, RoomPalette.DOOR_LOCKED_COLOR, "door starts with locked palette color")
	room.configure_actor(actor)
	actor.global_position = north_door.global_position
	_runner.assert_eq(room.check_actor_transitions(), 0, "locked door ignores actor overlap")

	room.enter()

	_runner.assert_true(room.has_entered(), "enter records lifecycle state")
	_runner.assert_true(room.has_been_cleared(), "default base room clears on enter")
	_runner.assert_eq(cleared_rooms.size(), 1, "room emits cleared once")
	_runner.assert_eq(entered_payloads.size(), 1, "room entered event emitted")
	_runner.assert_eq(cleared_payloads.size(), 1, "room cleared event emitted")
	_runner.assert_true(north_door.is_open(), "door opens after clear")
	_runner.assert_eq(door_visual.color, RoomPalette.DOOR_OPEN_COLOR, "open door uses palette color")

	if entered_payloads.size() == 1:
		_runner.assert_eq(entered_payloads[0]["room_id"], &"room_base", "entered payload has room id")
		_runner.assert_eq(entered_payloads[0]["room_type"], &"start", "entered payload has room type")
	if cleared_payloads.size() == 1:
		_runner.assert_eq(cleared_payloads[0]["door_dirs"][0], &"N", "cleared payload has door dir")

	var did_request_transition := room.check_actor_transitions()
	_runner.assert_eq(did_request_transition, 1, "open door accepts actor overlap transition")
	_runner.assert_eq(transitions.size(), 1, "room forwards door transition request")
	if transitions.size() == 1:
		_runner.assert_eq(transitions[0]["room_id"], &"room_base", "transition includes room id")
		_runner.assert_eq(transitions[0]["door_dir"], &"N", "transition includes door dir")
	_runner.assert_eq(room.check_actor_transitions(), 0, "door overlap transition emits once per entry")

	EventBus.room_entered.disconnect(on_room_entered)
	EventBus.room_cleared.disconnect(on_room_cleared)
	actor.queue_free()
	room.queue_free()
