extends Node

const HIT_STOP_MANAGER_PATH := "res://scripts/autoload/hit_stop_manager.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Engine.time_scale = 1.0


func after_each() -> void:
	Engine.time_scale = 1.0
	for child: Node in get_children():
		child.queue_free()


func test_hit_stop_is_registered_as_process_always_autoload() -> void:
	_runner.assert_true(ResourceLoader.exists(HIT_STOP_MANAGER_PATH), "hit stop manager script exists")
	_runner.assert_true(has_node("/root/HitStopManager"), "hit stop manager is registered as an autoload")
	if has_node("/root/HitStopManager"):
		_runner.assert_eq(get_node("/root/HitStopManager").process_mode, Node.PROCESS_MODE_ALWAYS, "hit stop manager processes during scaled/paused time")


func test_longer_request_replaces_shorter_and_shorter_is_ignored() -> void:
	var manager := _new_manager()
	if manager == null:
		return
	_runner.assert_true(bool(manager.call("request", 0.10, 0.05)), "first hit stop starts")
	_runner.assert_eq(Engine.time_scale, 0.05, "first request applies its scale")
	_runner.assert_false(bool(manager.call("request", 0.04, 0.2)), "shorter request cannot cut off the active hit stop")
	_runner.assert_eq(Engine.time_scale, 0.05, "ignored request cannot change active scale")
	_runner.assert_true(bool(manager.call("request", 0.18, 0.08)), "longer request replaces the remaining window")
	_runner.assert_eq(Engine.time_scale, 0.08, "longer request applies its scale")
	_runner.assert_eq(float(manager.call("get_remaining_real_seconds")), 0.18, "longer request replaces remaining real time")
	manager.call("restore")


func test_scaled_delta_is_converted_back_to_real_time() -> void:
	var manager := _new_manager()
	if manager == null:
		return
	manager.call("request", 0.10, 0.05)
	manager.call("_process", 0.0025)
	_runner.assert_true(is_equal_approx(float(manager.call("get_remaining_real_seconds")), 0.05), "scaled delta 0.0025 at 0.05 scale equals 0.05 real seconds")
	_runner.assert_eq(Engine.time_scale, 0.05, "hit stop remains active before real duration ends")
	manager.call("_process", 0.0025)
	_runner.assert_eq(Engine.time_scale, 1.0, "manager restores normal time exactly at the real-time boundary")
	_runner.assert_false(bool(manager.call("is_active")), "manager is inactive after restoration")


func test_restore_always_forces_normal_time_and_clears_remaining() -> void:
	var manager := _new_manager()
	if manager == null:
		return
	manager.call("request", 0.5, 0.01)
	manager.call("restore")
	_runner.assert_eq(Engine.time_scale, 1.0, "restore always forces normal time")
	_runner.assert_eq(float(manager.call("get_remaining_real_seconds")), 0.0, "restore clears the remaining window")
	manager.call("restore")
	_runner.assert_eq(Engine.time_scale, 1.0, "restore is idempotent")


func test_request_rejects_nonpositive_duration_and_clamps_extremes() -> void:
	var manager := _new_manager()
	if manager == null:
		return
	_runner.assert_false(bool(manager.call("request", 0.0, 0.0)), "zero duration cannot start hit stop")
	_runner.assert_false(bool(manager.call("request", -0.1, -1.0)), "negative duration cannot start hit stop")
	_runner.assert_eq(Engine.time_scale, 1.0, "rejected requests cannot change global time")

	_runner.assert_true(bool(manager.call("request", 2.0, -1.0)), "positive request starts after invalid requests")
	_runner.assert_eq(float(manager.call("get_remaining_real_seconds")), 1.0, "duration is capped at one real second")
	_runner.assert_eq(float(manager.call("get_active_scale")), 0.01, "scale is clamped to the safe lower bound")
	manager.call("restore")

	_runner.assert_true(bool(manager.call("request", 0.5, 3.0)), "upper-scale request starts")
	_runner.assert_eq(float(manager.call("get_active_scale")), 1.0, "scale is clamped to normal time")
	manager.call("restore")


func _new_manager() -> Node:
	_runner.assert_true(ResourceLoader.exists(HIT_STOP_MANAGER_PATH), "hit stop manager script exists")
	if not ResourceLoader.exists(HIT_STOP_MANAGER_PATH):
		return null
	var script := load(HIT_STOP_MANAGER_PATH) as Script
	var manager := script.new() as Node
	add_child(manager)
	return manager
