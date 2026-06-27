extends Node
## #51 공용 상태이상 컨트롤러.
##
## 시간형 효과를 액터의 런타임 자식으로 보관한다. 액터는 이 컨트롤러에
## tick 을 위임하고, 이동/행동 차단과 이동 배속만 질의한다.

signal effect_applied(effect_id: StringName, payload: Dictionary)
signal effect_removed(effect_id: StringName)
signal effect_ticked(effect_id: StringName, payload: Dictionary)

const EFFECT_STUN := &"stun"
const EFFECT_ROOT := &"root"
const EFFECT_SLOW := &"slow"
const EFFECT_POISON := &"poison"
const EFFECT_CLEANSE := &"cleanse"
const EFFECT_FREEZE := &"freeze"
const EFFECT_SILENCE := &"silence"
const EFFECT_HASTE := &"haste"

const DEFAULT_SLOW_MULTIPLIER := 0.5
const DEFAULT_HASTE_MULTIPLIER := 1.25
const DEFAULT_POISON_DAMAGE := 1
const DEFAULT_POISON_TICK_INTERVAL := 1.0

var _effects: Dictionary = {}


func apply_effect(effect_id: StringName, duration: float, params: Dictionary = {}) -> void:
	if effect_id == EFFECT_CLEANSE:
		clear_negative_effects()
	if duration <= 0.0:
		return

	var entry := _build_entry(effect_id, duration, params)
	if not _effects.has(effect_id):
		_effects[effect_id] = []
	(_effects[effect_id] as Array).append(entry)
	effect_applied.emit(effect_id, entry.duplicate(true))


func tick(delta: float, target: Node = null) -> void:
	if delta <= 0.0:
		return
	for effect_id: StringName in _effects.keys():
		var entries: Array = _effects.get(effect_id, [])
		for index in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[index]
			var active_delta: float = minf(delta, maxf(0.0, float(entry.get("remaining", 0.0))))
			if effect_id == EFFECT_POISON:
				_tick_poison(entry, active_delta, target)
			entry["remaining"] = float(entry.get("remaining", 0.0)) - delta
			if float(entry["remaining"]) <= 0.0:
				entries.remove_at(index)
		if entries.is_empty():
			_effects.erase(effect_id)
			effect_removed.emit(effect_id)
		else:
			_effects[effect_id] = entries


func has_effect(effect_id: StringName) -> bool:
	return _effects.has(effect_id) and not (_effects[effect_id] as Array).is_empty()


func clear_effect(effect_id: StringName) -> void:
	if not _effects.has(effect_id):
		return
	_effects.erase(effect_id)
	effect_removed.emit(effect_id)


func clear_negative_effects() -> void:
	for effect_id: StringName in _effects.keys():
		if is_negative_effect(effect_id):
			clear_effect(effect_id)


func get_speed_multiplier() -> float:
	var multiplier := 1.0
	for entry: Dictionary in _effects.get(EFFECT_SLOW, []):
		multiplier = minf(multiplier, _entry_speed_multiplier(entry, DEFAULT_SLOW_MULTIPLIER))
	for entry: Dictionary in _effects.get(EFFECT_HASTE, []):
		multiplier = maxf(multiplier, _entry_speed_multiplier(entry, DEFAULT_HASTE_MULTIPLIER))
	return maxf(0.0, multiplier)


func blocks_movement() -> bool:
	return has_effect(EFFECT_STUN) or has_effect(EFFECT_ROOT) or has_effect(EFFECT_FREEZE)


func blocks_actions() -> bool:
	return has_effect(EFFECT_STUN) or has_effect(EFFECT_FREEZE)


func is_negative_effect(effect_id: StringName) -> bool:
	return (
		effect_id == EFFECT_STUN
		or effect_id == EFFECT_ROOT
		or effect_id == EFFECT_SLOW
		or effect_id == EFFECT_POISON
		or effect_id == EFFECT_FREEZE
		or effect_id == EFFECT_SILENCE
	)


func get_active_effect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for effect_id: StringName in _effects.keys():
		if has_effect(effect_id):
			ids.append(effect_id)
	ids.sort()
	return ids


func get_effect_remaining(effect_id: StringName) -> float:
	var remaining := 0.0
	for entry: Dictionary in _effects.get(effect_id, []):
		remaining = maxf(remaining, float(entry.get("remaining", 0.0)))
	return remaining


func _build_entry(effect_id: StringName, duration: float, params: Dictionary) -> Dictionary:
	var entry := params.duplicate(true)
	entry["duration"] = maxf(0.0, duration)
	entry["remaining"] = maxf(0.0, duration)
	if effect_id == EFFECT_POISON:
		entry["damage"] = maxi(0, int(entry.get("damage", DEFAULT_POISON_DAMAGE)))
		var interval := maxf(0.001, float(entry.get("tick_interval", DEFAULT_POISON_TICK_INTERVAL)))
		entry["tick_interval"] = interval
		entry["tick_timer"] = float(entry.get("tick_timer", interval))
	return entry


func _tick_poison(entry: Dictionary, delta: float, target: Node) -> void:
	if delta <= 0.0 or target == null or not target.has_method("take_damage"):
		return
	var interval := maxf(0.001, float(entry.get("tick_interval", DEFAULT_POISON_TICK_INTERVAL)))
	var timer := float(entry.get("tick_timer", interval)) - delta
	var damage := maxi(0, int(entry.get("damage", DEFAULT_POISON_DAMAGE)))
	while timer <= 0.000001 and damage > 0:
		target.call("take_damage", damage)
		effect_ticked.emit(EFFECT_POISON, {"damage": damage})
		timer += interval
	entry["tick_timer"] = timer


func _entry_speed_multiplier(entry: Dictionary, fallback: float) -> float:
	if entry.has("speed_multiplier"):
		return clampf(float(entry["speed_multiplier"]), 0.0, 4.0)
	if entry.has("potency"):
		return clampf(1.0 - float(entry["potency"]), 0.0, 4.0)
	return fallback
