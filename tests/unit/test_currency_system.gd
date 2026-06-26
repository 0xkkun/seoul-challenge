extends Node

const SYSTEM_EVENT_SOURCE := "CurrencySystem"

var _runner: Node
var _system_payloads: Array[Dictionary] = []


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	_system_payloads.clear()
	EventBus.currency_changed.connect(_record_currency_payload)


func after_each() -> void:
	if EventBus.currency_changed.is_connected(_record_currency_payload):
		EventBus.currency_changed.disconnect(_record_currency_payload)
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	_system_payloads.clear()


func test_room_and_reward_events_increase_permanent_and_persist() -> void:
	EventBus.emit_room_cleared({})
	EventBus.emit_student_rescued({"reward_amount": 3})
	EventBus.emit_friend_purified({"permanent_amount": 4})

	var profile := SaveManager.load_profile()

	_runner.assert_eq(CurrencySystem.get_permanent(), 8, "permanent currency includes all rewards")
	_runner.assert_eq(profile[CurrencySystem.PROFILE_PERMANENT_CURRENCY_KEY], 8, "permanent currency is saved")
	_runner.assert_eq(_system_payloads.size(), 3, "each reward emits a HUD currency update")
	_runner.assert_eq(_system_payloads[0]["kind"], "permanent")
	_runner.assert_eq(_system_payloads[2]["permanent"], 8, "last payload includes latest permanent balance")


func test_currency_changed_applies_ingame_and_permanent_deltas() -> void:
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 7})
	EventBus.emit_currency_changed({"kind": "ingame", "amount": -2})
	EventBus.emit_currency_changed({"kind": "permanent", "amount": 5})

	var profile := SaveManager.load_profile()

	_runner.assert_eq(CurrencySystem.get_ingame(), 5, "ingame currency applies add and spend deltas")
	_runner.assert_eq(CurrencySystem.get_permanent(), 5, "permanent currency applies direct deltas")
	_runner.assert_eq(profile[CurrencySystem.PROFILE_PERMANENT_CURRENCY_KEY], 5, "permanent delta is saved")
	_runner.assert_eq(_system_payloads.size(), 3, "processed deltas are re-emitted once")
	_runner.assert_eq(_system_payloads[1]["amount"], -2, "spend delta is preserved in emitted payload")


func test_session_finish_resets_ingame_only() -> void:
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 6})
	EventBus.emit_currency_changed({"kind": "permanent", "amount": 2})
	EventBus.emit_session_finished({"result": "test"})

	var profile := SaveManager.load_profile()

	_runner.assert_eq(CurrencySystem.get_ingame(), 0, "run end clears ingame currency")
	_runner.assert_eq(CurrencySystem.get_permanent(), 2, "run end keeps permanent currency")
	_runner.assert_eq(profile[CurrencySystem.PROFILE_PERMANENT_CURRENCY_KEY], 2, "run end keeps saved permanent currency")
	_runner.assert_eq(_system_payloads[2]["kind"], "ingame")
	_runner.assert_eq(_system_payloads[2]["amount"], -6, "reset emits the removed ingame amount")


func test_reload_profile_restores_permanent_without_ingame() -> void:
	var profile := SaveManager.load_profile()
	profile[CurrencySystem.PROFILE_PERMANENT_CURRENCY_KEY] = 11
	SaveManager.save_profile(profile)
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 4})

	CurrencySystem.reset_for_tests()

	_runner.assert_eq(CurrencySystem.get_ingame(), 0, "ingame currency remains memory-only")
	_runner.assert_eq(CurrencySystem.get_permanent(), 11, "permanent currency reloads from profile")


func test_student_rescue_without_reward_amount_does_not_guess_reward() -> void:
	EventBus.emit_student_rescued({"student_id": &"student"})

	_runner.assert_eq(CurrencySystem.get_permanent(), 0, "student rescue reward requires an explicit amount")
	_runner.assert_eq(_system_payloads.size(), 0, "missing reward amount does not emit a guessed reward")


func _record_currency_payload(payload: Dictionary) -> void:
	if payload.get("source", "") == SYSTEM_EVENT_SOURCE:
		_system_payloads.append(payload.duplicate(true))
