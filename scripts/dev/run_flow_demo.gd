extends Node2D

@export var auto_run := true
@export var quit_on_complete := true

@onready var run_controller: RunController = %RunController
@onready var room_layer: Node2D = %RoomLayer
@onready var actor: Node2D = %DemoActor

var _finished_payloads: Array[Dictionary] = []


func _ready() -> void:
	EventBus.session_finished.connect(_on_session_finished)
	run_controller.room_changed.connect(_on_room_changed)
	run_controller.run_completed.connect(_on_run_completed)
	run_controller.configure(run_controller.layout, room_layer, actor)
	if auto_run:
		call_deferred("_run_demo")


func _exit_tree() -> void:
	if EventBus.session_finished.is_connected(_on_session_finished):
		EventBus.session_finished.disconnect(_on_session_finished)


func _run_demo() -> void:
	if not run_controller.start_run():
		_fail_demo("run did not start")
		return

	await get_tree().process_frame
	var guard := 0
	while not run_controller.is_completed():
		guard += 1
		if guard > 9:
			_fail_demo("run guard exceeded")
			return
		var before_room_id := run_controller.get_current_room_id()
		resolve_current_room_for_demo()
		var advanced := run_controller.advance_room()
		print("[run_flow_demo] advance from %s advanced=%s completed=%s" % [
			before_room_id,
			str(advanced),
			str(run_controller.is_completed()),
		])
		if not advanced and not run_controller.is_completed():
			_fail_demo("run stalled at %s" % before_room_id)
			return
		await get_tree().process_frame

	if _finished_payloads.is_empty():
		_fail_demo("session_finished event was not emitted")
		return

	print("[run_flow_demo] OK: run completed rooms=%s" % [run_controller.visited_room_ids])
	if quit_on_complete:
		get_tree().quit(0)


func _on_room_changed(room_id: StringName, room_type: StringName) -> void:
	var current_room := run_controller.get_current_room()
	if current_room != null:
		actor.global_position = current_room.global_position
	print("[run_flow_demo] room_changed %s type=%s" % [room_id, room_type])


func resolve_current_room_for_demo() -> void:
	var current_room := run_controller.get_current_room()
	if current_room == null:
		return
	if run_controller.room_manager != null and run_controller.room_manager.is_current_room_cleared():
		return
	if current_room.has_method("get_active_enemies"):
		for enemy: Node in current_room.call("get_active_enemies"):
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", 99)
	elif current_room.has_method("get_active_students"):
		for student: Node in current_room.call("get_active_students"):
			if student.has_method("rescue"):
				student.call("rescue", actor)
	elif current_room.has_method("pick_up"):
		current_room.call("pick_up", actor)
	elif current_room.has_method("get_active_friends"):
		for friend: Node in current_room.call("get_active_friends"):
			if friend.has_signal("purified"):
				friend.emit_signal("purified", friend)
	elif current_room.has_method("complete_boss_encounter"):
		current_room.call("complete_boss_encounter")


func _on_run_completed(result: Dictionary) -> void:
	print("[run_flow_demo] run_completed %s" % [result])


func _on_session_finished(result: Dictionary) -> void:
	_finished_payloads.append(result)
	print("[run_flow_demo] session_finished %s" % [result])


func _fail_demo(message: String) -> void:
	push_error("[run_flow_demo] FAIL: %s" % message)
	if quit_on_complete:
		get_tree().quit(1)
