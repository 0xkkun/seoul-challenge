extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_friend_room_spawns_friend_and_clears_after_purify() -> void:
	_runner.assert_true(ResourceLoader.exists("res://scenes/interactables/friend_room.tscn"), "friend room scene exists")
	if not ResourceLoader.exists("res://scenes/interactables/friend_room.tscn"):
		return
	var room := (load("res://scenes/interactables/friend_room.tscn") as PackedScene).instantiate()
	var purified_payloads: Array[Dictionary] = []
	var on_friend_purified := func(payload: Dictionary) -> void:
		purified_payloads.append(payload)
	EventBus.friend_purified.connect(on_friend_purified)
	add_child(room)

	room.enter()

	_runner.assert_eq(room.get("friend_id"), &"baseball_captain", "MVP friend room purifies the baseball captain")
	_runner.assert_false(room.call("is_cleared"), "friend room waits for purification")
	_runner.assert_eq(room.call("get_remaining_friend_count"), 1, "friend room spawns one yokai friend")
	var friends: Array = room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "friend room exposes active friend")
	if friends.size() == 1:
		var friend := friends[0] as Node
		_runner.assert_true(friend.has_signal("purified"), "spawned friend keeps purified contract")
		friend.emit_signal("purified", friend)

	_runner.assert_true(room.call("is_cleared"), "purifying the friend clears the room")
	_runner.assert_true(room.call("has_been_cleared"), "purifying marks the room cleared")
	_runner.assert_eq(purified_payloads.size(), 1, "friend purification emits EventBus payload")
	if purified_payloads.size() == 1:
		_runner.assert_eq(purified_payloads[0]["room_id"], room.get("room_id"), "payload includes room id")
		_runner.assert_eq(purified_payloads[0]["room_type"], &"friend", "payload identifies friend room")
		_runner.assert_eq(purified_payloads[0]["friend_id"], &"baseball_captain", "payload unlocks the baseball club loop")

	EventBus.friend_purified.disconnect(on_friend_purified)
