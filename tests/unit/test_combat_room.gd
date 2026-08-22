extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func test_combat_room_spawns_enemies_and_clears_after_defeats() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	var cleared_rooms: Array[StringName] = []
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)
	room.cleared.connect(on_cleared)
	add_child(room)

	room.enter()

	var east_door := room.call("get_door", &"E") as RoomDoor
	_runner.assert_not_null(east_door, "combat room has an east exit")
	if east_door == null:
		return
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 4, "combat room starts with four enemies")
	_runner.assert_false(room.call("is_cleared"), "combat room waits for enemy defeats")
	_runner.assert_true(east_door.is_locked(), "combat room door stays locked while enemies remain")

	_defeat_active_enemies(room)

	_runner.assert_true(room.call("is_cleared"), "combat room clears after every enemy is defeated")
	_runner.assert_true(east_door.is_open(), "combat clear opens exits")
	_runner.assert_eq(cleared_rooms, [room.get("room_id")], "combat room emits cleared once")


func test_combat_room_emits_spawn_after_each_enemy_is_tracked() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	room.call("apply_room_config", {
		"chaser_count": 0,
		"ranged_count": 0,
		"wolf_count": 1,
		"elite_chaser_count": 0,
		"elite_ranged_count": 0,
		"elite_wolf_count": 0,
		"wave_count": 1,
	})
	var payloads: Array[Dictionary] = []
	if room.has_signal("enemy_spawned"):
		room.connect(&"enemy_spawned", func(enemy: Node, enemy_type: StringName, wave_index: int) -> void:
			payloads.append({
				"enemy": enemy,
				"enemy_type": enemy_type,
				"wave_index": wave_index,
				"inside_tree": enemy.is_inside_tree(),
				"tracked": (room.call("get_active_enemies") as Array).has(enemy),
			})
		)
	add_child(room)
	room.enter()

	_runner.assert_eq(payloads.size(), 1, "initial encounter emits one event per real spawn")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0].get("enemy_type"), &"wolf", "spawn event identifies the wolf contract")
		_runner.assert_eq(payloads[0].get("wave_index"), 0, "initial encounter is wave zero")
		_runner.assert_true(bool(payloads[0].get("inside_tree")), "spawn event runs after the enemy enters the tree")
		_runner.assert_true(bool(payloads[0].get("tracked")), "spawn event runs after the room tracks the enemy")

	room.call("_spawn_enemy_entry", {"enemy_type": &"wolf", "elite_variant": false, "sequence": 1})
	_runner.assert_eq(payloads.size(), 2, "a later real spawn uses the same event contract")
	if payloads.size() == 2:
		_runner.assert_eq(payloads[1].get("wave_index"), 1, "later wave spawn reports the next wave index")


func test_combat_room_spawns_and_bounds_enemies_inside_play_area() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	add_child(room)

	room.enter()

	var expected_bounds := Rect2(room.global_position + RoomPalette.get_room_bounds().position, RoomPalette.get_room_bounds().size)
	for enemy: Node in room.call("get_active_enemies"):
		var enemy_node := enemy as Node2D
		_runner.assert_not_null(enemy_node, "combat enemy is a Node2D")
		_runner.assert_true(enemy.has_method("get_movement_bounds"), "combat enemies expose player-style movement bounds")
		_runner.assert_true(enemy.has_method("has_movement_bounds"), "combat enemies expose movement bounds state")
		_runner.assert_true(enemy.has_method("is_spawn_protected"), "combat enemies expose spawn protection state")
		if enemy_node == null or not enemy.has_method("get_movement_bounds") or not enemy.has_method("has_movement_bounds"):
			continue
		_runner.assert_true(enemy.call("has_movement_bounds"), "combat enemy movement bounds are enabled")
		_runner.assert_eq(enemy.call("get_movement_bounds"), expected_bounds, "combat enemy movement bounds match the current room play area")
		_runner.assert_true(expected_bounds.has_point(enemy_node.global_position), "combat enemy starts inside the current room play area")
		if enemy.has_method("is_spawn_protected"):
			_runner.assert_true(enemy.call("is_spawn_protected"), "combat enemy starts in fade-in protection")


func test_combat_room_with_no_spawn_budget_clears_on_enter() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	room.chaser_count = 0
	room.ranged_count = 0
	add_child(room)

	room.enter()

	_runner.assert_true(room.call("is_cleared"), "empty combat room resolves immediately")
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 0, "empty combat room has no active enemies")


func test_combat_room_applies_room_config_and_elite_variants() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	_runner.assert_true(room.has_method("apply_room_config"), "combat room accepts room config")
	_runner.assert_true(room.has_method("get_encounter_summary"), "combat room exposes encounter summary")
	if not room.has_method("apply_room_config") or not room.has_method("get_encounter_summary"):
		return

	room.call("apply_room_config", {
		"chaser_count": 1,
		"ranged_count": 1,
		"elite_chaser_count": 1,
		"elite_ranged_count": 1,
		"wave_count": 1,
	})
	add_child(room)

	room.enter()

	var summary: Dictionary = room.call("get_encounter_summary")
	_runner.assert_eq(summary["chaser_count"], 1, "config keeps normal chaser count")
	_runner.assert_eq(summary["ranged_count"], 1, "config keeps normal ranged count")
	_runner.assert_eq(summary["elite_chaser_count"], 1, "config keeps elite chaser count")
	_runner.assert_eq(summary["elite_ranged_count"], 1, "config keeps elite ranged count")
	_runner.assert_eq(summary["wave_count"], 1, "summary includes configured wave count")
	_runner.assert_eq(summary["total_count"], 4, "summary includes all configured enemies")
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 4, "room spawns every configured enemy")

	var elite_count := 0
	var elite_chaser_hp := 0
	var normal_chaser_hp := 0
	for enemy: Node in room.call("get_active_enemies"):
		if String(enemy.name).begins_with("Akgwi"):
			normal_chaser_hp = int(enemy.get("max_hp"))
		if String(enemy.name).begins_with("EliteAkgwi"):
			elite_chaser_hp = int(enemy.get("max_hp"))
		if enemy.get_meta("encounter_variant", &"normal") == &"elite":
			elite_count += 1
			_runner.assert_true(enemy.is_in_group(&"elite_enemy"), "elite enemies join elite group")

	_runner.assert_eq(elite_count, 2, "elite chaser and elite ranged are marked")
	_runner.assert_true(elite_chaser_hp > normal_chaser_hp, "elite chaser has more hp than normal chaser")


func test_combat_room_does_not_emit_ingame_rewards_for_enemy_defeats_and_clear() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	var ingame_payloads: Array[Dictionary] = []
	var on_currency_changed := func(payload: Dictionary) -> void:
		if payload.get("kind", "") == "ingame":
			ingame_payloads.append(payload)
	EventBus.currency_changed.connect(on_currency_changed)
	add_child(room)

	room.enter()
	_defeat_active_enemies(room)

	_runner.assert_true(room.call("is_cleared"), "combat room clears after reward source defeats")
	_runner.assert_eq(ingame_payloads.size(), 0, "combat no longer emits unused yeopjeon rewards")
	EventBus.currency_changed.disconnect(on_currency_changed)


func test_combat_room_spawns_full_encounter_on_enter_even_when_wave_count_configured() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	room.call("apply_room_config", {
		"chaser_count": 4,
		"ranged_count": 2,
		"elite_chaser_count": 0,
		"elite_ranged_count": 0,
		"wave_count": 2,
	})
	add_child(room)

	room.enter()

	var summary: Dictionary = room.call("get_encounter_summary")
	_runner.assert_eq(summary["total_count"], 6, "wave encounter budget includes all enemies")
	_runner.assert_eq(summary["wave_count"], 2, "wave encounter keeps authored wave count")
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 6, "combat room spawns the full encounter on enter")

	_defeat_active_enemies(room)

	_runner.assert_true(room.call("is_cleared"), "combat clears after every initially spawned enemy is defeated")
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 0, "final wave leaves no active enemies")
	_runner.assert_false(CurrencySystem.has_method("get_ingame"), "combat cannot accrue removed ingame yeopjeon balance")


func test_combat_room_ignores_duplicate_defeat_reward_for_same_enemy() -> void:
	var room := _instantiate_combat_room()
	if room == null:
		return
	room.chaser_count = 1
	room.ranged_count = 0
	add_child(room)

	room.enter()
	var enemies: Array = room.call("get_active_enemies")
	_runner.assert_eq(enemies.size(), 1, "test room starts with one tracked enemy")
	if enemies.is_empty():
		return
	var enemy := enemies[0] as Node
	_runner.assert_not_null(enemy, "test enemy exists")
	if enemy == null:
		return

	enemy.emit_signal("defeated", enemy)
	enemy.emit_signal("defeated", enemy)

	_runner.assert_true(room.call("is_cleared"), "first defeat clears the one-enemy combat")
	_runner.assert_false(CurrencySystem.has_method("get_ingame"), "duplicate defeat cannot pay removed ingame yeopjeon rewards")


func _instantiate_combat_room() -> Node:
	_runner.assert_true(ResourceLoader.exists("res://scenes/interactables/combat_room.tscn"), "combat room scene exists")
	if not ResourceLoader.exists("res://scenes/interactables/combat_room.tscn"):
		return null
	var packed := load("res://scenes/interactables/combat_room.tscn") as PackedScene
	_runner.assert_not_null(packed, "combat room scene loads")
	if packed == null:
		return null
	var room := packed.instantiate()
	_runner.assert_true(room.has_method("get_active_enemies"), "combat room exposes active enemies")
	_runner.assert_true(room.has_method("get_remaining_enemy_count"), "combat room exposes remaining enemy count")
	_runner.assert_true(room.has_method("get_alive_count"), "combat room keeps legacy alive count alias")
	return room


func _defeat_active_enemies(room: Node) -> void:
	for enemy: Node in room.call("get_active_enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 99)
