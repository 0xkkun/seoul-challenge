extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()


func after_each() -> void:
	PoolManager.clear_all()


func test_rescue_room_clears_after_all_students_are_rescued() -> void:
	var room := _instantiate_rescue_room()
	var actor := Node2D.new()
	var rescued_payloads: Array[Dictionary] = []
	var currency_payloads: Array[Dictionary] = []
	var cleared_rooms: Array[StringName] = []
	var on_student_rescued := func(payload: Dictionary) -> void:
		rescued_payloads.append(payload)
	var on_currency_changed := func(payload: Dictionary) -> void:
		if payload.get("source", "") != "CurrencySystem":
			currency_payloads.append(payload)
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)

	room.random_seed = 7
	room.rescue_student_count_min = 2
	room.rescue_student_count_max = 2
	room.rescue_reward_amount = 3
	EventBus.student_rescued.connect(on_student_rescued)
	EventBus.currency_changed.connect(on_currency_changed)
	room.cleared.connect(on_cleared)
	add_child(room)
	add_child(actor)

	room.enter()

	var students := room.get_active_students()
	var exit_door := room.get_door(&"E")
	_runner.assert_eq(students.size(), 2, "rescue room spawns the required students")
	_runner.assert_false(room.is_cleared(), "room waits for every student")
	_runner.assert_not_null(exit_door, "rescue room has an exit door")
	_runner.assert_true(exit_door.is_locked(), "door stays locked before completion")

	(students[0] as RescueStudent).rescue(actor)

	_runner.assert_false(room.is_cleared(), "one remaining student keeps room uncleared")
	_runner.assert_eq(room.get_rescued_count(), 1, "room tracks partial rescue progress")
	_runner.assert_eq(PoolManager.get_active_count(&"rescue_student"), 1, "rescued student returns to pool")

	(students[1] as RescueStudent).rescue(actor)

	_runner.assert_true(room.is_cleared(), "room clears after all students")
	_runner.assert_true(room.has_been_cleared(), "room marks base contract cleared")
	_runner.assert_true(exit_door.is_open(), "door opens after rescue completion")
	_runner.assert_eq(cleared_rooms.size(), 1, "room emits cleared once")
	_runner.assert_eq(rescued_payloads.size(), 2, "each student rescue emits an event")
	_runner.assert_eq(currency_payloads.size(), 2, "each student rescue emits a reward event")
	if currency_payloads.size() == 2:
		_runner.assert_eq(currency_payloads[0]["kind"], "permanent", "reward uses permanent currency")
		_runner.assert_eq(currency_payloads[0]["amount"], 3, "reward amount comes from the room")

	EventBus.student_rescued.disconnect(on_student_rescued)
	EventBus.currency_changed.disconnect(on_currency_changed)
	room.queue_free()
	actor.queue_free()


func test_rescue_student_uses_interaction_system_contract() -> void:
	var interaction_system_script := load("res://scripts/systems/interaction_system.gd") as GDScript
	var interaction_system: Node = interaction_system_script.new()
	var student := load("res://scenes/interactables/rescue_student.tscn").instantiate() as RescueStudent
	var actor := Node2D.new()
	var rescued: Array[Node] = []
	var on_rescued := func(rescued_student: Node, _source: Node) -> void:
		rescued.append(rescued_student)

	actor.position = Vector2.ZERO
	student.position = Vector2(12.0, 0.0)
	student.configure_rescue(&"interaction_student", 1)
	student.rescued.connect(on_rescued)
	add_child(actor)
	add_child(student)
	add_child(interaction_system)
	interaction_system.configure(actor, self)

	var dispatched: int = interaction_system.check_now()

	_runner.assert_eq(dispatched, 1, "interaction system dispatches to rescue student")
	_runner.assert_eq(rescued.size(), 1, "rescue student emits once")
	_runner.assert_true(student.is_rescued(), "student records rescued state")

	student.queue_free()
	actor.queue_free()
	interaction_system.queue_free()


func _instantiate_rescue_room() -> EventRoom:
	var packed := load("res://scenes/interactables/rescue_room.tscn") as PackedScene
	return packed.instantiate() as EventRoom
