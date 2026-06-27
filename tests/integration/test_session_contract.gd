extends Node

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Settings.reset_defaults()
	AudioManager.reset()
	PoolManager.clear_all()
	GameManager.reset_session()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	ProgressionSystem.reset_for_tests()


func after_each() -> void:
	get_tree().paused = false
	AudioManager.reset()
	Settings.reset_defaults()
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


func test_session_hides_template_interactable_visual_during_gameplay() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var sample := session.get_node("%SampleInteractable")
	var body := sample.get_node_or_null("Body") as CanvasItem
	_runner.assert_not_null(body, "sample interactable keeps the harness body node")
	if body != null:
		_runner.assert_false(body.is_visible_in_tree(), "template sample interactable body is not rendered in gameplay")

	var dispatched: int = session.trigger_sample_interaction()
	_runner.assert_eq(dispatched, 1, "hidden sample interactable still keeps the interaction harness contract")

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


func test_session_root_uses_three_room_baseball_onboarding_layout() -> void:
	GameManager.start_session({
		"source": "intro",
		"stage_id": &"gyeongbokgung",
		"stage_name": "경복궁",
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node
	_runner.assert_not_null(manager.layout, "onboarding session creates a layout")
	if manager.layout == null:
		session.queue_free()
		return
	_runner.assert_eq(manager.layout.layout_id, &"onboarding_baseball_captain", "onboarding layout is explicit, not generated")
	_runner.assert_eq(manager.layout.get_room_ids(), [&"start", &"combat_1", &"friend_1"], "onboarding is exactly three straight rooms")
	_runner.assert_eq(manager.layout.get_connected_room_ids(&"start"), [&"combat_1"], "start connects only to the tutorial combat room")
	_runner.assert_eq(manager.layout.get_connected_room_ids(&"combat_1"), [&"start", &"friend_1"], "combat room connects linearly to the friend room")
	_runner.assert_eq(manager.layout.get_connected_room_ids(&"friend_1"), [&"combat_1"], "friend room is the onboarding endpoint")
	_runner.assert_eq((manager.layout.get_room(&"combat_1") as RoomDef).room_type, RoomLayout.TYPE_COMBAT, "middle onboarding room teaches combat")
	_runner.assert_eq((manager.layout.get_room(&"friend_1") as RoomDef).room_type, RoomLayout.TYPE_FRIEND, "final onboarding room is the purification target")
	_runner.assert_eq((manager.layout.get_room(&"combat_1") as RoomDef).room_config.get("chaser_count", -1), 1, "onboarding combat keeps one close-range enemy")
	_runner.assert_false(actor.call("has_bat"), "onboarding starts before the bat reward is claimed")

	session.queue_free()


func test_generated_session_rooms_never_enter_empty_uncleared_state() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene

	for layout_seed: int in range(50):
		PoolManager.clear_all()
		GameManager.reset_session()
		GameManager.start_session({
			"source": "empty_room_guard_test",
			SceneTransition.RUN_CONFIG_LAYOUT_SEED: layout_seed,
		})
		var session := packed.instantiate()
		add_child(session)
		var manager := session.get_node("%RoomManager") as RoomManager

		for room_def: RoomDef in manager.layout.room_defs:
			_runner.assert_true(manager.enter_room(room_def.room_id), "seed %d enters %s" % [layout_seed, room_def.room_id])
			_runner.assert_false(
				_is_empty_uncleared_room(session, manager),
				"seed %d %s/%s has no active objective and no open exit" % [layout_seed, room_def.room_id, room_def.room_type]
			)

		remove_child(session)
		session.free()


func test_west_entry_combat_spawns_objective_in_initial_mobile_view() -> void:
	GameManager.start_session({
		"source": "combat_initial_view_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		session.queue_free()
		return

	_runner.assert_true(manager.enter_room(combat_room_def.room_id, &"W"), "test enters combat room from the west door")
	var enemies: Array = manager.current_room.call("get_active_enemies")
	_runner.assert_true(enemies.size() > 0, "combat room spawns enemies")
	_runner.assert_true(
		_any_node_in_initial_mobile_view(actor, enemies),
		"west-entry combat shows at least one enemy in the first mobile viewport"
	)

	session.queue_free()


func test_west_entry_friend_room_spawns_target_in_initial_mobile_view() -> void:
	GameManager.start_session({
		"source": "friend_initial_view_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var friend_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_FRIEND)
	_runner.assert_not_null(friend_room_def, "session run layout includes friend room")
	if friend_room_def == null:
		session.queue_free()
		return

	_runner.assert_true(manager.enter_room(friend_room_def.room_id, &"W"), "test enters friend room from the west door")
	var friends: Array = manager.current_room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "friend room spawns the purification target")
	_runner.assert_true(
		_any_node_in_initial_mobile_view(actor, friends),
		"west-entry friend room shows the purification target in the first mobile viewport"
	)

	session.queue_free()


func test_baseball_onboarding_friend_purification_finishes_run_and_sets_reward_flag() -> void:
	GameManager.start_session({
		"source": "intro",
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	_runner.assert_true(manager.enter_room(&"friend_1"), "test enters the onboarding friend room")
	var friends: Array = manager.current_room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "onboarding friend room spawns the captain target")
	if friends.size() == 1:
		var friend := friends[0] as Node
		friend.emit_signal("purified", friend)

	var result := GameManager.get_last_result()
	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	_runner.assert_false(GameManager.is_session_active(), "purifying the onboarding target finishes the tutorial run")
	_runner.assert_eq(result.get("reason", ""), "onboarding_friend_purified", "result distinguishes onboarding completion")
	_runner.assert_eq(result.get("onboarding_kind", &""), SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN, "result records the onboarding kind")
	_runner.assert_eq(result.get("friend_ids", []), [&"baseball_captain"], "onboarding result records the purified captain")
	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE), "day corridor reward dialogue is unlocked")
	_runner.assert_false(SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED), "bat reward is still pending until the captain dialogue")
	_runner.assert_true(session_ui.call("is_summary_visible"), "onboarding completion opens the result summary")

	session.queue_free()


func test_session_generated_layout_omits_disabled_shop_and_event_rooms() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	_runner.assert_not_null(manager.layout, "session creates a generated layout")
	if manager.layout == null:
		return
	_runner.assert_eq(_first_room_of_type(manager.layout, RoomLayout.TYPE_SHOP), null, "generated session layout does not expose shop rooms")
	_runner.assert_eq(_first_room_of_type(manager.layout, RoomLayout.TYPE_EVENT), null, "generated session layout does not expose event/info rooms")

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
	var touch_controls: Node = session.get_node("%TouchControls")
	var joystick := touch_controls.get_node_or_null("Joystick") as Control
	var attack_button := touch_controls.get_node_or_null("AttackButton") as Control
	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		return
	_runner.assert_true(manager.enter_room(combat_room_def.room_id), "test enters combat reward room")
	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "reward choices are hidden before combat clear")
	_runner.assert_not_null(joystick, "session mounts joystick touch input")
	_runner.assert_not_null(attack_button, "session mounts attack touch button")
	if joystick != null:
		joystick.set("_active_index", 7)
		joystick.set("_value", Vector2.LEFT)
		_runner.assert_eq(touch_controls.call("get_move"), Vector2.LEFT, "test starts with held joystick movement")
	if attack_button != null:
		attack_button.set("_active_index", 8)
		_runner.assert_true(touch_controls.call("is_attack_pressed"), "test starts with held attack input")

	_defeat_all_combat_waves(manager.current_room)

	_runner.assert_true(manager.is_current_room_cleared(), "combat room is cleared")
	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "combat clear waits before showing reward choice cards")
	_runner.assert_false(get_tree().paused, "reward delay lets death cleanup and fade finish before pausing")
	_runner.assert_true(touch_controls.visible, "reward delay keeps combat controls visible until cards appear")
	_runner.assert_true(touch_controls.call("get_move") != Vector2.ZERO, "reward delay does not release held joystick until cards appear")
	_runner.assert_true(session.has_method("flush_pending_reward_choice_for_tests"), "session exposes deterministic reward delay flush")
	if not session.has_method("flush_pending_reward_choice_for_tests"):
		session.queue_free()
		return
	_runner.assert_true(session.call("flush_pending_reward_choice_for_tests"), "test flushes the pending reward delay")

	_runner.assert_true(session_ui.call("is_reward_choice_visible"), "reward delay opens reward choice cards")
	_runner.assert_true(get_tree().paused, "reward choice pauses room transition input")
	_runner.assert_false(touch_controls.visible, "reward choice hides paused combat controls behind the cards")
	_runner.assert_eq(touch_controls.call("get_move"), Vector2.ZERO, "reward choice opening releases held joystick movement")
	_runner.assert_false(touch_controls.call("is_attack_pressed"), "reward choice opening releases held attack input")
	var snapshot: Dictionary = session_ui.call("get_reward_choice_snapshot")
	_runner.assert_eq((snapshot["choice_ids"] as Array).size(), 3, "reward choice offers three roguelike options")
	_runner.assert_true(snapshot.has("choice_effects"), "reward snapshot exposes concrete stat effects")
	if not snapshot.has("choice_effects"):
		session.queue_free()
		return
	_runner.assert_eq((snapshot["choice_effects"] as Array).size(), 3, "reward choices expose concrete stat effects")
	_runner.assert_true(String((snapshot["choice_effects"] as Array)[0]) != "", "first reward has a readable stat effect")
	var chosen_item := (snapshot["choice_ids"] as Array)[0] as StringName
	_runner.assert_true(session_ui.call("select_reward_choice", chosen_item), "player can choose one reward")

	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "reward choice closes after selection")
	_runner.assert_false(get_tree().paused, "selection resumes the run")
	_runner.assert_true(touch_controls.visible, "selection restores combat controls")
	_runner.assert_true((actor.call("get_run_modifier_ids") as Array).has(chosen_item), "chosen reward applies to player run modifiers")

	session.queue_free()


func test_breathing_room_heals_when_later_combat_room_clears() -> void:
	GameManager.start_session({
		"source": "breathing_room_clear_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		session.queue_free()
		return
	_runner.assert_true(manager.enter_room(combat_room_def.room_id), "test enters combat room")
	actor.call("take_damage", 2)
	_runner.assert_eq(actor.call("get_health"), 3, "test starts with damaged player health")
	_runner.assert_true(actor.call("apply_run_modifier", &"breathing_room"), "breathing room reward applies before a later room clear")
	_runner.assert_eq(actor.call("get_health"), 3, "breathing room does not heal immediately on pickup")

	_defeat_all_combat_waves(manager.current_room)

	_runner.assert_true(manager.is_current_room_cleared(), "combat room is cleared")
	_runner.assert_eq(actor.call("get_health"), 4, "breathing room heals one heart when a later combat room clears")

	session.queue_free()


func test_combat_reward_delay_waits_for_pause_modal_to_close() -> void:
	GameManager.start_session({
		"source": "reward_pause_modal_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var modal := session.get_node("%ConfirmModal")
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		session.queue_free()
		return
	_runner.assert_true(manager.enter_room(combat_room_def.room_id), "test enters combat reward room")

	_defeat_all_combat_waves(manager.current_room)
	_runner.assert_true(manager.is_current_room_cleared(), "combat room is cleared")
	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "combat clear starts with delayed reward hidden")

	session._on_pause_requested()
	_runner.assert_true(modal.is_open(), "pause request opens confirm modal during reward delay")
	_runner.assert_true(get_tree().paused, "pause modal pauses gameplay during reward delay")
	_runner.assert_true(session.has_method("flush_pending_reward_choice_for_tests"), "session exposes deterministic reward delay flush")
	if not session.has_method("flush_pending_reward_choice_for_tests"):
		session.queue_free()
		return
	_runner.assert_false(session.call("flush_pending_reward_choice_for_tests"), "reward delay does not open cards while pause modal is open")
	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "reward choices stay hidden under pause modal")
	_runner.assert_true(modal.is_open(), "pause modal remains the active modal")
	_runner.assert_true(get_tree().paused, "tree remains paused only by the pause modal")

	session._on_resume_requested()
	_runner.assert_false(modal.is_open(), "continue closes the pause modal")
	_runner.assert_false(get_tree().paused, "continue resumes gameplay before reward cards open")
	_runner.assert_true(session.call("flush_pending_reward_choice_for_tests"), "pending reward opens after gameplay resumes")
	_runner.assert_true(session_ui.call("is_reward_choice_visible"), "reward cards open after pause modal closes")
	var snapshot: Dictionary = session_ui.call("get_reward_choice_snapshot")
	var chosen_item := (snapshot["choice_ids"] as Array)[0] as StringName
	_runner.assert_true(session_ui.call("select_reward_choice", chosen_item), "player can resolve reward after pause modal")
	_runner.assert_false(get_tree().paused, "reward selection resumes gameplay instead of restoring stale pause")

	session.queue_free()


func test_combat_reward_modal_wins_over_exit_door_open_transition() -> void:
	GameManager.start_session({
		"source": "reward_transition_timing_test",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 40,
	})
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var combat_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	_runner.assert_not_null(combat_room_def, "session run layout includes combat room")
	if combat_room_def == null:
		return
	_runner.assert_true(manager.enter_room(combat_room_def.room_id), "test enters combat reward room")
	var combat_room_id := manager.current_room_id
	var exit_door: RoomDoor = null
	for door: RoomDoor in manager.current_room.call("get_doors"):
		exit_door = door
		break
	_runner.assert_not_null(exit_door, "combat room exposes an exit door")
	if exit_door == null:
		session.queue_free()
		return
	for enemy: Node in manager.current_room.call("get_active_enemies"):
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 99)

	_runner.assert_false(session_ui.call("is_reward_choice_visible"), "combat clear waits before reward cards appear")
	_runner.assert_false(get_tree().paused, "reward delay does not freeze death cleanup")
	actor.global_position = exit_door.global_position
	_runner.assert_true(exit_door.check_transition_for_actor(actor), "standing on the exit can attempt transition during reward delay")
	_runner.assert_eq(manager.current_room_id, combat_room_id, "pending reward delay ignores the consumed overlap transition")
	_runner.assert_true(exit_door.request_transition(), "open exit can request transition during reward delay")
	_runner.assert_eq(manager.current_room_id, combat_room_id, "pending reward delay keeps player in the cleared combat room")
	_runner.assert_true(session.has_method("flush_pending_reward_choice_for_tests"), "session exposes deterministic reward delay flush")
	if not session.has_method("flush_pending_reward_choice_for_tests"):
		session.queue_free()
		return
	_runner.assert_true(session.call("flush_pending_reward_choice_for_tests"), "test flushes the pending reward delay")
	_runner.assert_true(session_ui.call("is_reward_choice_visible"), "reward delay opens reward before exit transition can steal the room")
	_runner.assert_eq(manager.current_room_id, combat_room_id, "reward pause keeps player in the cleared combat room")
	var snapshot: Dictionary = session_ui.call("get_reward_choice_snapshot")
	var chosen_item := (snapshot["choice_ids"] as Array)[0] as StringName
	_runner.assert_true(session_ui.call("select_reward_choice", chosen_item), "player can resolve the pending reward")
	_runner.assert_true(exit_door.check_transition_for_actor(actor), "reward resolution resets the consumed exit overlap")
	_runner.assert_true(manager.current_room_id != combat_room_id, "player standing on the exit transitions after reward selection")

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
	# #243: 강화배트는 정화에서 분리됨 — 정화 런 결과엔 stage 3 만, 배트는 없음(로비 퀘스트에서 해금).
	_runner.assert_false((result["unlocks"] as Array).has(&"awakened_bat"), "session result excludes awakened bat on purify alone")
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
	# #243: 정화 런(로비 퀘스트 전)이므로 결과에 강화배트 없음, stage 3 만.
	_runner.assert_false((result.get("unlocks", []) as Array).has(&"awakened_bat"), "boss victory result excludes awakened bat on purify alone")
	_runner.assert_true((result.get("unlocks", []) as Array).has(&"baseball_stage_3"), "boss victory result includes baseball stage 3 unlock")

	session.queue_free()


func test_session_root_preserves_existing_config() -> void:
	GameManager.start_session({"source": "preconfigured"})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	_runner.assert_eq(GameManager.get_active_config()["source"], "preconfigured")

	session.queue_free()


func test_session_root_starts_night_run_suspense_bgm() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.NIGHT_RUN_SUSPENSE_BGM, "session root starts the night run suspense BGM")
	_runner.assert_eq(AudioManager.get_current_bgm_path(), "res://assets/audio/bgm/night_run_suspense_bgm.ogg", "session root uses the night run suspense BGM stream")
	_runner.assert_true(AudioManager.is_bgm_playing(), "session root leaves the night run BGM active")

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


func test_session_combat_hud_avoids_top_right_minimap() -> void:
	GameManager.start_session({
		"source": "hud_layout_test",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var hud_panel := session.get_node("%CombatHud/Root/StubPanel") as Control
	var minimap := session.get_node("MinimapLayer/Minimap") as Control
	if not hud_panel.visible:
		_runner.assert_false(hud_panel.visible, "hidden combat HUD text cannot overlap the minimap")
		session.queue_free()
		return
	_runner.assert_false(hud_panel.get_global_rect().intersects(minimap.get_global_rect()), "combat HUD text does not overlap the minimap")

	session.queue_free()


func test_session_combat_hud_shows_initial_player_health() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var actor := session.get_node("%Player") as Node
	var combat_hud := session.get_node("%CombatHud") as CanvasLayer
	var session_ui := session.get_node("%SessionUIRoot") as CanvasLayer
	var health_panel := combat_hud.get_node("Root/HealthPanel") as Control
	var hearts := combat_hud.get_node("%Hearts") as HBoxContainer
	var map_tab := session_ui.get_node("%MapTabButton") as Button

	_runner.assert_true(combat_hud.visible, "전투 HUD 레이어는 세션 진입 직후 보인다")
	_runner.assert_true(health_panel.is_visible_in_tree(), "생명력 패널은 세션 진입 직후 표시된다")
	_runner.assert_eq(combat_hud.call("get_max_health"), int(actor.get("max_health")), "HUD는 플레이어 최대 체력을 즉시 반영한다")
	_runner.assert_eq(combat_hud.call("get_current_health"), actor.call("get_health"), "HUD는 플레이어 현재 체력을 즉시 반영한다")
	_runner.assert_eq(hearts.get_child_count(), int(actor.get("max_health")), "현재 체력만큼 렌더링할 하트 노드가 생성된다")
	_runner.assert_true(health_panel.get_global_rect().size.x > 0.0, "생명력 패널은 화면에 그릴 폭을 가진다")
	_runner.assert_false(
		health_panel.get_global_rect().intersects(map_tab.get_global_rect()),
		"생명력 패널은 좌상단 맵 탭에 가려지지 않는다"
	)

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

	_runner.assert_true(actor.call("has_bat"), "bat locker selection equips the run actor")
	_runner.assert_eq(actor.call("current_weapon_name"), "금 간 나무 배트", "bat locker selection shows cracked bat label")
	_runner.assert_false(bool(actor.get("ranged_enabled")), "bat locker selection keeps ranged baseball disabled")

	session.queue_free()


func test_session_player_awakens_bat_on_lobby_quest_not_purify() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor: Node = session.get_node("%Player")
	var combat_hud := session.get_node("%CombatHud") as CanvasLayer
	actor.call("equip_bat")
	_runner.assert_eq(actor.call("current_weapon_name"), "금 간 나무 배트", "run starts with regular bat")
	_runner.assert_true(combat_hud.call("get_weapon_text").contains("금 간 나무 배트"), "HUD shows regular bat after equip")
	var friend_room_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_FRIEND)
	_runner.assert_not_null(friend_room_def, "session run layout includes a friend room")
	if friend_room_def == null:
		session.queue_free()
		return
	_runner.assert_true(manager.enter_room(friend_room_def.room_id), "test enters generated friend room")
	var friends: Array = manager.current_room.call("get_active_friends")
	_runner.assert_eq(friends.size(), 1, "friend room spawns the purification target")
	if friends.size() == 1:
		var friend := friends[0] as Node
		friend.emit_signal("purified", friend)

	# #243: 정화만으론 배트가 해금·각성되지 않는다(정화/언락 분리).
	_runner.assert_false(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "purification alone does not unlock awakened bat")
	_runner.assert_false(actor.call("is_bat_awakened"), "session player stays un-awakened after purify alone")
	_runner.assert_eq(actor.call("current_weapon_name"), "금 간 나무 배트", "player keeps regular bat after purify alone")

	# 로비 퀘스트 완료가 강화배트를 해금하고, 같은 런의 플레이어가 unlock_changed 로 각성한다.
	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)

	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "lobby quest unlocks awakened bat")
	_runner.assert_true(actor.call("is_bat_awakened"), "session player receives the quest unlock event")
	_runner.assert_eq(actor.call("current_weapon_name"), "마지막 시즌의 배트", "session player shows awakened bat label")
	_runner.assert_true(combat_hud.call("get_weapon_text").contains("마지막 시즌의 배트"), "HUD updates to awakened bat label")

	session.queue_free()


func test_session_root_ignores_removed_baseball_weapon_config() -> void:
	GameManager.start_session({
		"source": "night_map_select",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"baseball",
	})

	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)
	var actor: Node = session.get_node("%Player")

	_runner.assert_false(bool(actor.get("ranged_enabled")), "removed baseball config does not enable ranged play")
	_runner.assert_true(bool(actor.call("has_bat")), "removed baseball config falls back to the story-backed bat")
	_runner.assert_eq(actor.call("current_weapon_name"), "금 간 나무 배트", "fallback weapon is the regular bat")

	session.queue_free()


func test_session_ui_can_resume_while_tree_is_paused() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var session_ui: CanvasLayer = session.get_node("%SessionUIRoot")
	var map_tab: Button = session_ui.get_node("%MapTabButton")
	var modal := session.get_node("%ConfirmModal") as ConfirmModal

	_runner.assert_true(UiTestHarness.press_by_test_id(session_ui, "session.map_tab"), "top-left map tab requests pause")
	_runner.assert_true(get_tree().paused, "pause request pauses scene tree")
	_runner.assert_eq(session_ui.process_mode, Node.PROCESS_MODE_ALWAYS)
	_runner.assert_true(session_ui.can_process(), "session UI still processes while paused")
	_runner.assert_true(map_tab.can_process(), "map tab still processes while paused")
	_runner.assert_true(modal.is_open(), "pause request opens a visible modal")
	_runner.assert_eq(modal.get_message_text(), "일시정지", "pause modal uses short player-facing copy")

	var continue_button := UiTestHarness.find_by_test_id(modal, ConfirmModal.TEST_ID_YES) as Button
	var exit_button := UiTestHarness.find_by_test_id(modal, ConfirmModal.TEST_ID_NO) as Button
	_runner.assert_eq(continue_button.text, "계속하기", "pause modal exposes a continue action")
	_runner.assert_eq(exit_button.text, "나가기", "pause modal exposes an exit action")
	_assert_pixel_button_style(exit_button, PixelButtonStyle.VARIANT_DANGER, "pause exit")

	_runner.assert_true(UiTestHarness.press_by_test_id(modal, ConfirmModal.TEST_ID_YES), "continue button can be pressed by stable test id")
	_runner.assert_false(modal.is_open(), "continue closes the pause modal")
	_runner.assert_false(get_tree().paused, "continue resumes the paused scene tree")

	session.queue_free()


func test_session_pause_modal_exit_opens_abandon_confirmation() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var modal := session.get_node("%ConfirmModal") as ConfirmModal
	session._on_pause_requested()

	_runner.assert_true(UiTestHarness.press_by_test_id(modal, ConfirmModal.TEST_ID_NO), "exit button can be pressed by stable test id")
	_runner.assert_true(modal.is_open(), "exit opens the abandon confirmation")
	_runner.assert_eq(modal.get_message_text(), "오늘 밤을 포기할까요? 이번 밤에 얻은 보상은 사라지지만 혼 조각은 남습니다", "exit action reuses the abandon confirmation")
	_runner.assert_true(get_tree().paused, "abandon confirmation keeps gameplay paused")

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


func test_player_death_shows_game_over_summary_without_immediate_transition() -> void:
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
	_runner.assert_eq(action_counts["returned"], 0, "death does not immediately transition to school")
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


func test_room_transition_spawns_player_at_entry_matching_source_door() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	add_child(session)

	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as CharacterBody2D
	manager.start_layout(_directional_spawn_layout())
	var cases: Array[Dictionary] = [
		{"door_dir": &"E", "target_room_id": &"east_shop", "entry_dir": &"W"},
		{"door_dir": &"W", "target_room_id": &"west_treasure", "entry_dir": &"E"},
		{"door_dir": &"N", "target_room_id": &"north_friend", "entry_dir": &"S"},
		{"door_dir": &"S", "target_room_id": &"south_event", "entry_dir": &"N"},
	]

	for test_case: Dictionary in cases:
		get_tree().paused = false
		_runner.assert_true(manager.enter_room(&"start"), "테스트가 시작 방으로 복귀한다")
		var door: RoomDoor = manager.current_room.get_door(test_case["door_dir"])
		_runner.assert_not_null(door, "시작 방은 %s 문을 노출한다" % test_case["door_dir"])
		if door == null:
			continue

		_runner.assert_true(door.request_transition(), "%s 문 전환 요청이 성공한다" % test_case["door_dir"])
		_runner.assert_eq(manager.current_room_id, test_case["target_room_id"], "문 방향에 맞는 연결 방으로 이동한다")
		_runner.assert_eq(manager.get("last_entry_door_dir"), test_case["entry_dir"], "매니저는 다음 방에 들어온 입구 방향을 보관한다")
		_assert_actor_spawned_near_entry(actor, manager.current_room, test_case["entry_dir"])

	session.queue_free()


func test_session_finish_request_confirms_abandon_to_school() -> void:
	var packed := load("res://scenes/session/session_root.tscn") as PackedScene
	var session := packed.instantiate()
	var action_counts := {"returned": 0}
	session.return_to_school_callable = func() -> void:
		action_counts["returned"] += 1
	add_child(session)

	_runner.assert_true(GameManager.is_session_active(), "session starts active")
	session._on_finish_requested()
	_runner.assert_true(session.is_exit_confirm_visible(), "abandon confirmation opens")
	_runner.assert_eq(session.get_exit_confirm_message(), "오늘 밤을 포기할까요? 이번 밤에 얻은 보상은 사라지지만 혼 조각은 남습니다", "abandon copy matches issue")
	_runner.assert_true(get_tree().paused, "abandon confirmation pauses gameplay")

	_runner.assert_true(UiTestHarness.press_by_test_id(session, ConfirmModal.TEST_ID_NO), "no cancels abandon")
	_runner.assert_false(session.is_exit_confirm_visible(), "no closes abandon confirmation")
	_runner.assert_false(get_tree().paused, "cancel restores the previous pause state")
	_runner.assert_true(GameManager.is_session_active(), "cancel keeps the run active")

	session._on_finish_requested()
	_runner.assert_true(UiTestHarness.press_by_test_id(session, ConfirmModal.TEST_ID_YES), "yes confirms abandon")
	_runner.assert_eq(action_counts["returned"], 1, "abandon returns to school once")
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


func _assert_pixel_button_style(button: Button, variant: StringName, label: String) -> void:
	_assert_pixel_button_texture(button.get_theme_stylebox("normal"), PixelButtonStyle.normal_texture_path(variant), "%s normal" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("hover"), PixelButtonStyle.normal_texture_path(variant), "%s hover" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("pressed"), PixelButtonStyle.pressed_texture_path(variant), "%s pressed" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("disabled"), PixelButtonStyle.normal_texture_path(variant), "%s disabled" % label)


func _assert_pixel_button_texture(style: StyleBox, expected_path: String, label: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses pixel style texture" % label)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, expected_path, "%s uses expected pixel texture" % label)


func _is_empty_uncleared_room(session: Node, manager: RoomManager) -> bool:
	if manager == null or manager.current_room == null:
		return true
	if manager.is_current_room_cleared():
		return false
	var room := manager.current_room
	if _active_count(room, "get_active_enemies") > 0:
		return false
	if _active_count(room, "get_active_students") > 0:
		return false
	if _active_count(room, "get_active_friends") > 0:
		return false
	if room.has_method("has_requested_spawn") and bool(room.call("has_requested_spawn")):
		var active_boss: Variant = session.get("_active_boss")
		if active_boss is Node and is_instance_valid(active_boss) and not (active_boss as Node).is_queued_for_deletion():
			return false
	return not _has_open_exit(room)


func _active_count(room: Node, method_name: String) -> int:
	if room == null or not room.has_method(method_name):
		return 0
	var nodes: Array = room.call(method_name)
	return nodes.size()


func _has_open_exit(room: Node) -> bool:
	if room == null or not room.has_method("get_doors"):
		return false
	for door: RoomDoor in room.call("get_doors"):
		if door.is_open():
			return true
	return false


func _any_node_in_initial_mobile_view(actor: Node2D, nodes: Array) -> bool:
	if actor == null:
		return false
	var view := _initial_mobile_view_rect(actor)
	for node: Node in nodes:
		if node is Node2D and view.has_point((node as Node2D).global_position):
			return true
	return false


func _initial_mobile_view_rect(actor: Node2D) -> Rect2:
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	return Rect2(actor.global_position - viewport_size * 0.5, viewport_size)


func _defeat_all_combat_waves(room: Node) -> void:
	var guard := 0
	while room.has_method("get_active_enemies") and room.has_method("is_cleared") and not room.call("is_cleared"):
		var enemies: Array = room.call("get_active_enemies")
		if enemies.is_empty():
			return
		for enemy: Node in enemies:
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", 99)
		guard += 1
		if guard > 8:
			return


func _first_connected_room_id(layout: RoomLayout, room_id: StringName) -> StringName:
	for connected_room_id: StringName in layout.get_connected_room_ids(room_id):
		return connected_room_id
	return &""


func _assert_actor_spawned_near_entry(actor: Node2D, room: Node2D, entry_dir: StringName) -> void:
	var play_bounds := RoomPalette.get_room_bounds()
	var local_spawn := actor.global_position - room.global_position
	var edge_inset := 170.0
	var center_tolerance := 90.0

	_runner.assert_true(play_bounds.has_point(local_spawn), "입장 스폰은 플레이 가능 영역 안에 있어야 한다")
	match entry_dir:
		&"W":
			_runner.assert_true(local_spawn.x <= play_bounds.position.x + edge_inset, "서쪽 입구로 들어오면 왼쪽 입구 근처에 등장한다")
			_runner.assert_true(absf(local_spawn.y) <= center_tolerance, "서쪽 입구 스폰은 문 중앙축 근처에 있다")
		&"E":
			_runner.assert_true(local_spawn.x >= play_bounds.end.x - edge_inset, "동쪽 입구로 들어오면 오른쪽 입구 근처에 등장한다")
			_runner.assert_true(absf(local_spawn.y) <= center_tolerance, "동쪽 입구 스폰은 문 중앙축 근처에 있다")
		&"N":
			_runner.assert_true(local_spawn.y <= play_bounds.position.y + edge_inset, "북쪽 입구로 들어오면 위쪽 입구 근처에 등장한다")
			_runner.assert_true(absf(local_spawn.x) <= center_tolerance, "북쪽 입구 스폰은 문 중앙축 근처에 있다")
		&"S":
			_runner.assert_true(local_spawn.y >= play_bounds.end.y - edge_inset, "남쪽 입구로 들어오면 아래쪽 입구 근처에 등장한다")
			_runner.assert_true(absf(local_spawn.x) <= center_tolerance, "남쪽 입구 스폰은 문 중앙축 근처에 있다")
		_:
			_runner.assert_true(false, "지원하지 않는 입장 방향: %s" % entry_dir)


func _directional_spawn_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = &"directional_spawn_test"
	layout.start_room_id = &"start"
	layout.room_defs = [
		_room_def(&"start", RoomLayout.TYPE_START, Vector2i(0, 0), [&"east_shop", &"west_treasure", &"north_friend", &"south_event"]),
		_room_def(&"east_shop", RoomLayout.TYPE_SHOP, Vector2i(1, 0), [&"start", &"east_combat"]),
		_room_def(&"west_treasure", RoomLayout.TYPE_TREASURE, Vector2i(-1, 0), [&"start"]),
		_room_def(&"north_friend", RoomLayout.TYPE_FRIEND, Vector2i(0, -1), [&"start"]),
		_room_def(&"south_event", RoomLayout.TYPE_EVENT, Vector2i(0, 1), [&"start"]),
		_room_def(&"east_combat", RoomLayout.TYPE_COMBAT, Vector2i(2, 0), [&"east_shop", &"south_combat"]),
		_room_def(&"south_combat", RoomLayout.TYPE_COMBAT, Vector2i(2, 1), [&"east_combat", &"final"]),
		_room_def(&"final", RoomLayout.TYPE_FINAL, Vector2i(3, 1), [&"south_combat"], true),
	]
	return layout


func _room_def(
	room_id: StringName,
	room_type: StringName,
	grid_pos: Vector2i,
	connections: Array[StringName],
	hidden := false
) -> RoomDef:
	var room_def := RoomDef.new()
	room_def.room_id = room_id
	room_def.room_type = room_type
	room_def.grid_pos = grid_pos
	room_def.connections = connections
	room_def.hidden = hidden
	room_def.scene_path = "res://scenes/session/room_base.tscn"
	return room_def


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
