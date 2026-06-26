extends Node
## 전투 방 — 입장 시 적 스폰, 전부 처치되면 클리어(문 열림) 검증.

const CombatRoomScene := preload("res://scenes/interactables/combat_room.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_spawns_enemies_and_clears_when_all_defeated() -> void:
	var room = CombatRoomScene.instantiate()
	room.chaser_count = 2
	room.ranged_count = 1
	add_child(room)
	room.enter()

	_runner.assert_eq(room.get_alive_count(), 3, "입장 시 잡몹 3마리 스폰")
	_runner.assert_false(room.is_cleared(), "적이 남아 있으면 미클리어(문 잠김)")

	for enemy: Node in room.get_node("Enemies").get_children():
		enemy.take_damage(999)

	_runner.assert_eq(room.get_alive_count(), 0, "전부 처치됨")
	_runner.assert_true(room.is_cleared(), "전부 처치되면 방 클리어")
	room.free()


func test_empty_combat_room_clears_on_entry() -> void:
	var room = CombatRoomScene.instantiate()
	room.chaser_count = 0
	room.ranged_count = 0
	add_child(room)
	room.enter()

	_runner.assert_eq(room.get_alive_count(), 0, "적 0이면 스폰 없음")
	_runner.assert_true(room.is_cleared(), "적 0인 방은 입장 즉시 클리어")
	room.free()
