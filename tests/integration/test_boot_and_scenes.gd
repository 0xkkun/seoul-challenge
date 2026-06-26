extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_required_scenes_instantiate() -> void:
	var scene_paths := [
		"res://scenes/lobby/lobby.tscn",
		"res://scenes/session/session_root.tscn",
		"res://scenes/dev/main_dev.tscn",
	]
	for path: String in scene_paths:
		var packed := load(path) as PackedScene
		_runner.assert_not_null(packed, "%s loads" % path)
		var instance := packed.instantiate()
		_runner.assert_not_null(instance, "%s instantiates" % path)
		add_child(instance)
		instance.queue_free()


func test_autoloads_are_available() -> void:
	var names := [
		"GameManager",
		"EventBus",
		"SceneTransition",
		"SaveManager",
		"Settings",
		"AudioManager",
		"PoolManager",
		"PlatformManager",
	]
	for autoload_name: String in names:
		_runner.assert_true(has_node("/root/" + autoload_name), "%s autoload exists" % autoload_name)
