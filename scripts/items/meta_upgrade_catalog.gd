extends RefCounted
## 영구 재화 메타 업그레이드 카탈로그 (순수 데이터 + 헬퍼).
##
## 설계: docs/plans/permanent-upgrades.md
## - 4종 × 3레벨, 비용 4/7/10 (에스컬레이팅: 다음 레벨로 가는 비용 = COSTS[현재레벨]).
## - 각 업그레이드는 기존 런 모디파이어 키에 매핑된다(효과 적용은 player 가 담당).
## - 이 스크립트는 상태/autoload 의존 없음(테스트 용이). 소비 인스턴스는 preload 로 쓴다:
##     const MetaUpgradeCatalog := preload("res://scripts/items/meta_upgrade_catalog.gd")

const MAX_LEVEL := 3
const COSTS := [4, 7, 10] ## COSTS[level] = level -> level+1 로 올리는 비용

const ORDER: Array[StringName] = [&"max_health", &"melee_damage", &"bat_damage", &"dodge_charges"]

const UPGRADES := {
	&"max_health": {
		"display": "체력",
		"effect": "최대 체력 +1",
		"modifier_key": "max_health_add",
		"per_level": 1,
	},
	&"melee_damage": {
		"display": "근접",
		"effect": "근접 피해 +1",
		"modifier_key": "melee_damage_add",
		"per_level": 1,
	},
	&"bat_damage": {
		"display": "배트",
		"effect": "배트 피해 +1",
		"modifier_key": "bat_damage_add",
		"per_level": 1,
	},
	&"dodge_charges": {
		"display": "대시",
		"effect": "회피(대시) 횟수 +1",
		"modifier_key": "special_skill_uses_add",
		"per_level": 1,
	},
}


static func upgrade_ids() -> Array[StringName]:
	return ORDER.duplicate()


static func has_upgrade(id: StringName) -> bool:
	return UPGRADES.has(id)


static func get_def(id: StringName) -> Dictionary:
	return (UPGRADES.get(id, {}) as Dictionary).duplicate(true)


static func display_name(id: StringName) -> String:
	return String((UPGRADES.get(id, {}) as Dictionary).get("display", String(id)))


static func effect_text(id: StringName) -> String:
	return String((UPGRADES.get(id, {}) as Dictionary).get("effect", ""))


static func max_level(_id: StringName) -> int:
	return MAX_LEVEL


static func clamp_level(level: int) -> int:
	return clampi(level, 0, MAX_LEVEL)


## level -> level+1 로 올리는 비용. 최대 레벨이면 -1.
static func cost_to_next(_id: StringName, current_level: int) -> int:
	if current_level >= MAX_LEVEL:
		return -1
	if current_level < 0:
		return COSTS[0]
	return int(COSTS[current_level])


static func is_maxed(_id: StringName, current_level: int) -> bool:
	return current_level >= MAX_LEVEL


static func can_purchase(id: StringName, current_level: int, balance: int) -> bool:
	if not has_upgrade(id):
		return false
	var cost := cost_to_next(id, current_level)
	return cost >= 0 and balance >= cost


## 레벨 dict({id: level}) -> 모디파이어 dict({modifier_key: amount}). (효과 적용 단계에서 사용)
static func compose_modifiers(levels: Dictionary) -> Dictionary:
	var mods := {}
	for id: StringName in ORDER:
		var lvl := clamp_level(int(levels.get(id, 0)))
		var def: Dictionary = UPGRADES[id]
		var key := String(def["modifier_key"])
		mods[key] = int(mods.get(key, 0)) + int(def["per_level"]) * lvl
	return mods
