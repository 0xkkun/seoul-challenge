extends Node

const PROFILE_PERMANENT_CURRENCY_KEY := "permanent_currency"
const SYSTEM_EVENT_SOURCE := "CurrencySystem"
const ROOM_CLEAR_PERMANENT_REWARD := 1
const STUDENT_RESCUED_PERMANENT_REWARD := 1
const FRIEND_PURIFIED_PERMANENT_REWARD := 1
const BOSS_DEFEATED_PERMANENT_REWARD := 1

var _ingame := 0
var _permanent := 0


func _ready() -> void:
	reload_profile()
	_connect_event_signals()


func get_ingame() -> int:
	return _ingame


func get_permanent() -> int:
	return _permanent


func reload_profile() -> void:
	if not has_node("/root/SaveManager"):
		_permanent = 0
		return

	var profile := SaveManager.load_profile()
	_permanent = _non_negative_int(profile.get(PROFILE_PERMANENT_CURRENCY_KEY, 0))


func reset_for_tests() -> void:
	_ingame = 0
	reload_profile()


func _connect_event_signals() -> void:
	if not has_node("/root/EventBus"):
		return

	_connect_event(&"room_cleared", Callable(self, "_on_room_cleared"))
	_connect_event(&"student_rescued", Callable(self, "_on_student_rescued"))
	_connect_event(&"friend_purified", Callable(self, "_on_friend_purified"))
	_connect_event(&"boss_defeated", Callable(self, "_on_boss_defeated"))
	_connect_event(&"currency_changed", Callable(self, "_on_currency_changed"))
	_connect_event(&"run_ended", Callable(self, "_on_run_ended"))
	_connect_event(&"returned_to_school", Callable(self, "_on_returned_to_school"))
	_connect_event(&"session_finished", Callable(self, "_on_session_finished"))


func _connect_event(signal_name: StringName, target: Callable) -> void:
	if not EventBus.has_signal(signal_name):
		return
	if EventBus.is_connected(signal_name, target):
		return
	EventBus.connect(signal_name, target)


func _on_room_cleared(payload: Dictionary) -> void:
	_change_permanent(_reward_amount(payload, ROOM_CLEAR_PERMANENT_REWARD), "room_cleared")


func _on_student_rescued(payload: Dictionary) -> void:
	_change_permanent(_reward_amount(payload, STUDENT_RESCUED_PERMANENT_REWARD), "student_rescued")


func _on_friend_purified(payload: Dictionary) -> void:
	_change_permanent(_reward_amount(payload, FRIEND_PURIFIED_PERMANENT_REWARD), "friend_purified")


func _on_boss_defeated(payload: Dictionary) -> void:
	_change_permanent(_reward_amount(payload, BOSS_DEFEATED_PERMANENT_REWARD), "boss_defeated")


func _on_currency_changed(payload: Dictionary) -> void:
	if payload.get("source", "") == SYSTEM_EVENT_SOURCE:
		return

	var amount := _int_value(payload.get("amount", 0))
	match String(payload.get("kind", "")).to_lower():
		"ingame":
			_change_ingame(amount, "currency_changed")
		"permanent":
			_change_permanent(amount, "currency_changed")


func _on_run_ended(_payload: Dictionary = {}) -> void:
	_reset_ingame("run_ended")


func _on_returned_to_school(_payload: Dictionary = {}) -> void:
	_reset_ingame("returned_to_school")


func _on_session_finished(_payload: Dictionary = {}) -> void:
	_reset_ingame("session_finished")


func _change_ingame(amount: int, reason: String) -> void:
	var next := _ingame + amount
	if next < 0:
		next = 0
	var delta := next - _ingame
	if delta == 0:
		return

	_ingame = next
	_emit_currency_changed("ingame", delta, reason)


func _change_permanent(amount: int, reason: String) -> void:
	var next := _permanent + amount
	if next < 0:
		next = 0
	var delta := next - _permanent
	if delta == 0:
		return

	_permanent = next
	_save_permanent()
	_emit_currency_changed("permanent", delta, reason)


func _reset_ingame(reason: String) -> void:
	if _ingame == 0:
		return

	var delta := -_ingame
	_ingame = 0
	_emit_currency_changed("ingame", delta, reason)


func _save_permanent() -> void:
	if not has_node("/root/SaveManager"):
		return

	var profile := SaveManager.load_profile()
	profile[PROFILE_PERMANENT_CURRENCY_KEY] = _permanent
	SaveManager.save_profile(profile)


func _emit_currency_changed(kind: String, amount: int, reason: String) -> void:
	if not has_node("/root/EventBus"):
		return

	EventBus.emit_currency_changed({
		"kind": kind,
		"amount": amount,
		"ingame": _ingame,
		"permanent": _permanent,
		"source": SYSTEM_EVENT_SOURCE,
		"reason": reason,
	})


func _reward_amount(payload: Dictionary, fallback: int) -> int:
	for key: String in ["permanent_amount", "reward_amount", "amount", "reward"]:
		if payload.has(key):
			return _non_negative_int(payload[key])
	return fallback


func _non_negative_int(value: Variant) -> int:
	var amount := _int_value(value)
	if amount < 0:
		return 0
	return amount


func _int_value(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)

	var text := str(value)
	if text.is_valid_int():
		return int(text)
	return 0
