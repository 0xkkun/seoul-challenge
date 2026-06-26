extends Node

signal session_started(config: Dictionary)
signal session_finished(result: Dictionary)
signal interaction_completed(payload: Dictionary)
signal settings_changed(settings: Dictionary)


func emit_session_started(config: Dictionary) -> void:
	session_started.emit(config.duplicate(true))


func emit_session_finished(result: Dictionary) -> void:
	session_finished.emit(result.duplicate(true))


func emit_interaction_completed(payload: Dictionary) -> void:
	interaction_completed.emit(payload.duplicate(true))


func emit_settings_changed(settings: Dictionary) -> void:
	settings_changed.emit(settings.duplicate(true))
