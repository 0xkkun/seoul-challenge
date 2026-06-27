extends RefCounted

const DEFAULT_ITEM_ID := &"gung_talisman"
const ROOM_CLEAR_REWARD_ITEM_IDS := [
	&"dokkaebi_fire",
	&"wind_step",
	&"moon_guard",
	&"nurse_bandage",
	&"shadow_knot",
	&"full_swing_stance",
	&"breathing_room",
]

const ITEMS := {
	&"gung_talisman": {
		"display_name": "강타 부적",
		"flavor": "주먹과 배트에 힘이 실린다.",
		"modifiers": {
			"melee_damage_add": 1,
			"bat_damage_add": 1,
		},
	},
	&"dokkaebi_fire": {
		"display_name": "도깨비불",
		"flavor": "푸른 불씨가 공격 타이밍을 앞당긴다.",
		"modifiers": {
			"attack_cooldown_mult": 0.84,
			"fire_cooldown_mult": 0.84,
		},
	},
	&"wind_step": {
		"display_name": "바람 매듭",
		"flavor": "매듭이 풀리며 발끝이 가벼워진다.",
		"modifiers": {
			"move_speed_mult": 1.15,
		},
	},
	&"moon_guard": {
		"display_name": "달빛 호신부",
		"flavor": "달빛이 체력 한 칸을 잠시 감싼다.",
		"modifiers": {
			"max_health_add": 1,
		},
	},
	&"nurse_bandage": {
		"display_name": "보건실 반창고",
		"flavor": "보건실에서 챙긴 반창고가 상처를 빠르게 덮는다.",
		"modifiers": {
			"health_restore_add": 2,
		},
	},
	&"shadow_knot": {
		"display_name": "그림자 매듭",
		"flavor": "그림자가 몸을 감싸 회피 끝자락을 조금 더 버티게 한다.",
		"modifiers": {
			"dodge_invuln_time_add": 0.25,
		},
	},
	&"full_swing_stance": {
		"display_name": "풀스윙 자세",
		"flavor": "크게 휘두르는 대신 다음 스윙까지 숨이 더 찬다.",
		"modifiers": {
			"bat_knockback_mult": 1.4,
			"attack_cooldown_mult": 1.0 / 0.9,
		},
	},
	&"breathing_room": {
		"display_name": "숨 고르기",
		"flavor": "방을 정리할 때마다 짧게 숨을 돌려 상처를 가라앉힌다.",
		"modifiers": {
			"room_clear_health_restore_add": 1,
		},
	},
}

const _BASE_MODIFIERS := {
	"melee_damage_add": 0,
	"bat_damage_add": 0,
	"max_health_add": 0,
	"health_restore_add": 0,
	"room_clear_health_restore_add": 0,
	"dodge_invuln_time_add": 0.0,
	"special_skill_uses_add": 0,
	"move_speed_mult": 1.0,
	"bat_knockback_mult": 1.0,
	"attack_cooldown_mult": 1.0,
	"fire_cooldown_mult": 1.0,
}

const _EFFECT_ORDER := [
	"melee_damage_add",
	"bat_damage_add",
	"max_health_add",
	"health_restore_add",
	"room_clear_health_restore_add",
	"dodge_invuln_time_add",
	"special_skill_uses_add",
	"move_speed_mult",
	"bat_knockback_mult",
	"attack_cooldown_mult",
	"fire_cooldown_mult",
]


static func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item_id: StringName in ITEMS.keys():
		ids.append(item_id)
	return ids


static func reward_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item_id: StringName in ROOM_CLEAR_REWARD_ITEM_IDS:
		if has_item(item_id):
			ids.append(item_id)
	return ids


static func has_item(item_id: StringName) -> bool:
	return ITEMS.has(item_id)


static func get_item_def(item_id: StringName) -> Dictionary:
	if not has_item(item_id):
		return {}
	return (ITEMS[item_id] as Dictionary).duplicate(true)


static func get_display_name(item_id: StringName) -> String:
	return String(get_item_def(item_id).get("display_name", String(item_id)))


static func get_flavor(item_id: StringName) -> String:
	return String(get_item_def(item_id).get("flavor", ""))


static func get_effect_text(item_id: StringName) -> String:
	var modifiers: Dictionary = get_item_def(item_id).get("modifiers", {})
	return effect_text_from_modifiers(modifiers)


static func effect_text_from_modifiers(modifiers: Dictionary) -> String:
	var parts: Array[String] = []
	for modifier_key: String in _EFFECT_ORDER:
		if not modifiers.has(modifier_key):
			continue
		var text := _modifier_effect_text(modifier_key, modifiers[modifier_key])
		if text != "":
			parts.append(text)
	return " / ".join(parts)


static func resolve_item_id(configured_item_id: StringName, room_id: StringName = &"") -> StringName:
	if has_item(configured_item_id):
		return configured_item_id
	var ids := item_ids()
	if ids.is_empty():
		return &""
	if room_id == &"":
		return DEFAULT_ITEM_ID
	var index := absi(String(room_id).hash()) % ids.size()
	return ids[index]


static func compose_modifiers(item_ids_to_apply: Array) -> Dictionary:
	var result := _BASE_MODIFIERS.duplicate(true)
	for item_id: Variant in item_ids_to_apply:
		var key := item_id as StringName
		if not has_item(key):
			continue
		var modifiers: Dictionary = ITEMS[key].get("modifiers", {})
		for modifier_key: String in modifiers.keys():
			if modifier_key.ends_with("_mult"):
				result[modifier_key] = float(result.get(modifier_key, 1.0)) * float(modifiers[modifier_key])
			elif _should_compose_as_float(result.get(modifier_key, 0), modifiers[modifier_key]):
				result[modifier_key] = float(result.get(modifier_key, 0.0)) + float(modifiers[modifier_key])
			else:
				result[modifier_key] = int(result.get(modifier_key, 0)) + int(modifiers[modifier_key])
	return result


static func apply_modifiers_to_stats(base_stats: Dictionary, modifiers: Dictionary) -> Dictionary:
	var stats := base_stats.duplicate(true)
	stats["move_speed"] = maxf(1.0, float(base_stats.get("move_speed", 0.0)) * float(modifiers.get("move_speed_mult", 1.0)))
	stats["attack_cooldown"] = maxf(0.05, float(base_stats.get("attack_cooldown", 0.0)) * float(modifiers.get("attack_cooldown_mult", 1.0)))
	stats["fire_cooldown"] = maxf(0.05, float(base_stats.get("fire_cooldown", 0.0)) * float(modifiers.get("fire_cooldown_mult", 1.0)))
	stats["melee_damage"] = maxi(0, int(base_stats.get("melee_damage", 0)) + int(modifiers.get("melee_damage_add", 0)))
	stats["bat_damage"] = maxi(0, int(base_stats.get("bat_damage", 0)) + int(modifiers.get("bat_damage_add", 0)))
	stats["bat_knockback"] = maxf(0.0, float(base_stats.get("bat_knockback", 0.0)) * float(modifiers.get("bat_knockback_mult", 1.0)))
	stats["dodge_invuln_time"] = maxf(0.0, float(base_stats.get("dodge_invuln_time", 0.0)) + float(modifiers.get("dodge_invuln_time_add", 0.0)))
	stats["max_health"] = maxi(1, int(base_stats.get("max_health", 1)) + int(modifiers.get("max_health_add", 0)))
	stats["special_skill_max_uses"] = maxi(0, int(base_stats.get("special_skill_max_uses", 0)) + int(modifiers.get("special_skill_uses_add", 0)))
	return stats


## 두 모디파이어 dict 를 합친다(_add 는 합, _mult 는 곱). 메타 + 런 아이템 모디파이어 결합용.
static func merge_modifiers(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key: Variant in extra.keys():
		if String(key).ends_with("_mult"):
			result[key] = float(result.get(key, 1.0)) * float(extra[key])
		elif _should_compose_as_float(result.get(key, 0), extra[key]):
			result[key] = float(result.get(key, 0.0)) + float(extra[key])
		else:
			result[key] = int(result.get(key, 0)) + int(extra[key])
	return result


static func _modifier_effect_text(modifier_key: String, value: Variant) -> String:
	match modifier_key:
		"melee_damage_add":
			return _signed_integer_effect("근접 피해", int(value))
		"bat_damage_add":
			return _signed_integer_effect("배트 피해", int(value))
		"max_health_add":
			return _signed_integer_effect("최대 체력", int(value))
		"health_restore_add":
			return _signed_integer_effect("체력 회복", int(value))
		"room_clear_health_restore_add":
			return _room_clear_health_effect(int(value))
		"dodge_invuln_time_add":
			return _signed_seconds_effect("회피 무적", float(value))
		"special_skill_uses_add":
			return _signed_integer_effect("회피 횟수", int(value))
		"move_speed_mult":
			return _signed_multiplier_effect("이동 속도", float(value))
		"bat_knockback_mult":
			return _signed_multiplier_effect("배트 넉백", float(value))
		"attack_cooldown_mult":
			return _cooldown_multiplier_as_speed_effect("근접 공격 속도", float(value))
		"fire_cooldown_mult":
			return _cooldown_multiplier_as_speed_effect("투척 속도", float(value))
	return ""


static func _signed_integer_effect(label: String, amount: int) -> String:
	if amount == 0:
		return ""
	if amount > 0:
		return "%s +%d" % [label, amount]
	return "%s %d" % [label, amount]


static func _signed_multiplier_effect(label: String, multiplier: float) -> String:
	var percent := roundi((multiplier - 1.0) * 100.0)
	if percent == 0:
		return ""
	var sign := "+" if percent > 0 else "-"
	return "%s %s%d%%" % [label, sign, absi(percent)]


static func _signed_seconds_effect(label: String, amount: float) -> String:
	if is_zero_approx(amount):
		return ""
	var sign := "+" if amount > 0.0 else "-"
	return "%s %s%s초" % [label, sign, _format_seconds(absf(amount))]


static func _room_clear_health_effect(amount: int) -> String:
	if amount == 0:
		return ""
	if amount > 0:
		return "방 클리어 시 체력 +%d" % amount
	return "방 클리어 시 체력 %d" % amount


static func _cooldown_multiplier_as_speed_effect(label: String, multiplier: float) -> String:
	if multiplier <= 0.0:
		return ""
	var percent := roundi(((1.0 / multiplier) - 1.0) * 100.0)
	if percent == 0:
		return ""
	var sign := "+" if percent > 0 else "-"
	return "%s %s%d%%" % [label, sign, absi(percent)]


static func _format_seconds(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


static func _should_compose_as_float(current_value: Variant, next_value: Variant) -> bool:
	return typeof(current_value) == TYPE_FLOAT or typeof(next_value) == TYPE_FLOAT
