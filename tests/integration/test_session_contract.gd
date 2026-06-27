extends Node

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	ProgressionSystem.reset_for_tests()


func after_each() -> void:
	get_tree().paused = false
	PoolManager.clear_all()
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	ProgressionSystem.reset_for_tests()


func test_session_interaction_and_summary() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var dispatched: int = session.trigger_sample_interaction()
	_runner.assert_eq(dispatched, 1, "one interactable receives interaction check")
	_runner.assert_eq(session.completed_interactions, 1, "interaction updates session count")
	_runner.assert_eq(PoolManager.get_active_count(&"sample_marker"), 1, "interaction spawns pooled marker")

	var result: Dictionary = session.finish_session()
	_runner.assert_eq(result["interactions"], 1)
	_runner.assert_eq(result["rooms_cleared"], 1, "session summary includes cleared rooms")
	_runner.assert_eq(result["memory_reward"], 1, "session summary includes permanent reward delta")
	_runner.assert_eq(result["current_room_id"], &"start", "session summary includes current room")
	_runner.assert_false(GameManager.is_session_active(), "session is no longer active")

	session.queue_free()


func test_session_root_uses_new_layout_seed_without_config() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var layout_ids := {}

	for _index: int in range(4):
		GameManager.reset_session()
		var session := packed.instantiate()
		add_child(session)
		var manager := session.get_node("%RoomManager") as RoomManager
		_runner.assert_not_null(manager.layout, "session creates a run layout")
		if manager.layout != null:
			layout_ids[manager.layout.layout_id] = true
		remove_child(session)
		session.free()

	_runner.assert_true(layout_ids.size() > 1, "new runs without an explicit seed do not reuse one layout id")


func test_session_root_honors_explicit_layout_seed_config() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var layouts: Array[RoomLayout] = []

	for _index: int in range(2):
		GameManager.start_session({
			"source": "seeded_test",
			SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
		})
		var session := packed.instantiate()
		add_child(session)
		var manager := session.get_node("%RoomManager") as RoomManager
		layouts.append(manager.layout)
		remove_child(session)
		session.free()

	_runner.assert_eq(layouts.size(), 2, "test created two seeded run layouts")
	_runner.assert_eq(layouts[0].layout_id, &"generated_40", "explicit seed sets the generated layout id")
	_runner.assert_eq(_layout_signature(layouts[0]), _layout_signature(layouts[1]), "explicit seed keeps layout generation deterministic")

	GameManager.start_session({
		"source": "seeded_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 41,
	})
	var different_session := packed.instantiate()
	add_child(different_session)
	var different_manager := different_session.get_node("%RoomManager") as RoomManager
	_runner.assert_true(
		_layout_signature(layouts[0]) != _layout_signature(different_manager.layout),
		"different explicit seeds can change the room map"
	)
	remove_child(different_session)
	different_session.free()


func test_session_interaction_scope_reaches_current_shop_room() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var shop_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_SHOP)
	_runner.assert_not_null(shop_room_def, "session run layout includes shop room")
	if shop_room_def == null:
		return
	_runner.assert_true(manager.enter_room(shop_room_def.room_id), "test enters shop room directly")
	_runner.assert_true(manager.current_room.has_method("get_offer_position"), "shop room exposes offer position")
	if not manager.current_room.has_method("get_offer_position"):
		return
	actor.global_position = manager.current_room.call("get_offer_position", &"bat")
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 6})

	session.trigger_sample_interaction()

	_runner.assert_eq(CurrencySystem.get_ingame(), 2, "session interaction can purchase from current shop room")
	_runner.assert_eq(actor.call("current_weapon_name"), "야구배트", "session shop interaction equips purchased item")

	session.queue_free()


func test_combat_clear_requires_reward_choice_before_room_transition() -> void:
	GameManager.start_session({
		"source": "reward_choice_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node
	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		return
	_runner.assert_true(manager.enter_room(combat_room_def.room_id), "test enters combat reward room")
	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "reward choices are hidden before combat clear")

	for enemy: Node in manager.current_room.call("get_active_enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 99)

	_runner.assert_true(manager.is_current_room_cleared(), "combat room is cleared")
	_runner.assert_true(session_ui.call("is_reward_choice_visible"), "combat clear opens reward choice overlay")
	_runner.assert_true(get_tree().paused, "reward choice pauses room transition input")
	var snapshot: Dictionary = session_ui.call("get_reward_choice_snapshot")
	_runner.assert_eq((snapshot["choice_ids"] as Array).size(), 3, "reward choice offers three roguelike options")
	var chosen_item := (snapshot["choice_ids"] as Array)[0] as StringName
	_runner.assert_true(session_ui.call("select_reward_choice", chosen_item), "player can choose one reward")

	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "reward choice closes after selection")
	_runner.assert_false(get_tree().paused, "selection resumes the run")
	_runner.assert_true((actor.call("get_run_modifier_ids") as Array).has(chosen_item), "chosen reward applies to player run modifiers")

	session.queue_free()


func test_session_result_tracks_baseball_friend_purification_unlocks() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var friend_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_FRIEND)
	_runner.assert_not_null(friend_room_def, "session run layout includes a friend room")
	if friend_room_def == null:
		return
	_runner.assert_true(manager.enter_room(friend_room_def.room_id), "test enters generated friend room")
	var friends: Array = manager.current_room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "friend room spawns the purification target")
	if friends.size() == 1:
		var friend := friends[0] as Node
		friend.emit_signal("purified", friend)

	var result: Dictionary = session.finish_session()

	_runner.assert_eq(result["friends_purified"], 1, "session result counts purified friends")
	_runner.assert_eq(result["friend_ids"], [&"baseball_captain"], "session result records the baseball friend id")
	_runner.assert_true((result["unlocks"] as Array).has(&"awakened_bat"), "session result includes awakened bat unlock")
	_runner.assert_true((result["unlocks"] as Array).has(&"baseball_stage_3"), "session result includes baseball stage 3 unlock")

	session.queue_free()


func test_boss_victory_result_keeps_baseball_friend_unlocks() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var friend_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_FRIEND)
	var final_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_FINAL)
	_runner.assert_not_null(friend_room_def, "session run layout includes a friend room")
	_runner.assert_not_null(final_room_def, "session run layout includes a final room")
	if friend_room_def == null or final_room_def == null:
		return

	_runner.assert_true(manager.enter_room(friend_room_def.room_id), "test enters generated friend room")
	var friends: Array = manager.current_room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "friend room spawns the purification target")
	if friends.size() == 1:
		var friend := friends[0] as Node
		friend.emit_signal("purified", friend)
	_runner.assert_true(manager.enter_room(final_room_def.room_id), "test enters generated boss room")

	var defeated_boss := Node.new()
	session._on_boss_defeated(defeated_boss, manager.current_room)
	defeated_boss.free()

	var result := GameManager.get_last_result()
	_runner.assert_false(GameManager.is_session_active(), "boss victory finishes the active run")
	_runner.assert_eq(result.get("friends_purified", 0), 1, "boss victory result counts purified friends")
	_runner.assert_eq(result.get("friend_ids", []), [&"baseball_captain"], "boss victory result records the baseball friend id")
	_runner.assert_true((result.get("unlocks", []) as Array).has(&"awakened_bat"), "boss victory result includes awakened bat unlock")
	_runner.assert_true((result.get("unlocks", []) as Array).has(&"baseball_stage_3"), "boss victory result includes baseball stage 3 unlock")

	session.queue_free()


func test_session_root_preserves_existing_config() -> void:
	GameManager.start_session({"source": "preconfigured"})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	_runner.assert_eq(GameManager.get_active_config()["source"], "preconfigured")

	session.queue_free()


func test_session_map_tab_uses_stage_name_and_replaces_bottom_actions() -> void:
	GameManager.start_session({
		"source": "map_tab_test",
		"stage_name": "창덕궁",
	})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var map_tab: Button = session_ui.get_node("%MapTabButton")
	_runner.assert_eq(map_tab.text, "창덕궁", "session map tab uses the active run map name")
	_runner.assert_false(session_ui.call("is_action_panel_visible"), "session does not expose bottom action buttons")
	_runner.assert_eq(session_ui.get_node_or_null("%PauseButton"), null, "old pause button is removed from session UI")
	_runner.assert_eq(session_ui.get_node_or_null("%ResumeButton"), null, "old resume button is removed from session UI")
	_runner.assert_eq(session_ui.get_node_or_null("%FinishButton"), null, "old finish button is removed from session UI")

	session.queue_free()


func test_session_root_applies_locker_weapon_config() -> void:
	GameManager.start_session({
		"source": "night_map_select",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)
	var actor: Node = session.get_node("%Player")

	_runner.assert_eq(actor.call("current_weapon_name"), "야구배트", "bat locker selection equips the run actor")
	_runner.assert_false(bool(actor.get("ranged_enabled")), "bat locker selection keeps ranged baseball disabled")

	session.queue_free()


func test_session_root_applies_baseball_weapon_config() -> void:
	GameManager.start_session({
		"source": "night_map_select",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"baseball",
	})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)
	var actor: Node = session.get_node("%Player")

	_runner.assert_true(bool(actor.get("ranged_enabled")), "baseball locker selection enables ranged baseball")

	session.queue_free()


func test_session_ui_can_resume_while_tree_is_paused() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var map_tab: Button = session_ui.get_node("%MapTabButton")

	session._on_pause_requested()
	_runner.assert_true(get_tree().paused, "pause request pauses scene tree")
	_runner.assert_eq(session_ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	_runner.assert_true(session_ui.can_process(), "session UI still processes while paused")
	_runner.assert_true(map_tab.can_process(), "map tab still processes while paused")

	_runner.assert_true(UiTestHarness.press_by_test_id(session_ui, "session.map_tab"), "map tab can be pressed by stable test id")
	_runner.assert_false(get_tree().paused, "map tab resumes the paused scene tree")

	session.queue_free()


func test_session_render_layer_contract() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var world_layer := session.get_node("WorldLayer") as Node2D
	var room_layer := session.get_node("%RoomLayer") as Node2D
	var actor_layer := session.get_node("ActorLayer") as Node2D
	var interactable_layer := session.get_node("%InteractableLayer") as Node2D
	var pooled_object_layer := session.get_node("%PooledObjectLayer") as Node2D
	var session_ui := session.get_node("%SessionUIRoot") as CanvasLayer

	_runner.assert_eq(world_layer.z_index, RenderLayers.WORLD_BACKGROUND_Z)
	_runner.assert_eq(room_layer.z_index, RenderLayers.WORLD_BACKGROUND_Z)
	_runner.assert_eq(actor_layer.z_index, RenderLayers.WORLD_ACTOR_Z)
	_runner.assert_eq(interactable_layer.z_index, RenderLayers.WORLD_INTERACTABLE_Z)
	_runner.assert_eq(pooled_object_layer.z_index, RenderLayers.WORLD_EFFECT_Z)
	_runner.assert_eq(session_ui.layer, RenderLayers.UI_SESSION_LAYER)

	session.queue_free()


func test_session_camera_reacts_to_combat_feedback() -> void:
	_runner.assert_true(EventBus.has_method("emit_combat_feedback"), "combat feedback event wrapper exists")
	if not EventBus.has_method("emit_combat_feedback"):
		return

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var player_camera := session.get_node("%PlayerCamera") as Camera2D
	_runner.assert_eq(player_camera.offset, Vector2.ZERO, "camera starts without feedback offset")

	EventBus.emit_combat_feedback({
		"kind": &"melee_hit",
		"intensity": 4.0,
		"direction": Vector2.RIGHT,
	})

	_runner.assert_true(player_camera.offset.length() > 0.0, "combat feedback applies an immediate camera offset")

	session.queue_free()


func test_session_result_actions_unpause_and_preserve_retry_config() -> void:
	GameManager.start_session({
		"source": "session_result_test",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var action_counts := {"returned": 0}
	var retry_configs: Array[Dictionary] = []
	session.return_to_school_callable = func() -> void:
		action_counts["returned"] += 1
	session.retry_session_callable = func(config: Dictionary) -> Error:
		retry_configs.append(config.duplicate(true))
		GameManager.start_session(config)
		return OK

	session._on_pause_requested()
	session.finish_session()
	session._on_return_requested()
	_runner.assert_false(get_tree().paused, "return action unpauses before transition")
	_runner.assert_eq(action_counts["returned"], 1, "return action calls injected transition")

	session._on_pause_requested()
	session._on_retry_requested()
	_runner.assert_false(get_tree().paused, "retry action unpauses before transition")
	_runner.assert_eq(retry_configs.size(), 1, "retry action starts a new session once")
	_runner.assert_eq(retry_configs[0]["source"], "session_result_retry", "retry uses result retry source")
	_runner.assert_eq(retry_configs[0][SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID], &"bat", "retry keeps the selected locker weapon")
	session._exit_tree()
	_runner.assert_true(GameManager.is_session_active(), "retry handoff is not reset by old session exit")
	_runner.assert_eq(GameManager.get_active_config()["source"], "session_result_retry", "retry config survives old session exit")

	session.queue_free()


func test_player_death_shows_game_over_summary_without_lobby_transition() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	var action_counts := {"returned": 0}
	session.return_to_school_callable = func() -> void:
		action_counts["returned"] += 1
	add_child(session)

	var death_controller: DeathReturnController = session.get_node("%DeathReturnController")
	death_controller.trigger_death_return()

	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var snapshot: Dictionary = session_ui.get_summary_snapshot()
	_runner.assert_true(snapshot["visible"], "death shows the result summary overlay")
	_runner.assert_eq(snapshot["title"], "쓰러짐", "death summary uses game over title")
	_runner.assert_false(GameManager.is_session_active(), "death finishes the active run")
	_runner.assert_eq(GameManager.get_last_result().get("outcome", ""), "death", "death result is saved")
	_runner.assert_eq(action_counts["returned"], 0, "death does not immediately transition to lobby")
	_runner.assert_true(get_tree().paused, "gameplay freezes under the game over summary")

	get_tree().paused = false
	session.queue_free()


func test_room_change_configures_player_bounds_and_clears_motion() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as CharacterBody2D
	_runner.assert_true(actor.has_method("has_movement_bounds"), "세션 플레이어는 방 이동 경계 상태를 노출한다")
	_runner.assert_true(actor.has_method("get_movement_bounds"), "세션 플레이어는 현재 방 이동 경계를 노출한다")
	if not actor.has_method("has_movement_bounds") or not actor.has_method("get_movement_bounds"):
		session.queue_free()
		return
	_runner.assert_true(actor.call("has_movement_bounds"), "시작 방 진입 시 플레이어 이동 경계가 설정된다")
	var start_bounds: Rect2 = actor.call("get_movement_bounds")
	var play_bounds := RoomPalette.get_room_bounds()
	_runner.assert_eq(start_bounds.position, manager.current_room.global_position + play_bounds.position, "플레이어 이동 경계는 실제 플레이 가능 영역에서 시작한다")
	_runner.assert_eq(start_bounds.size, play_bounds.size, "플레이어 이동 경계는 실제 플레이 가능 영역 크기를 따른다")

	var connected_room_id := _first_connected_room_id(manager.layout, manager.current_room_id)
	_runner.assert_true(connected_room_id != &"", "테스트용 다음 방이 존재한다")
	if connected_room_id == &"":
		session.queue_free()
		return
	actor.velocity = Vector2(999.0, 0.0)

	_runner.assert_true(manager.enter_room(connected_room_id), "테스트가 다음 방으로 직접 진입한다")
	_runner.assert_eq(actor.velocity, Vector2.ZERO, "방 전환 뒤 남은 X축 속도를 초기화한다")
	var next_bounds: Rect2 = actor.call("get_movement_bounds")
	_runner.assert_eq(next_bounds.position, manager.current_room.global_position + play_bounds.position, "이동 경계는 현재 방 전역 위치에 맞춰 갱신된다")
	_runner.assert_eq(next_bounds.size, play_bounds.size, "다음 방 이동 경계도 실제 플레이 가능 영역 크기를 따른다")
	var local_spawn := actor.global_position - manager.current_room.global_position
	_runner.assert_true(local_spawn.x >= play_bounds.position.x and local_spawn.x <= play_bounds.end.x, "방 전환 후 플레이어는 X축 플레이 경계 안에 배치된다")

	session.queue_free()


func test_session_finish_request_confirms_abandon_to_lobby() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	var action_counts := {"returned": 0}
	session.return_to_school_callable = func() -> void:
		action_counts["returned"] += 1
	add_child(session)

	_runner.assert_true(GameManager.is_session_active(), "session starts active")
	session._on_finish_requested()
	_runner.assert_true(session.is_exit_confirm_visible(), "abandon confirmation opens")
	_runner.assert_eq(session.get_exit_confirm_message(), "런을 포기할까요? 이번 밤 보상은 사라지고 영구 재화는 유지됩니다", "abandon copy matches issue")
	_runner.assert_true(get_tree().paused, "abandon confirmation pauses gameplay")

	_runner.assert_true(UiTestHarness.press_by_test_id(session, ConfirmModal.TEST_ID_NO), "no cancels abandon")
	_runner.assert_false(session.is_exit_confirm_visible(), "no closes abandon confirmation")
	_runner.assert_false(get_tree().paused, "cancel restores the previous pause state")
	_runner.assert_true(GameManager.is_session_active(), "cancel keeps the run active")

	session._on_finish_requested()
	_runner.assert_true(UiTestHarness.press_by_test_id(session, ConfirmModal.TEST_ID_YES), "yes confirms abandon")
	_runner.assert_eq(action_counts["returned"], 1, "abandon returns to lobby once")
	_runner.assert_false(GameManager.is_session_active(), "abandon resets the active run")

	session.queue_free()


func test_room_base_lifecycle_opens_door_and_requests_transition() -> void:
	var packed := load("res://scenes/session/room_base.tscn") as PackedScene
	var room := packed.instantiate() as Room
	var entered_payloads: Array[Dictionary] = []
	var cleared_payloads: Array[Dictionary] = []
	var cleared_rooms: Array[StringName] = []
	var transitions: Array[Dictionary] = []
	var on_room_entered := func(payload: Dictionary) -> void:
		entered_payloads.append(payload)
	var on_room_cleared := func(payload: Dictionary) -> void:
		cleared_payloads.append(payload)
	var on_cleared := func(room_id: StringName) -> void:
		cleared_rooms.append(room_id)
	var on_transition_requested := func(room_id: StringName, door_dir: StringName) -> void:
		transitions.append({"room_id": room_id, "door_dir": door_dir})

	EventBus.room_entered.connect(on_room_entered)
	EventBus.room_cleared.connect(on_room_cleared)
	room.cleared.connect(on_cleared)
	room.transition_requested.connect(on_transition_requested)
	add_child(room)
	var actor := (load("res://scenes/actors/sample_actor.tscn") as PackedScene).instantiate() as Node2D
	add_child(actor)

	var exit_door := room.get_door(&"E")
	var floor := room.get_node("Floor") as ColorRect
	var door_visual := exit_door.get_node("DoorVisual") as ColorRect
	var portal_visual := exit_door.get_node_or_null("PortalVisual") as Node2D
	var door_shape := exit_door.get_node("TransitionArea/CollisionShape2D") as CollisionShape2D
	var door_rectangle := door_shape.shape as RectangleShape2D

	_runner.assert_not_null(exit_door, "base room exposes exit door")
	_runner.assert_not_null(portal_visual, "base room door builds a portal visual")
	if portal_visual != null:
		var portal_sprite := portal_visual.get_node_or_null("PortalSprite") as Sprite2D
		_runner.assert_not_null(portal_sprite, "base room portal uses the 5-frame sprite sheet visual")
		if portal_sprite != null:
			_runner.assert_eq(portal_sprite.hframes, 5, "base room portal has five horizontal frames")
			_runner.assert_eq(portal_sprite.texture.resource_path, "res://assets/effects/portal.png", "base room portal uses the supplied sprite sheet")
		_runner.assert_true(portal_visual.get_node_or_null("PortalColumn") == null, "base room portal does not keep the old light-gate visual")
	_runner.assert_not_null(door_rectangle, "base room door configures collision shape")
	_runner.assert_eq(floor.size, RoomPalette.ROOM_SIZE, "room floor uses palette size")
	_runner.assert_eq(floor.color, RoomPalette.START_ROOM_FLOOR_COLOR, "room floor uses palette color")
	_runner.assert_eq(exit_door.position, RoomPalette.EAST_DOOR_POSITION, "door uses palette position")
	_runner.assert_eq(door_visual.size, RoomPalette.DOOR_SIZE, "door visual uses palette size")
	_runner.assert_eq(door_rectangle.size, RoomPalette.DOOR_TRIGGER_SIZE, "door trigger uses palette size")
	_runner.assert_true(exit_door.is_locked(), "door starts locked")
	_runner.assert_eq(door_visual.color, RoomPalette.DOOR_LOCKED_COLOR, "door starts with locked palette color")
	if portal_visual != null:
		_runner.assert_false(portal_visual.visible, "locked door hides portal visual")
	room.configure_actor(actor)
	actor.global_position = exit_door.global_position
	_runner.assert_eq(room.check_actor_transitions(), 0, "locked door ignores actor overlap")

	room.enter()

	_runner.assert_true(room.has_entered(), "enter records lifecycle state")
	_runner.assert_true(room.has_been_cleared(), "default base room clears on enter")
	_runner.assert_eq(cleared_rooms.size(), 1, "room emits cleared once")
	_runner.assert_eq(entered_payloads.size(), 1, "room entered event emitted")
	_runner.assert_eq(cleared_payloads.size(), 1, "room cleared event emitted")
	_runner.assert_true(exit_door.is_open(), "door opens after clear")
	_runner.assert_true(door_visual.color.a < 0.01, "open door hides flat door rectangle")
	if portal_visual != null:
		_runner.assert_true(portal_visual.visible, "open door shows portal visual")

	if entered_payloads.size() == 1:
		_runner.assert_eq(entered_payloads[0]["room_id"], &"room_base", "entered payload has room id")
		_runner.assert_eq(entered_payloads[0]["room_type"], &"start", "entered payload has room type")
	if cleared_payloads.size() == 1:
		_runner.assert_eq(cleared_payloads[0]["door_dirs"][0], &"E", "cleared payload has door dir")

	var did_request_transition := room.check_actor_transitions()
	_runner.assert_eq(did_request_transition, 1, "open door accepts actor overlap transition")
	_runner.assert_eq(transitions.size(), 1, "room forwards door transition request")
	if transitions.size() == 1:
		_runner.assert_eq(transitions[0]["room_id"], &"room_base", "transition includes room id")
		_runner.assert_eq(transitions[0]["door_dir"], &"E", "transition includes door dir")
	_runner.assert_eq(room.check_actor_transitions(), 0, "door overlap transition emits once per entry")

	EventBus.room_entered.disconnect(on_room_entered)
	EventBus.room_cleared.disconnect(on_room_cleared)
	actor.queue_free()
	room.queue_free()


func _first_room_of_type(layout: RoomLayout, room_type: StringName) -> RoomDef:
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type == room_type:
			return room_def
	return null


func _first_connected_room_id(layout: RoomLayout, room_id: StringName) -> StringName:
	for connected_room_id: StringName in layout.get_connected_room_ids(room_id):
		return connected_room_id
	return &""


func _layout_signature(layout: RoomLayout) -> String:
	var parts: Array[String] = []
	for room_def: RoomDef in layout.room_defs:
		var connections: Array[String] = []
		for connected_id: StringName in room_def.connections:
			connections.append(String(connected_id))
		connections.sort()
		parts.append("%s:%s:%s:%s" % [
			room_def.room_id,
			room_def.room_type,
			room_def.grid_pos,
			",".join(connections),
		])
	parts.sort()
	return "|".join(parts)
