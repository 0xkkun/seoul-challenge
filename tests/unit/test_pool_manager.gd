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


func test_clear_pool_removes_only_target_registration_and_nodes() -> void:
	var scene := load("res://scenes/interactables/sample_pooled_marker.tscn") as PackedScene
	var target_parent := Node2D.new()
	var other_parent := Node2D.new()
	add_child(target_parent)
	add_child(other_parent)
	PoolManager.register_scene(&"floating_combat_text", scene, 2, target_parent)
	PoolManager.register_scene(&"other_pool", scene, 1, other_parent)
	var target_active := PoolManager.acquire(&"floating_combat_text")
	var target_available: Node = (PoolManager.get("_available") as Dictionary)[&"floating_combat_text"][0]
	var other_active := PoolManager.acquire(&"other_pool")

	_runner.assert_true(PoolManager.has_method("clear_pool"), "pool manager exposes targeted teardown")
	_runner.assert_true(PoolManager.has_method("has_pool"), "pool manager exposes registration state")
	if not PoolManager.has_method("clear_pool") or not PoolManager.has_method("has_pool"):
		return
	_runner.assert_true(bool(PoolManager.call("has_pool", &"floating_combat_text")), "target pool starts registered")
	PoolManager.call("clear_pool", &"floating_combat_text")
	_runner.assert_false(bool(PoolManager.call("has_pool", &"floating_combat_text")), "clear_pool erases target registration")
	_runner.assert_eq(PoolManager.get_active_count(&"floating_combat_text"), 0, "target active list is gone")
	_runner.assert_eq(PoolManager.get_available_count(&"floating_combat_text"), 0, "target available list is gone")
	_runner.assert_false(is_instance_valid(target_active), "target active node is freed")
	_runner.assert_false(is_instance_valid(target_available), "target available node is freed")
	_runner.assert_true(bool(PoolManager.call("has_pool", &"other_pool")), "unrelated pool stays registered")
	_runner.assert_true(is_instance_valid(other_active), "unrelated active node stays alive")
	_runner.assert_not_null(PoolManager.acquire(&"other_pool"), "unrelated pool remains usable")
