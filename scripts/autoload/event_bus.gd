extends Node

signal session_started(config: Dictionary)
signal session_finished(result: Dictionary)
signal interaction_completed(payload: Dictionary)
signal room_entered(payload: Dictionary)
signal room_cleared(payload: Dictionary)
signal student_rescued(payload: Dictionary)
signal friend_purified(payload: Dictionary)
signal currency_changed(payload: Dictionary)
signal settings_changed(settings: Dictionary)


func emit_session_started(config: Dictionary) -> void:
	session_started.emit(config.duplicate(true))


func emit_session_finished(result: Dictionary) -> void:
	session_finished.emit(result.duplicate(true))


func emit_interaction_completed(payload: Dictionary) -> void:
	interaction_completed.emit(payload.duplicate(true))


func emit_room_entered(payload: Dictionary) -> void:
	room_entered.emit(payload.duplicate(true))


func emit_room_cleared(payload: Dictionary) -> void:
	room_cleared.emit(payload.duplicate(true))


func emit_student_rescued(payload: Dictionary) -> void:
	student_rescued.emit(payload.duplicate(true))


func emit_friend_purified(payload: Dictionary) -> void:
	friend_purified.emit(payload.duplicate(true))


func emit_currency_changed(payload: Dictionary) -> void:
	currency_changed.emit(payload.duplicate(true))


func emit_settings_changed(settings: Dictionary) -> void:
	settings_changed.emit(settings.duplicate(true))
