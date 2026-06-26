extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_interaction_system_uses_group_dispatch() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/systems/interaction_system.gd")
	_runner.assert_true(source.contains("get_nodes_in_group"), "interaction dispatch uses group scan")
	_runner.assert_true(source.contains("check_interaction"), "interaction dispatch calls interface")
	_runner.assert_false(source.contains(" is Sample"), "interaction dispatch avoids sample-specific branches")


func test_template_surface_avoids_private_reference() -> void:
	var private_term := "PRIVATE_PROJECT_REFERENCE"
	var checked_files := [
		"res://README.md",
		"res://AGENTS.md",
		"res://project.godot",
		"res://docs/customizing.md",
	]
	for path: String in checked_files:
		if FileAccess.file_exists(path):
			var content := FileAccess.get_file_as_string(path)
			_runner.assert_false(content.contains(private_term), "%s avoids private reference" % path)


func test_room_event_bus_surface_uses_payload_wrappers() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/autoload/event_bus.gd")
	var event_names := [
		"room_entered",
		"room_cleared",
		"student_rescued",
		"friend_purified",
		"currency_changed",
	]
	for event_name: String in event_names:
		_runner.assert_true(
			source.contains("signal %s(payload: Dictionary)" % event_name),
			"%s signal exists" % event_name
		)
		_runner.assert_true(
			source.contains("func emit_%s(payload: Dictionary) -> void:" % event_name),
			"%s wrapper exists" % event_name
		)
		_runner.assert_true(
			source.contains("%s.emit(payload.duplicate(true))" % event_name),
			"%s wrapper duplicates payload" % event_name
		)
