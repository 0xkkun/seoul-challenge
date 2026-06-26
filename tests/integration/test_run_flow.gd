extends Node

var _runner: Node
var _session_finished_callback := Callable()


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	if _session_finished_callback.is_valid() and EventBus.session_finished.is_connected(_session_finished_callback):
		EventBus.session_finished.disconnect(_session_finished_callback)
	_session_finished_callback = Callable()

	for child: Node in get_children():
		remove_child(child)
		child.free()

	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func test_run_controller_drives_layout_to_completion() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var room_container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var controller := RunController.new()
	var changed_rooms: Array[StringName] = []
	var finished_payloads: Array[Dictionary] = []
	var on_room_changed := func(room_id: StringName, _room_type: StringName) -> void:
		changed_rooms.append(room_id)
	_session_finished_callback = func(result: Dictionary) -> void:
		finished_payloads.append(result)

	add_child(room_container)
	add_child(actor)
	add_child(controller)
	controller.room_changed.connect(on_room_changed)
	EventBus.session_finished.connect(_session_finished_callback)
	controller.configure(layout, room_container, actor)

	_runner.assert_true(controller.start_run(), "run starts")
	_runner.assert_eq(controller.get_current_room_id(), &"start", "run starts at start room")
	var current_room := controller.get_current_room()
	_runner.assert_not_null(current_room, "run mounts current room")
	if current_room != null:
		_runner.assert_eq(current_room.get_parent(), room_container, "room mounts under injected container")
	_runner.assert_false(controller.is_completed(), "run is not complete after start")

	var guard := 0
	while not controller.is_completed():
		guard += 1
		_runner.assert_true(guard <= 8, "run completion guard")
		var advanced := controller.advance_room()
		if not controller.is_completed():
			_runner.assert_true(advanced, "run advances before completion")

	_runner.assert_eq(changed_rooms, [&"start", &"combat_1", &"combat_2", &"event_1", &"final_1"])
	_runner.assert_eq(finished_payloads.size(), 1, "session finished once")
	if finished_payloads.size() == 1:
		_runner.assert_eq(finished_payloads[0]["layout_id"], &"gyeongbokgung", "result includes layout id")
		_runner.assert_true(finished_payloads[0]["completed"], "result marks completion")
		_runner.assert_eq(finished_payloads[0]["current_room_id"], &"final_1", "result ends at final")
		_runner.assert_eq(finished_payloads[0]["visited_room_ids"], changed_rooms, "result keeps visited rooms")


func test_run_controller_finishes_active_game_manager_session() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var room_container := Node2D.new()
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	var controller := RunController.new()
	var finished_payloads: Array[Dictionary] = []
	_session_finished_callback = func(result: Dictionary) -> void:
		finished_payloads.append(result)

	add_child(room_container)
	add_child(actor)
	add_child(controller)
	EventBus.session_finished.connect(_session_finished_callback)
	GameManager.start_session({"source": "run_controller_test"})
	controller.configure(layout, room_container, actor)

	_runner.assert_true(controller.start_run(), "run starts with active GameManager session")
	_advance_until_completed(controller, "active session run completion guard")

	var profile: Dictionary = SaveManager.load_profile()
	var saved_results: Array = profile.get("session_results", [])
	_runner.assert_false(GameManager.is_session_active(), "run completion ends the active session")
	_runner.assert_eq(finished_payloads.size(), 1, "active session emits finish once")
	_runner.assert_eq(saved_results.size(), 1, "active session result is persisted")
	if saved_results.size() == 1:
		_runner.assert_eq(saved_results[0]["layout_id"], &"gyeongbokgung", "saved result includes layout id")
		_runner.assert_true(saved_results[0]["completed"], "saved result marks completion")
		_runner.assert_eq(saved_results[0]["current_room_id"], &"final_1", "saved result ends at final")


func test_run_flow_demo_scene_executes_to_completion() -> void:
	var packed := load("res://scenes/dev/run_flow_demo.tscn") as PackedScene
	var demo := packed.instantiate()
	demo.auto_run = false
	demo.quit_on_complete = false
	add_child(demo)

	var controller := demo.get_node("%RunController") as RunController
	_runner.assert_true(controller.start_run(), "demo controller starts")
	var guard := 0
	while not controller.is_completed():
		guard += 1
		_runner.assert_true(guard <= 8, "demo completion guard")
		var advanced := controller.advance_room()
		if not controller.is_completed():
			_runner.assert_true(advanced, "demo advances before completion")

	_runner.assert_eq(controller.get_current_room_id(), &"final_1", "demo reaches final room")
	_runner.assert_eq(controller.visited_room_ids.size(), 5, "demo visits fixed layout rooms")


func _advance_until_completed(controller: RunController, guard_message: String) -> void:
	var guard := 0
	while not controller.is_completed():
		guard += 1
		_runner.assert_true(guard <= 8, guard_message)
		var advanced := controller.advance_room()
		if not controller.is_completed():
			_runner.assert_true(advanced, "run advances before completion")
