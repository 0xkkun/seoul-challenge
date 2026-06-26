extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()


func after_each() -> void:
	PoolManager.clear_all()


func test_acquire_release_reuses_instance() -> void:
	var scene := load("res://scenes/interactables/sample_pooled_marker.tscn") as PackedScene
	PoolManager.register_scene(&"sample_marker", scene, 0, self)

	var first := PoolManager.acquire(&"sample_marker", self)
	_runner.assert_not_null(first, "first acquire returns a node")
	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 1)

	PoolManager.release(first)
	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 0)
	_runner.assert_eq(PoolManager.get_available_count(&"sample_marker"), 1)

	var second := PoolManager.acquire(&"sample_marker", self)
	_runner.assert_true(first == second, "pool reuses released instance")
	_runner.assert_eq(second.get_meta("pool_id"), &"sample_marker")


func test_default_parent_is_scoped_to_pool_id() -> void:
	var scene := load("res://scenes/interactables/sample_pooled_marker.tscn") as PackedScene
	var first_parent := Node2D.new()
	var second_parent := Node2D.new()
	add_child(first_parent)
	add_child(second_parent)

	PoolManager.register_scene(&"first_marker", scene, 0, first_parent)
	PoolManager.register_scene(&"second_marker", scene, 0, second_parent)

	var first_marker := PoolManager.acquire(&"first_marker")
	var second_marker := PoolManager.acquire(&"second_marker")

	_runner.assert_eq(first_marker.get_parent(), first_parent)
	_runner.assert_eq(second_marker.get_parent(), second_parent)

	first_parent.queue_free()
	second_parent.queue_free()


func test_double_release_does_not_duplicate_available_instance() -> void:
	var scene := load("res://scenes/interactables/sample_pooled_marker.tscn") as PackedScene
	PoolManager.register_scene(&"sample_marker", scene, 0, self)

	var first := PoolManager.acquire(&"sample_marker", self)
	PoolManager.release(first)
	PoolManager.release(first)

	_runner.assert_eq(PoolManager.get_available_count(&"sample_marker"), 1)

	var second := PoolManager.acquire(&"sample_marker", self)
	var third := PoolManager.acquire(&"sample_marker", self)

	_runner.assert_true(first == second, "first available instance is reused")
	_runner.assert_true(third != second, "second acquire creates a different active instance")
	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 2)


func test_clear_all_ignores_nodes_freed_by_parent_cleanup() -> void:
	var scene := load("res://scenes/interactables/sample_pooled_marker.tscn") as PackedScene
	var parent := Node2D.new()
	add_child(parent)
	PoolManager.register_scene(&"sample_marker", scene, 0, parent)

	var marker := PoolManager.acquire(&"sample_marker", parent)
	marker.free()
	PoolManager.clear_all()

	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 0, "clear all drops freed active references")
