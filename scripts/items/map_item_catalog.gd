extends RefCounted

const DEFAULT_ITEM_ID := &"gung_talisman"

const ITEMS := {
	&"gung_talisman": {
		"display_name": "궁 부적",
		"flavor": "붉은 궁 부적이 주먹과 배트에 힘을 싣는다.",
		"modifiers": {
			"melee_damage_add": 1,
			"bat_damage_add": 1,
		},
	},
	&"dokkaebi_fire": {
		"display_name": "도깨비불",
		"flavor": "푸른 불씨가 공격 박자를 앞당긴다.",
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
		"flavor": "달빛이 하트 한 칸을 임시로 감싼다.",
		"modifiers": {
			"max_health_add": 1,
		},
	},
}

const _BASE_MODIFIERS := {
	"melee_damage_add": 0,
	"bat_damage_add": 0,
	"max_health_add": 0,
	"special_skill_uses_add": 0,
	"move_speed_mult": 1.0,
	"attack_cooldown_mult": 1.0,
	"fire_cooldown_mult": 1.0,
}

const _EFFECT_ORDER := [
	"melee_damage_add",
	"bat_damage_add",
	"max_health_add",
	"special_skill_uses_add",
	"move_speed_mult",
	"attack_cooldown_mult",
	"fire_cooldown_mult",
]


static func item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for item_id: StringName in ITEMS.keys():
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
	stats["max_health"] = maxi(1, int(base_stats.get("max_health", 1)) + int(modifiers.get("max_health_add", 0)))
	stats["special_skill_max_uses"] = maxi(0, int(base_stats.get("special_skill_max_uses", 0)) + int(modifiers.get("special_skill_uses_add", 0)))
	return stats


## 두 모디파이어 dict 를 합친다(_add 는 합, _mult 는 곱). 메타 + 런 아이템 모디파이어 결합용.
static func merge_modifiers(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key: Variant in extra.keys():
		if String(key).ends_with("_mult"):
			result[key] = float(result.get(key, 1.0)) * float(extra[key])
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
		"special_skill_uses_add":
			return _signed_integer_effect("회피 횟수", int(value))
		"move_speed_mult":
			return _signed_multiplier_effect("이동 속도", float(value))
		"attack_cooldown_mult":
			return _signed_multiplier_effect("근접 공격 간격", float(value))
		"fire_cooldown_mult":
			return _signed_multiplier_effect("투척 간격", float(value))
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
