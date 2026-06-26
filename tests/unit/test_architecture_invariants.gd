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
		"boss_defeated",
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


func test_room_palette_centralizes_placeholder_values() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/constants/room_palette.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/systems/room.gd")
	var door_source := FileAccess.get_file_as_string("res://scripts/systems/room_door.gd")

	_runner.assert_true(source.contains("const ROOM_SIZE"), "room palette defines room size")
	_runner.assert_true(source.contains("const DOOR_SIZE"), "room palette defines door size")
	_runner.assert_true(source.contains("const DOOR_LOCKED_COLOR"), "room palette defines locked door color")
	_runner.assert_true(source.contains("const DOOR_OPEN_COLOR"), "room palette defines open door color")
	_runner.assert_true(source.contains("const STUDENT_MARKER_COLOR"), "room palette defines student marker color")
	_runner.assert_true(room_source.contains("RoomPalette"), "room script reads room palette")
	_runner.assert_true(door_source.contains("RoomPalette"), "door script reads room palette")


func test_render_layers_are_centralized() -> void:
	var render_layers := FileAccess.get_file_as_string("res://scripts/constants/render_layers.gd")
	var session_root := FileAccess.get_file_as_string("res://scripts/session/session_root.gd")
	var session_ui_root := FileAccess.get_file_as_string("res://scripts/ui/session_ui_root.gd")

	for constant_name: String in [
		"WORLD_BACKGROUND_Z",
		"WORLD_ACTOR_Z",
		"WORLD_INTERACTABLE_Z",
		"WORLD_EFFECT_Z",
		"UI_SESSION_LAYER",
		"UI_MODAL_LAYER",
	]:
		_runner.assert_true(
			render_layers.contains("const %s :=" % constant_name),
			"render layer constant exists: %s" % constant_name
		)

	_runner.assert_true(
		session_root.contains("RenderLayers.WORLD_BACKGROUND_Z"),
		"session root uses render layer constants for world background"
	)
	_runner.assert_true(
		session_root.contains("RenderLayers.WORLD_ACTOR_Z"),
		"session root uses render layer constants for actors"
	)
	_runner.assert_true(
		session_root.contains("RenderLayers.WORLD_INTERACTABLE_Z"),
		"session root uses render layer constants for interactables"
	)
	_runner.assert_true(
		session_root.contains("RenderLayers.WORLD_EFFECT_Z"),
		"session root uses render layer constants for effects"
	)
	_runner.assert_true(
		session_ui_root.contains("RenderLayers.UI_SESSION_LAYER"),
		"session UI uses render layer constants"
	)
