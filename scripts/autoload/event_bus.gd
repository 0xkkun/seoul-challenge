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
## #154 액션쾌감 피드백 — payload 예 {"kind": StringName, "intensity": float, "direction": Vector2}.
## 전투 객체는 피드백 의도만 발신하고, 카메라/이펙트/HUD 쪽이 구독해 표현한다.
signal combat_feedback(payload: Dictionary)
signal settings_changed(settings: Dictionary)
## #19 밤 전투 계약: 플레이어 체력 변화 — payload {"current": int, "max": int}.
## 전투 트랙은 emit_player_health_changed() 로 발신, HUD(#13) 등은 구독만 한다.
signal player_health_changed(payload: Dictionary)
## #19 밤 전투 계약: 플레이어 사망 — payload 예 {"cause": String}. 런 종료/귀환 트리거.
## 전투 트랙은 emit_player_died() 로 발신, 재선언하지 말 것.
signal player_died(payload: Dictionary)
## #93 진행도 해금 변경 — payload 예 {"friend_id": StringName, "unlocks": Array, "club_stages": Dictionary}.
## ProgressionSystem 이 정화 기록 후 발신, UI(허브/결과창)는 구독만 한다.
signal unlock_changed(payload: Dictionary)


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


func emit_combat_feedback(payload: Dictionary) -> void:
	combat_feedback.emit(payload.duplicate(true))


func emit_settings_changed(settings: Dictionary) -> void:
	settings_changed.emit(settings.duplicate(true))


func emit_player_health_changed(payload: Dictionary) -> void:
	player_health_changed.emit(payload.duplicate(true))


func emit_player_died(payload: Dictionary) -> void:
	player_died.emit(payload.duplicate(true))


func emit_unlock_changed(payload: Dictionary) -> void:
	unlock_changed.emit(payload.duplicate(true))
