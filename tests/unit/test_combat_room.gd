extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


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
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 3, "combat room spawns chasers and a ranged shooter")
	_runner.assert_false(room.call("is_cleared"), "combat room waits for enemy defeats")
	_runner.assert_true(east_door.is_locked(), "combat room door stays locked while enemies remain")

	for enemy: Node in room.call("get_active_enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 99)

	_runner.assert_true(room.call("is_cleared"), "combat room clears after every enemy is defeated")
	_runner.assert_true(east_door.is_open(), "combat clear opens exits")
	_runner.assert_eq(cleared_rooms, [room.get("room_id")], "combat room emits cleared once")


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
	})
	add_child(room)

	room.enter()

	var summary: Dictionary = room.call("get_encounter_summary")
	_runner.assert_eq(summary["chaser_count"], 1, "config keeps normal chaser count")
	_runner.assert_eq(summary["ranged_count"], 1, "config keeps normal ranged count")
	_runner.assert_eq(summary["elite_chaser_count"], 1, "config keeps elite chaser count")
	_runner.assert_eq(summary["elite_ranged_count"], 1, "config keeps elite ranged count")
	_runner.assert_eq(summary["total_count"], 4, "summary includes all configured enemies")
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 4, "room spawns every configured enemy")

	var elite_count := 0
	var elite_chaser_hp := 0
	var normal_chaser_hp := 0
	for enemy: Node in room.call("get_active_enemies"):
		if String(enemy.name).begins_with("Chaser"):
			normal_chaser_hp = int(enemy.get("max_hp"))
		if String(enemy.name).begins_with("EliteChaser"):
			elite_chaser_hp = int(enemy.get("max_hp"))
		if enemy.get_meta("encounter_variant", &"normal") == &"elite":
			elite_count += 1
			_runner.assert_true(enemy.is_in_group(&"elite_enemy"), "elite enemies join elite group")

	_runner.assert_eq(elite_count, 2, "elite chaser and elite ranged are marked")
	_runner.assert_true(elite_chaser_hp > normal_chaser_hp, "elite chaser has more hp than normal chaser")


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
