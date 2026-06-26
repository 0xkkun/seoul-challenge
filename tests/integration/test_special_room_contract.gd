extends Node

const MinimapDataScript = preload("res://scripts/systems/minimap_data.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	GameManager.reset_session()


func after_each() -> void:
	GameManager.reset_session()
	for child: Node in get_children():
		child.queue_free()


func test_start_room_clears_on_entry() -> void:
	var room := (load("res://scenes/interactables/start_room.tscn") as PackedScene).instantiate() as StartRoom
	add_child(room)

	var north_door := room.get_door(&"N")
	var floor := room.get_node("Floor") as ColorRect
	_runner.assert_not_null(north_door, "start room exposes an exit door")
	_runner.assert_eq(floor.color, RoomPalette.START_ROOM_FLOOR_COLOR, "start room uses start palette")
	_runner.assert_true(north_door.is_locked(), "start room door is locked before enter")

	room.enter()

	_runner.assert_true(room.has_been_cleared(), "start room clears automatically on entry")
	_runner.assert_true(north_door.is_open(), "start room opens exits after clear")


func test_boss_room_requests_spawn_and_finishes_active_session() -> void:
	_runner.assert_true(EventBus.has_signal("boss_defeated"), "EventBus exposes boss defeated event")
	if not EventBus.has_signal("boss_defeated"):
		return
	var room := (load("res://scenes/interactables/boss_room.tscn") as PackedScene).instantiate() as BossRoom
	var spawn_requests: Array[Dictionary] = []
	var spawn_events: Array[Dictionary] = []
	var purified_payloads: Array[Dictionary] = []
	var boss_defeated_payloads: Array[Dictionary] = []
	var finished_results: Array[Dictionary] = []
	var on_spawn_requested := func(room_id: StringName, boss_id: StringName, spawn_position: Vector2) -> void:
		spawn_requests.append({
			"room_id": room_id,
			"boss_id": boss_id,
			"spawn_position": spawn_position,
		})
	var on_interaction_completed := func(payload: Dictionary) -> void:
		if payload.get("kind", "") == "boss_spawn_requested":
			spawn_events.append(payload)
	var on_friend_purified := func(payload: Dictionary) -> void:
		purified_payloads.append(payload)
	var on_boss_defeated := func(payload: Dictionary) -> void:
		boss_defeated_payloads.append(payload)
	var on_session_finished := func(result: Dictionary) -> void:
		finished_results.append(result)

	room.boss_spawn_requested.connect(on_spawn_requested)
	EventBus.interaction_completed.connect(on_interaction_completed)
	EventBus.friend_purified.connect(on_friend_purified)
	EventBus.boss_defeated.connect(on_boss_defeated)
	EventBus.session_finished.connect(on_session_finished)
	GameManager.start_session({"source": "boss_room_test"})
	add_child(room)

	room.enter()

	_runner.assert_true(room.has_requested_spawn(), "boss room requests spawn on entry")
	_runner.assert_false(room.has_been_cleared(), "boss room stays uncleared until boss completion")
	_runner.assert_eq(spawn_requests.size(), 1, "boss room emits a local spawn signal")
	_runner.assert_eq(spawn_events.size(), 1, "boss room emits EventBus spawn trigger")
	if spawn_events.size() == 1:
		_runner.assert_eq(spawn_events[0]["room_id"], &"final_1", "spawn trigger includes room id")
		_runner.assert_eq(spawn_events[0]["boss_id"], &"gyeongbokgung_boss", "spawn trigger includes boss id")

	_runner.assert_true(room.complete_boss_encounter(), "boss completion resolves the shell")

	_runner.assert_true(room.has_been_cleared(), "boss completion clears the room")
	_runner.assert_eq(purified_payloads.size(), 0, "boss completion does not emit friend purified payload")
	_runner.assert_eq(boss_defeated_payloads.size(), 1, "boss completion emits boss defeated payload")
	if boss_defeated_payloads.size() == 1:
		_runner.assert_eq(boss_defeated_payloads[0]["room_id"], &"final_1", "boss defeated includes room id")
		_runner.assert_eq(boss_defeated_payloads[0]["boss_id"], &"gyeongbokgung_boss", "boss defeated includes boss id")
	_runner.assert_eq(finished_results.size(), 1, "active session is finished by boss completion")
	_runner.assert_false(GameManager.is_session_active(), "boss completion ends the active session")
	if finished_results.size() == 1:
		_runner.assert_eq(finished_results[0]["reason"], "boss_resolved", "session result records boss completion")

	room.boss_spawn_requested.disconnect(on_spawn_requested)
	EventBus.interaction_completed.disconnect(on_interaction_completed)
	EventBus.friend_purified.disconnect(on_friend_purified)
	EventBus.boss_defeated.disconnect(on_boss_defeated)
	EventBus.session_finished.disconnect(on_session_finished)


func test_treasure_room_pickup_marks_room_cleared() -> void:
	var room := (load("res://scenes/interactables/treasure_room.tscn") as PackedScene).instantiate() as TreasureRoom
	var actor := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node2D
	var room_container := Node2D.new()
	var interaction_system: Node = (load("res://scripts/systems/interaction_system.gd") as GDScript).new()
	var pickup_events: Array[Dictionary] = []
	var on_interaction_completed := func(payload: Dictionary) -> void:
		if payload.get("kind", "") == "treasure_picked_up":
			pickup_events.append(payload)

	EventBus.interaction_completed.connect(on_interaction_completed)
	add_child(room_container)
	room_container.add_child(room)
	add_child(actor)
	add_child(interaction_system)
	interaction_system.configure(actor, room_container)
	room.enter()

	var north_door := room.get_door(&"N")
	var pickup_visual := room.get_node("PickupSpot/PickupVisual") as ColorRect
	_runner.assert_false(room.has_picked_up(), "treasure starts available")
	_runner.assert_true(north_door.is_locked(), "treasure room door stays locked before pickup")
	_runner.assert_eq(pickup_visual.color, RoomPalette.REWARD_ROOM_FLOOR_COLOR, "pickup visual uses palette color")
	_runner.assert_eq(actor.get("melee_damage"), 1, "player starts at base melee damage")

	var dispatched: int = interaction_system.check_now()

	_runner.assert_eq(dispatched, 1, "interaction system dispatches to treasure pickup")
	_runner.assert_true(room.has_picked_up(), "treasure pickup records state")
	_runner.assert_true(room.has_been_cleared(), "treasure pickup clears room")
	_runner.assert_true(north_door.is_open(), "treasure pickup opens exits")
	_runner.assert_false(pickup_visual.visible, "pickup visual hides after pickup")
	_runner.assert_eq(actor.get("melee_damage"), 2, "treasure pickup applies the run item immediately")
	_runner.assert_eq(pickup_events.size(), 1, "treasure pickup emits EventBus payload")
	if pickup_events.size() == 1:
		_runner.assert_eq(pickup_events[0]["item_id"], &"gung_talisman", "pickup payload includes item id")
		_runner.assert_eq(pickup_events[0]["item_display_name"], "궁 부적", "pickup payload includes flavor name")
		_runner.assert_true(pickup_events[0]["applied"], "pickup payload records player stat application")

	EventBus.interaction_completed.disconnect(on_interaction_completed)


func test_minimap_data_marks_current_visible_and_boss_hidden() -> void:
	var layout := load("res://resources/layouts/gyeongbokgung.tres") as RoomLayout
	var data: Dictionary = MinimapDataScript.build_from_layout(layout, &"combat_1", {})
	var current_room := _find_room(data["rooms"], &"combat_1")
	var boss_room := _find_room(data["rooms"], &"final_1")

	_runner.assert_eq(data["layout_id"], &"gyeongbokgung", "minimap data keeps layout id")
	_runner.assert_true(current_room["current"], "current room is marked")
	_runner.assert_true(current_room["visible"], "current room is visible")
	_runner.assert_eq(boss_room["minimap_type"], &"boss", "final room is exposed as boss type")
	_runner.assert_true(boss_room["hidden"], "boss room keeps hidden flag")
	_runner.assert_false(boss_room["visible"], "boss room starts hidden on minimap")

	var cleared := {
		&"start": true,
		&"combat_1": true,
		&"treasure_1": true,
		&"combat_2": true,
		&"event_1": true,
	}
	var revealed_data: Dictionary = MinimapDataScript.build_from_layout(layout, &"event_1", cleared)
	var revealed_boss := _find_room(revealed_data["rooms"], &"final_1")
	var friend_room := _find_room(revealed_data["rooms"], &"friend_1")
	_runner.assert_false(friend_room.is_empty(), "minimap data includes friend room")
	if friend_room.is_empty():
		return
	_runner.assert_eq(friend_room["minimap_type"], &"friend", "friend room is exposed as friend type")
	_runner.assert_false(revealed_boss["visible"], "boss stays hidden until friend room clears")

	cleared[&"friend_1"] = true
	revealed_data = MinimapDataScript.build_from_layout(layout, &"friend_1", cleared)
	revealed_boss = _find_room(revealed_data["rooms"], &"final_1")
	_runner.assert_true(revealed_boss["visible"], "layout reveal rules can expose boss room data later")


func test_minimap_data_keeps_treasure_and_shop_visible() -> void:
	var layout := RoomLayout.new()
	var defs: Array[RoomDef] = [
		_make_room_def(&"start", &"start"),
		_make_room_def(&"treasure_1", &"treasure"),
		_make_room_def(&"shop_1", &"shop"),
	]
	layout.layout_id = &"minimap_test"
	layout.start_room_id = &"start"
	layout.room_defs = defs

	var data: Dictionary = MinimapDataScript.build_from_layout(layout, &"start", {})
	var treasure_room := _find_room(data["rooms"], &"treasure_1")
	var shop_room := _find_room(data["rooms"], &"shop_1")

	_runner.assert_true(treasure_room["visible"], "treasure room is visible for HUD rendering")
	_runner.assert_eq(treasure_room["minimap_type"], &"treasure", "treasure minimap type is preserved")
	_runner.assert_true(shop_room["visible"], "shop room is visible for HUD rendering")
	_runner.assert_eq(shop_room["minimap_type"], &"shop", "shop minimap type is preserved")


func _find_room(rooms: Array, room_id: StringName) -> Dictionary:
	for room: Dictionary in rooms:
		if room.get("room_id", &"") == room_id:
			return room
	return {}


func _make_room_def(room_id: StringName, room_type: StringName) -> RoomDef:
	var room_def := RoomDef.new()
	room_def.room_id = room_id
	room_def.room_type = room_type
	room_def.scene_path = "res://scenes/session/room_base.tscn"
	return room_def
