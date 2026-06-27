extends Node
## MetaUpgradeCatalog 순수 로직 테스트.

const MetaUpgradeCatalog := preload("res://scripts/items/meta_upgrade_catalog.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_catalog_has_four_upgrades() -> void:
	_runner.assert_eq(MetaUpgradeCatalog.upgrade_ids().size(), 4, "4종 업그레이드")
	_runner.assert_true(MetaUpgradeCatalog.has_upgrade(&"dodge_charges"), "대시 업그레이드 존재")
	_runner.assert_false(MetaUpgradeCatalog.has_upgrade(&"unknown"), "없는 id는 false")


func test_cost_curve_escalates_4_7_10() -> void:
	_runner.assert_eq(MetaUpgradeCatalog.cost_to_next(&"max_health", 0), 4, "레벨0→1 = 4")
	_runner.assert_eq(MetaUpgradeCatalog.cost_to_next(&"max_health", 1), 7, "레벨1→2 = 7")
	_runner.assert_eq(MetaUpgradeCatalog.cost_to_next(&"max_health", 2), 10, "레벨2→3 = 10")
	_runner.assert_eq(MetaUpgradeCatalog.cost_to_next(&"max_health", 3), -1, "최대면 -1")


func test_is_maxed_at_three() -> void:
	_runner.assert_false(MetaUpgradeCatalog.is_maxed(&"bat_damage", 2), "레벨2는 최대 아님")
	_runner.assert_true(MetaUpgradeCatalog.is_maxed(&"bat_damage", 3), "레벨3은 최대")


func test_can_purchase_respects_balance_and_max() -> void:
	_runner.assert_true(MetaUpgradeCatalog.can_purchase(&"max_health", 0, 4), "딱 맞는 잔액 구매 가능")
	_runner.assert_false(MetaUpgradeCatalog.can_purchase(&"max_health", 0, 3), "잔액 부족 불가")
	_runner.assert_false(MetaUpgradeCatalog.can_purchase(&"max_health", 3, 999), "최대 레벨 불가")
	_runner.assert_false(MetaUpgradeCatalog.can_purchase(&"unknown", 0, 999), "없는 id 불가")


func test_compose_modifiers_maps_levels_to_keys() -> void:
	var mods := MetaUpgradeCatalog.compose_modifiers({
		&"max_health": 2,
		&"melee_damage": 1,
		&"dodge_charges": 3,
	})
	_runner.assert_eq(int(mods.get("max_health_add", 0)), 2, "체력 레벨2 → +2")
	_runner.assert_eq(int(mods.get("melee_damage_add", 0)), 1, "근접 레벨1 → +1")
	_runner.assert_eq(int(mods.get("special_skill_uses_add", 0)), 3, "대시 레벨3 → +3")
	_runner.assert_eq(int(mods.get("bat_damage_add", 0)), 0, "미구매는 0")
