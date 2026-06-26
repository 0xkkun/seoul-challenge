extends Node

var _active_config: Dictionary = {}
var _last_result: Dictionary = {}
var _session_active := false


func start_session(config: Dictionary = {}) -> void:
	_active_config = config.duplicate(true)
	_session_active = true
	if has_node("/root/EventBus"):
		EventBus.emit_session_started(_active_config)


func finish_session(result: Dictionary = {}) -> void:
	_last_result = result.duplicate(true)
	_session_active = false
	if has_node("/root/SaveManager"):
		SaveManager.save_session_result(_last_result)
	if has_node("/root/EventBus"):
		EventBus.emit_session_finished(_last_result)


func reset_session() -> void:
	_active_config.clear()
	_last_result.clear()
	_session_active = false


func is_session_active() -> bool:
	return _session_active


func get_active_config() -> Dictionary:
	return _active_config.duplicate(true)


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)
