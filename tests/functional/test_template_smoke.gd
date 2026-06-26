extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()
	GameManager.reset_session()


func after_each() -> void:
	PoolManager.clear_all()
	GameManager.reset_session()


func test_boot_start_interact_finish() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	_runner.assert_true(GameManager.is_session_active(), "session starts on ready")

	var actor: Node2D = session.get_node("%Player")
	var step: Vector2 = actor.step_velocity(Vector2.ZERO, Vector2.RIGHT, 1.0 / 60.0)
	_runner.assert_true(step.x > 0.0, "player responds to input path")

	session.trigger_sample_interaction()
	_runner.assert_eq(session.completed_interactions, 1, "sample interaction completes")

	var marker: Node = session.spawn_sample_marker()
	_runner.assert_not_null(marker, "pooled marker can be acquired")
	PoolManager.release(marker)
	_runner.assert_eq(PoolManager.get_available_count(&"sample_marker"), 1)

	var result: Dictionary = session.finish_session()
	_runner.assert_eq(result["interactions"], 1)

	session.queue_free()
