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

	var north_door := room.call("get_door", &"N") as RoomDoor
	_runner.assert_eq(room.call("get_remaining_enemy_count"), 3, "combat room spawns chasers and a ranged shooter")
	_runner.assert_false(room.call("is_cleared"), "combat room waits for enemy defeats")
	_runner.assert_true(north_door.is_locked(), "combat room door stays locked while enemies remain")

	for enemy: Node in room.call("get_active_enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 99)

	_runner.assert_true(room.call("is_cleared"), "combat room clears after every enemy is defeated")
	_runner.assert_true(north_door.is_open(), "combat clear opens exits")
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
	return room
