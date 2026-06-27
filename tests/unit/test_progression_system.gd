extends Node
## #93/#243 ProgressionSystem — 야구부 정화 → STAGE 3 기록(배트는 정화에서 분리).
## 강화배트는 로비 퀘스트 완료(record_quest_completed)에서 해금. profile 저장/리로드.

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()


func after_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()


func test_record_baseball_captain_unlocks_stage_not_weapon() -> void:
	_runner.assert_false(ProgressionSystem.is_friend_purified(&"baseball_captain"), "처음엔 미정화")
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "처음엔 각성 배트 잠김")

	ProgressionSystem.record_friend_purified(&"baseball_captain")

	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "정화가 기록됨")
	_runner.assert_eq(ProgressionSystem.get_club_stage(&"baseball"), 3, "야구부 STAGE 3 해금")
	# #243: 정화는 더 이상 강화배트를 해금하지 않는다.
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "정화만으론 각성 배트 잠김 유지")


func test_lobby_quest_completion_unlocks_awakened_bat() -> void:
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "정화 직후엔 잠김")

	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)

	_runner.assert_true(ProgressionSystem.is_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY), "로비 퀘스트 완료 기록")
	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "로비 퀘스트 완료가 각성 배트 해금")


func test_record_quest_completed_is_idempotent() -> void:
	var events: Array[Dictionary] = []
	var cb := func(payload: Dictionary) -> void:
		events.append(payload)
	EventBus.unlock_changed.connect(cb)

	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)
	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)  # 2회차 no-op

	EventBus.unlock_changed.disconnect(cb)

	_runner.assert_eq(events.size(), 1, "퀘스트 완료 시 unlock_changed 1회만")
	if events.size() == 1:
		_runner.assert_true((events[0]["unlocks"] as Array).has(&"awakened_bat"), "payload 에 awakened_bat 해금 포함")


func test_unlock_persists_after_reload() -> void:
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)
	var profile := SaveManager.load_profile()
	_runner.assert_true(profile.has("progression"), "profile 에 progression 저장됨")

	ProgressionSystem.reload_profile()

	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "리로드 후에도 각성 배트 유지")
	_runner.assert_true(ProgressionSystem.is_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY), "리로드 후 퀘스트 완료 유지")
	_runner.assert_eq(ProgressionSystem.get_club_stage(&"baseball"), 3, "리로드 후 STAGE 3 유지")
	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "리로드 후 정화 기록 유지")


func test_unlock_changed_on_purify_excludes_weapon() -> void:
	var events: Array[Dictionary] = []
	var cb := func(payload: Dictionary) -> void:
		events.append(payload)
	EventBus.unlock_changed.connect(cb)

	ProgressionSystem.record_friend_purified(&"baseball_captain")
	ProgressionSystem.record_friend_purified(&"baseball_captain")  # 중복 — 변화 없으면 재발신 안 함

	EventBus.unlock_changed.disconnect(cb)

	_runner.assert_eq(events.size(), 1, "정화 시 unlock_changed 1회만")
	if events.size() == 1:
		var unlocks := events[0]["unlocks"] as Array
		_runner.assert_true(unlocks.has(&"baseball_stage_3"), "payload 에 baseball_stage_3 포함")
		# #243: 정화 payload 에는 강화배트가 들어가지 않는다.
		_runner.assert_false(unlocks.has(&"awakened_bat"), "정화 payload 에 awakened_bat 미포함")


func test_friend_purified_event_records_progress_without_weapon() -> void:
	EventBus.emit_friend_purified({"friend_id": &"baseball_captain", "room_id": &"friend_1", "room_type": &"friend"})

	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "friend_purified 이벤트가 진행도에 기록됨")
	# #243: 이벤트 경로로도 정화만으론 각성 배트는 잠김.
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "이벤트 경로 정화만으론 각성 배트 잠김")
