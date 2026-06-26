extends Node

signal session_started(config: Dictionary)
signal session_finished(result: Dictionary)
signal interaction_completed(payload: Dictionary)
signal room_entered(payload: Dictionary)
signal room_cleared(payload: Dictionary)
signal student_rescued(payload: Dictionary)
signal friend_purified(payload: Dictionary)
signal boss_defeated(payload: Dictionary)
signal currency_changed(payload: Dictionary)
signal special_skill_state_changed(payload: Dictionary)
signal settings_changed(settings: Dictionary)
## #19 밤 전투 계약: 플레이어 체력 변화 — payload {"current": int, "max": int}.
## 전투 트랙은 emit_player_health_changed() 로 발신, HUD(#13) 등은 구독만 한다.
signal player_health_changed(payload: Dictionary)
## #19 밤 전투 계약: 플레이어 사망 — payload 예 {"cause": String}. 런 종료/귀환 트리거.
## 전투 트랙은 emit_player_died() 로 발신, 재선언하지 말 것.
signal player_died(payload: Dictionary)


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


func emit_boss_defeated(payload: Dictionary) -> void:
	boss_defeated.emit(payload.duplicate(true))


func emit_currency_changed(payload: Dictionary) -> void:
	currency_changed.emit(payload.duplicate(true))


func emit_special_skill_state_changed(payload: Dictionary) -> void:
	special_skill_state_changed.emit(payload.duplicate(true))


func emit_settings_changed(settings: Dictionary) -> void:
	settings_changed.emit(settings.duplicate(true))


func emit_player_health_changed(payload: Dictionary) -> void:
	player_health_changed.emit(payload.duplicate(true))


func emit_player_died(payload: Dictionary) -> void:
	player_died.emit(payload.duplicate(true))
