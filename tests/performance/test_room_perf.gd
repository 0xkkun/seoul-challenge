extends Node

const LAYOUT_PATH := "res://resources/layouts/gyeongbokgung.tres"

const GENERATED_LAYOUT_COUNT := 200
const GENERATED_LAYOUT_BUDGET_USEC := 200000
const REQUEST_NEXT_ROOM_BUDGET_USEC := 20000
const LAYOUT_VALIDATION_BUDGET_USEC := 20000

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()
	if has_node("/root/PoolManager"):
		PoolManager.clear_all()


func test_room_layout_generator_two_hundred_seeds_stays_under_budget() -> void:
	var generator := RoomLayoutGenerator.new()
	var invalid_count := 0
	var started_at := Time.get_ticks_usec()
	for layout_seed in range(GENERATED_LAYOUT_COUNT):
		var layout := generator.generate(layout_seed)
		if layout.validate_layout().size() != 0:
			invalid_count += 1
	var elapsed := Time.get_ticks_usec() - started_at

	_runner.assert_eq(invalid_count, 0, "all generated layouts validate")
	_runner.assert_true(
		elapsed <= GENERATED_LAYOUT_BUDGET_USEC,
		"200 generated layouts took %dus, budget %dus" % [elapsed, GENERATED_LAYOUT_BUDGET_USEC]
	)


func test_layout_connectivity_validation_stays_under_budget() -> void:
	var layout := _load_layout()
	var started_at := Time.get_ticks_usec()
	var errors := layout.validate_layout()
	var elapsed := Time.get_ticks_usec() - started_at

	_runner.assert_eq(errors.size(), 0, "fixed layout validates")
	_runner.assert_true(
		elapsed <= LAYOUT_VALIDATION_BUDGET_USEC,
		"layout validation took %dus, budget %dus" % [elapsed, LAYOUT_VALIDATION_BUDGET_USEC]
	)


func test_room_manager_request_next_room_stays_under_budget() -> void:
	var layout := _load_layout()
	_warm_room_scene_resources(layout)
	var container := Node2D.new()
	var actor := Node2D.new()
	var manager := RoomManager.new()
	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "manager starts layout")

	var started_at := Time.get_ticks_usec()
	var advanced := manager.request_next_room()
	var elapsed := Time.get_ticks_usec() - started_at

	_runner.assert_true(advanced, "manager advances to the next room")
	_runner.assert_eq(manager.current_room_id, &"combat_1", "manager enters the first combat room")
	_runner.assert_true(
		elapsed <= REQUEST_NEXT_ROOM_BUDGET_USEC,
		"request_next_room took %dus, budget %dus" % [elapsed, REQUEST_NEXT_ROOM_BUDGET_USEC]
	)


func test_room_manager_runtime_walks_fixed_route() -> void:
	var layout := _load_layout()
	var container := Node2D.new()
	var actor := Node2D.new()
	var manager := RoomManager.new()
	var completed_layouts: Array[StringName] = []
	var on_layout_completed := func(layout_id: StringName) -> void:
		completed_layouts.append(layout_id)

	add_child(container)
	add_child(actor)
	add_child(manager)
	manager.layout_completed.connect(on_layout_completed)
	manager.configure(layout, container, actor)

	_runner.assert_true(manager.start_layout(), "runtime starts room manager")
	for expected_room_id: StringName in [&"combat_1", &"combat_2", &"event_1", &"final_1"]:
		_runner.assert_true(manager.request_next_room(), "runtime advances to %s" % expected_room_id)
		_runner.assert_eq(manager.current_room_id, expected_room_id)
		_resolve_current_room(manager, actor)

	_runner.assert_false(manager.request_next_room(), "runtime reports route completion after final")
	_runner.assert_eq(completed_layouts, [&"gyeongbokgung"], "runtime emits layout completion")
	manager.layout_completed.disconnect(on_layout_completed)


func _load_layout() -> RoomLayout:
	var layout := load(LAYOUT_PATH) as RoomLayout
	_runner.assert_not_null(layout, "layout resource loads")
	return layout


func _warm_room_scene_resources(layout: RoomLayout) -> void:
	for room_def: RoomDef in layout.room_defs:
		if room_def == null:
			continue
		_runner.assert_not_null(load(room_def.scene_path), "room scene resource warms: %s" % room_def.scene_path)


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
