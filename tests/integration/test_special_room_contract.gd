extends Node

const MinimapDataScript = preload("res://scripts/systems/minimap_data.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
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
		_runner.assert_eq(pickup_events[0]["item_display_name"], "강타 부적", "pickup payload includes readable attack name")
		_runner.assert_true(pickup_events[0]["applied"], "pickup payload records player stat application")

	EventBus.interaction_completed.disconnect(on_interaction_completed)


func test_treasure_room_auto_picks_up_on_enter_to_avoid_softlock() -> void:
	var room := (load("res://scenes/interactables/treasure_room.tscn") as PackedScene).instantiate() as TreasureRoom
	var actor := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node2D
	add_child(room)
	add_child(actor)
	room.configure_actor(actor)

	room.enter()

	var north_door := room.get_door(&"N")
	_runner.assert_true(room.has_picked_up(), "treasure room grants its item immediately on entry")
	_runner.assert_true(room.has_been_cleared(), "treasure room auto clear prevents locked-room softlock")
	_runner.assert_true(north_door.is_open(), "treasure room opens exits without requiring hidden interaction input")
	_runner.assert_eq(actor.get("melee_damage"), 2, "auto pickup applies the run item to the player")


func test_shop_room_bat_purchase_spends_ingame_and_equips_player() -> void:
	var room := _instantiate_shop_room()
	if room == null:
		return
	var player := _instantiate_player()
	if player == null:
		return
	add_child(room)
	add_child(player)
	room.enter()
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 6})

	_runner.assert_true(room.call("purchase_offer", &"bat", player), "bat offer can be purchased with enough ingame currency")

	_runner.assert_eq(CurrencySystem.get_ingame(), 2, "bat purchase spends its ingame cost")
	_runner.assert_eq(player.call("current_weapon_name"), "야구배트", "bat purchase equips the stronger melee item")
	_runner.assert_true(room.call("is_offer_sold", &"bat"), "bat offer is marked sold")
	_runner.assert_true(String(room.call("get_offer_text", &"bat")).contains("구매 완료"), "shop label shows sold state")


func test_shop_room_dodge_refill_purchase_spends_ingame_and_upgrades_special() -> void:
	var room := _instantiate_shop_room()
	if room == null:
		return
	var player := _instantiate_player()
	if player == null:
		return
	add_child(room)
	add_child(player)
	room.enter()
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 5})

	_runner.assert_true(room.call("purchase_offer", &"dodge_refill", player), "dodge refill can be purchased with enough ingame currency")

	_runner.assert_eq(CurrencySystem.get_ingame(), 2, "dodge refill spends its ingame cost")
	_runner.assert_eq(player.get("special_skill_id"), &"emergency_dodge", "purchase keeps emergency dodge equipped")
	_runner.assert_eq(player.get("special_skill_max_uses"), 5, "purchase raises dodge charges")
	_runner.assert_true(is_equal_approx(float(player.get("special_skill_cooldown")), 1.0), "purchase lowers dodge cooldown")
	_runner.assert_true(room.call("is_offer_sold", &"dodge_refill"), "dodge refill offer is marked sold")


func test_shop_room_rejects_purchase_without_enough_ingame_currency() -> void:
	var room := _instantiate_shop_room()
	if room == null:
		return
	var player := _instantiate_player()
	if player == null:
		return
	add_child(room)
	add_child(player)
	room.enter()
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 2})

	_runner.assert_false(room.call("purchase_offer", &"bat", player), "shop rejects unaffordable offer")

	_runner.assert_eq(CurrencySystem.get_ingame(), 2, "failed purchase keeps ingame balance")
	_runner.assert_eq(player.call("current_weapon_name"), "맨손", "failed purchase does not equip item")
	_runner.assert_false(room.call("is_offer_sold", &"bat"), "failed purchase does not mark offer sold")


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
		&"shop_1": true,
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


func _instantiate_shop_room() -> Node:
	_runner.assert_true(ResourceLoader.exists("res://scenes/interactables/shop_room.tscn"), "shop room scene exists")
	if not ResourceLoader.exists("res://scenes/interactables/shop_room.tscn"):
		return null
	var packed := load("res://scenes/interactables/shop_room.tscn") as PackedScene
	_runner.assert_not_null(packed, "shop room scene loads")
	if packed == null:
		return null
	var room := packed.instantiate()
	_runner.assert_true(room.has_method("purchase_offer"), "shop room exposes purchase API")
	_runner.assert_true(room.has_method("is_offer_sold"), "shop room exposes sold-state API")
	_runner.assert_true(room.has_method("get_offer_text"), "shop room exposes offer UI text for tests")
	return room


func _instantiate_player() -> Node:
	_runner.assert_true(ResourceLoader.exists("res://scenes/player/player.tscn"), "player scene exists")
	if not ResourceLoader.exists("res://scenes/player/player.tscn"):
		return null
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	_runner.assert_not_null(packed, "player scene loads")
	if packed == null:
		return null
	var player := packed.instantiate()
	_runner.assert_true(player.has_method("equip_bat"), "player exposes bat upgrade")
	_runner.assert_true(player.has_method("equip_special_skill"), "player exposes special skill upgrade")
	return player
