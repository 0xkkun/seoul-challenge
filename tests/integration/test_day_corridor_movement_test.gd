extends Node

const DayCorridorScene := preload("res://scenes/dev/day_corridor_movement_test.tscn")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_day_corridor_scene_uses_mobile_landscape_plate() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var viewport_size: Vector2 = scene.get_reference_viewport_size()
	var bounds: Rect2 = scene.get_corridor_bounds()

	_runner.assert_eq(viewport_size, Vector2(960.0, 540.0), "dev scene targets mobile landscape reference")
	_runner.assert_eq(bounds.size, Vector2(2172.0, 720.0), "one school corridor plate forms the active room")
	_runner.assert_true(bounds.size.x > viewport_size.x * 2.0, "active room is wider than one landscape screen")
	_runner.assert_eq(scene.get_floor_y(), 616.0, "player is pinned to the corridor floor line")
	_runner.assert_true(is_equal_approx(scene.get_reference_visible_world_size().y, bounds.size.y), "camera shows the full corridor plate height")
	_runner.assert_true(is_equal_approx(scene.get_background_asset_scale(), 1.0), "final background is authored at runtime scale")
	_runner.assert_true(is_equal_approx(scene.get_character_asset_scale(), 2.0), "student sprite is scaled up for corridor readability")
	_runner.assert_true(scene.are_runtime_sprites_nearest_filtered(), "runtime sprites use nearest filtering")
	_runner.assert_not_null(scene.get_node("%Player"), "placeholder player is mounted")
	_runner.assert_not_null(scene.get_node("%CharacterSprite"), "student character sprite is mounted")
	_runner.assert_not_null(scene.get_node("%TouchControls"), "touch controls are mounted")
	_runner.assert_not_null(scene.get_node("%HubDialogueUi"), "hub dialogue UI is mounted")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "dialogue UI starts hidden")


func test_day_corridor_routes_touch_attack_to_dialogue_not_combat() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: Node = scene.get_node("%Player")
	var proxy: Node = scene.get_node("%MoveOnlyTouchProxy")

	_runner.assert_eq(player.get("touch_controls_path"), NodePath("../MoveOnlyTouchProxy"), "player reads touch movement through the move-only proxy")
	_runner.assert_false(proxy.is_attack_pressed(), "proxy never forwards the touch attack button to player firing")
	_runner.assert_true(scene.is_combat_output_disabled(), "day scene removes projectile output and recoil")


func test_day_corridor_character_animates_and_flips_with_side_movement() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var sprite: Sprite2D = scene.get_node("%CharacterSprite")

	_runner.assert_eq(scene.get_character_frame_count(), 8, "4x2 walking sheet uses all eight frames")

	player.velocity.x = 80.0
	scene.call("_update_character_sprite", 0.2)
	_runner.assert_false(sprite.flip_h, "right movement keeps the sprite facing right")
	_runner.assert_true(sprite.frame > 0, "movement advances walking frames")
	scene.call("_update_character_sprite", 0.7)
	_runner.assert_true(sprite.frame >= 4, "walking animation can advance into the second row")

	player.velocity.x = -80.0
	scene.call("_update_character_sprite", 0.2)
	_runner.assert_true(sprite.flip_h, "left movement flips the sprite")

	player.velocity.x = 0.0
	scene.call("_update_character_sprite", 0.2)
	_runner.assert_eq(sprite.frame, 0, "idle resets to the first frame")


func test_day_corridor_internal_edges_fade_between_corridor_rooms() -> void:
	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var left_bg: Sprite2D = scene.get_node("%SchoolBgLeft")
	var right_bg: Sprite2D = scene.get_node("%SchoolBgRight")
	var sprite: Sprite2D = scene.get_node("%CharacterSprite")

	_runner.assert_eq(scene.get_current_room_id(), &"left", "scene starts on the left school corridor plate")
	_runner.assert_true(left_bg.visible, "left background starts visible")
	_runner.assert_false(right_bg.visible, "right background starts hidden")

	player.global_position = Vector2(scene.get_player_right_bound() + 1.0, scene.get_floor_y())
	player.velocity.x = 80.0
	_runner.assert_true(scene.update_room_transition_request(), "left room right edge transitions to right room")
	_runner.assert_eq(scene.get_current_room_id(), &"right", "transition lands on right room")
	_runner.assert_false(left_bg.visible, "left background hides after transition")
	_runner.assert_true(right_bg.visible, "right background shows after transition")
	_runner.assert_true(player.global_position.x < 520.0, "right room starts near its left entry")
	_runner.assert_true(sprite.flip_h, "right room entry faces back toward the connection")

	player.global_position = Vector2(scene.get_player_left_bound() - 1.0, scene.get_floor_y())
	player.velocity.x = -80.0
	_runner.assert_true(scene.update_room_transition_request(), "right room left edge transitions to left room")
	_runner.assert_eq(scene.get_current_room_id(), &"left", "transition lands back on left room")
	_runner.assert_true(player.global_position.x > scene.get_player_right_bound() - 520.0, "left room starts near its right entry")
	_runner.assert_false(sprite.flip_h, "left room entry faces back toward the connection")

	player.global_position = Vector2(scene.get_player_left_bound() - 1.0, scene.get_floor_y())
	player.velocity.x = -80.0
	_runner.assert_false(scene.update_room_transition_request(), "outer left edge stays blocked for later handling")


func test_day_corridor_dialogue_signal_updates_state() -> void:
	var scene := DayCorridorScene.instantiate()
	var payloads: Array[Dictionary] = []
	add_child(scene)
	scene.dialogue_requested.connect(func(payload: Dictionary) -> void:
		payloads.append(payload)
	)

	scene.trigger_dialogue()

	_runner.assert_eq(scene.get_dialogue_count(), 1, "dialogue count increments")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "dialogue trigger opens the hub dialogue UI")
	_runner.assert_false(scene.is_touch_controls_visible(), "touch controls hide while the dialogue bar is open")
	_runner.assert_false(scene.get_node("%TalkButtonLabel").visible, "talk button helper label hides behind dialogue UI")
	_runner.assert_true(scene.get_node("%HubDialogueUi").is_dialogue_overlay_visible(), "dialogue UI dims the corridor behind it")
	_runner.assert_false(scene.get_node("%HubDialogueUi").is_dialogue_overlay_modal(), "dialogue overlay does not block the choice button")
	_runner.assert_false(scene.get_node("%HubDialogueUi").is_stage_row_visible(), "day corridor dialogue hides abstract stage labels")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 0, "first trigger starts at the first dialogue line")
	_runner.assert_eq(scene.get_active_dialogue_text(), "낮엔 뛰지 말고, 얘기부터 하자.", "dialogue text is rendered without duplicating the speaker name")
	_runner.assert_eq(scene.get_active_dialogue_memory_text(), "기억: 창밖으로 밀려드는 낮빛", "memory text is rendered through HubDialogueUi")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "dialogue UI exposes only the currently available action")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_choice_texts(), ["다음"], "first dialogue line exposes a single next button")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(scene, "day_corridor.dialogue.next_button"), "next choice exposes a stable test id")
	_runner.assert_eq(payloads.size(), 1, "dialogue request signal emits once")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0]["source"], &"day_corridor", "dialogue payload identifies the day corridor")
		_runner.assert_eq(payloads[0]["line_index"], 0, "dialogue payload includes the current line index")


func test_day_corridor_dialogue_choices_advance_and_close_ui() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()

	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "harness presses next by action id")
	_runner.assert_eq(scene.get_dialogue_count(), 2, "next choice advances the dialogue counter")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "next choice advances to the second line")
	_runner.assert_eq(scene.get_active_dialogue_text(), "복도 끝 교실에 들르면 준비가 끝나.", "second dialogue line is rendered")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "next choice keeps dialogue UI open")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "middle dialogue line still exposes only next")

	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "harness presses next to the final line")
	_runner.assert_eq(scene.get_dialogue_count(), 3, "second next advances the dialogue counter")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 2, "second next advances to the final line")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"close"], "final dialogue line exposes only close")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_choice_texts(), ["나가기"], "final dialogue line exposes a single exit button")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(scene, "day_corridor.dialogue.close_button"), "close choice exposes a stable test id on the final line")

	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.dialogue.close_button"), "harness presses close by test id")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "close choice hides dialogue UI")
	_runner.assert_true(scene.is_touch_controls_visible(), "touch controls return after dialogue closes")
	_runner.assert_true(scene.get_node("%TalkButtonLabel").visible, "talk button helper label returns after dialogue closes")


func test_day_corridor_dialogue_ignores_hidden_touch_attack_while_open() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var touch_controls: Node = scene.get_node("%TouchControls")
	var attack_button: Control = touch_controls.get_node("AttackButton")
	_runner.assert_not_null(UiTestHarness.find_by_uat_action(scene, "day_corridor.dialogue.open"), "dialogue open button exposes an action id")
	scene.trigger_dialogue()
	attack_button.set("_active_index", 0)
	scene.call("_process_dialogue_input")

	_runner.assert_eq(scene.get_active_dialogue_line_index(), 0, "dialogue stays on the current line while hidden touch controls are pressed")
	_runner.assert_eq(scene.get_dialogue_count(), 1, "hidden touch attack does not advance dialogue while the dialogue UI owns input")

	attack_button.set("_active_index", -1)


func test_day_corridor_uat_bridge_drives_dialogue_by_test_id() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var bridge: Node = scene.get_node("%UatCommandBridge")
	player.global_position = Vector2(950.0, scene.get_floor_y())

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.open_button"), "device bridge opens dialogue by test id")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "test id open action opens the dialogue UI")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "first UAT state exposes next only")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.next_button"), "device bridge presses next by test id")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "first next advances to the second line")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.next_button"), "device bridge presses next on the second line by test id")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 2, "second next advances to the final line")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"close"], "final UAT state exposes close only")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.close_button"), "device bridge closes dialogue by test id")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "test id close action hides the dialogue UI")
