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
