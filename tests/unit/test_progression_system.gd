extends Node
## #93 ProgressionSystem — 야구부 정화 → STAGE 3 + 각성 배트 해금, profile 저장/리로드.

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()


func after_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reload_profile()


func test_record_baseball_captain_unlocks_stage_and_weapon() -> void:
	_runner.assert_false(ProgressionSystem.is_friend_purified(&"baseball_captain"), "처음엔 미정화")
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "처음엔 각성 배트 잠김")

	ProgressionSystem.record_friend_purified(&"baseball_captain")

	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "정화가 기록됨")
	_runner.assert_eq(ProgressionSystem.get_club_stage(&"baseball"), 3, "야구부 STAGE 3 해금")
	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "각성 배트 해금")


func test_unlock_persists_after_reload() -> void:
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	var profile := SaveManager.load_profile()
	_runner.assert_true(profile.has("progression"), "profile 에 progression 저장됨")

	ProgressionSystem.reload_profile()

	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "리로드 후에도 각성 배트 유지")
	_runner.assert_eq(ProgressionSystem.get_club_stage(&"baseball"), 3, "리로드 후 STAGE 3 유지")
	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "리로드 후 정화 기록 유지")


func test_unlock_changed_emitted_once_on_purify() -> void:
	var events: Array[Dictionary] = []
	var cb := func(payload: Dictionary) -> void:
		events.append(payload)
	EventBus.unlock_changed.connect(cb)

	ProgressionSystem.record_friend_purified(&"baseball_captain")
	ProgressionSystem.record_friend_purified(&"baseball_captain")  # 중복 — 변화 없으면 재발신 안 함

	EventBus.unlock_changed.disconnect(cb)

	_runner.assert_eq(events.size(), 1, "정화 시 unlock_changed 1회만")
	if events.size() == 1:
		_runner.assert_true((events[0]["unlocks"] as Array).has(&"awakened_bat"), "payload 에 awakened_bat 해금 포함")


func test_friend_purified_event_records_progress() -> void:
	EventBus.emit_friend_purified({"friend_id": &"baseball_captain", "room_id": &"friend_1", "room_type": &"friend"})

	_runner.assert_true(ProgressionSystem.is_friend_purified(&"baseball_captain"), "friend_purified 이벤트가 진행도에 기록됨")
	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "이벤트 경로로도 각성 배트 해금")
