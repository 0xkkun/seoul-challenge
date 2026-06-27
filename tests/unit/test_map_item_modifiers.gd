extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_catalog_exposes_multiple_run_items() -> void:
	var catalog := _load_catalog()
	if catalog == null:
		return
	_runner.assert_true(catalog.call("has_item", &"gung_talisman"), "catalog includes damage talisman")
	var item_ids: Array[StringName] = catalog.call("item_ids")
	_runner.assert_true(item_ids.size() >= 3, "catalog exposes at least three map items")
	var item_def: Dictionary = catalog.call("get_item_def", &"gung_talisman")
	_runner.assert_eq(item_def.get("display_name", ""), "강타 부적", "damage item has readable attack name")
	_runner.assert_true(String(item_def.get("flavor", "")).contains("힘"), "damage item flavor explains hit power")
	_runner.assert_true((item_def.get("modifiers", {}) as Dictionary).has("melee_damage_add"), "item carries stat modifiers")


func test_compose_modifiers_stacks_damage_speed_and_health() -> void:
	var catalog := _load_catalog()
	if catalog == null:
		return
	var modifiers: Dictionary = catalog.call("compose_modifiers", [&"gung_talisman", &"wind_step", &"moon_guard"])

	_runner.assert_eq(modifiers["melee_damage_add"], 1, "damage item adds melee damage")
	_runner.assert_eq(modifiers["bat_damage_add"], 1, "damage item adds bat damage")
	_runner.assert_true(float(modifiers["move_speed_mult"]) > 1.0, "speed item multiplies move speed")
	_runner.assert_eq(modifiers["max_health_add"], 1, "health item adds max health")


func test_apply_modifiers_to_stats_changes_combat_numbers() -> void:
	var catalog := _load_catalog()
	if catalog == null:
		return
	var base_stats := {
		"move_speed": 200.0,
		"attack_cooldown": 0.35,
		"fire_cooldown": 0.22,
		"melee_damage": 1,
		"bat_damage": 2,
		"max_health": 5,
	}
	var modifiers: Dictionary = catalog.call("compose_modifiers", [&"gung_talisman", &"dokkaebi_fire", &"wind_step"])
	var stats: Dictionary = catalog.call("apply_modifiers_to_stats", base_stats, modifiers)

	_runner.assert_eq(stats["melee_damage"], 2, "damage modifier changes melee damage")
	_runner.assert_eq(stats["bat_damage"], 3, "damage modifier changes bat damage")
	_runner.assert_true(float(stats["move_speed"]) > float(base_stats["move_speed"]), "speed modifier changes movement")
	_runner.assert_true(float(stats["attack_cooldown"]) < float(base_stats["attack_cooldown"]), "tempo modifier speeds melee swings")
	_runner.assert_true(float(stats["fire_cooldown"]) < float(base_stats["fire_cooldown"]), "tempo modifier speeds ranged throws")


func test_effect_text_describes_visible_stat_changes() -> void:
	var catalog := _load_catalog()
	if catalog == null:
		return

	_runner.assert_eq(catalog.call("get_effect_text", &"gung_talisman"), "근접 피해 +1 / 배트 피해 +1", "damage reward explains both attack stats")
	_runner.assert_eq(catalog.call("get_effect_text", &"dokkaebi_fire"), "근접 공격 간격 -16% / 투척 간격 -16%", "tempo reward explains cooldown reduction")
	_runner.assert_eq(catalog.call("get_effect_text", &"wind_step"), "이동 속도 +15%", "speed reward explains movement stat")
	_runner.assert_eq(catalog.call("get_effect_text", &"moon_guard"), "최대 체력 +1", "health reward explains health stat")


func _load_catalog() -> GDScript:
	var path := "res://scripts/items/map_item_catalog.gd"
	_runner.assert_true(ResourceLoader.exists(path), "map item catalog script exists")
	if not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	_runner.assert_not_null(script, "map item catalog script exists")
	if script == null:
		return null
	for method_name: String in ["has_item", "item_ids", "get_item_def", "compose_modifiers", "apply_modifiers_to_stats", "get_effect_text"]:
		_runner.assert_true(script.has_method(method_name), "catalog exposes %s" % method_name)
		if not script.has_method(method_name):
			return null
	return script
