extends Node

const DayCorridorScene := preload("res://scenes/dev/day_corridor_movement_test.tscn")
const HubDialogueScript := preload("res://scripts/ui/hub_dialogue_ui.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	# 진행도/세이브 공유 autoload 격리 — 소문 tier(first_visit)와 동적 소문 컨텍스트 안정화.
	ProgressionSystem.reset_for_tests()
	SaveManager.reset_profile()


func after_each() -> void:
	AudioManager.reset()
	SceneTransition.clear_pending_day_corridor_context()
	ProgressionSystem.reset_for_tests()
	SaveManager.reset_profile()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_day_corridor_starts_school_hallway_bgm() -> void:
	AudioManager.reset()
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.SCHOOL_HALLWAY_BGM, "day corridor starts the school hallway BGM")
	_runner.assert_eq(AudioManager.get_current_bgm_path(), "res://assets/audio/bgm/school_hallway_bgm.ogg", "day corridor uses the hallway BGM stream")


func test_day_corridor_scene_uses_mobile_landscape_plate() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var viewport_size: Vector2 = scene.get_reference_viewport_size()
	var bounds: Rect2 = scene.get_corridor_bounds()

	_runner.assert_eq(viewport_size, Vector2(960.0, 540.0), "dev scene targets mobile landscape reference")
	_runner.assert_eq(bounds.size, Vector2(2172.0, 720.0), "one school corridor plate forms the active room")
	_runner.assert_true(bounds.size.x > viewport_size.x * 2.0, "active room is wider than one landscape screen")
	_runner.assert_eq(scene.get_floor_y(), 628.0, "player is pinned lower to reduce bottom padding")
	_runner.assert_true(is_equal_approx(scene.get_reference_visible_world_size().y, bounds.size.y), "camera shows the full corridor plate height")
	_runner.assert_false((scene.get_node("%Camera2D") as Camera2D).position_smoothing_enabled, "day corridor camera disables smoothing to avoid movement ghosting")
	_runner.assert_true(is_equal_approx(scene.get_background_asset_scale(), 1.0), "final background is authored at runtime scale")
	_runner.assert_true(is_equal_approx(scene.get_character_asset_scale(), 2.4), "student sprite is scaled up for corridor readability")
	_runner.assert_true(scene.are_runtime_sprites_nearest_filtered(), "runtime sprites use nearest filtering")
	_runner.assert_eq(scene.get_talk_target_texture_path(), "res://assets/characters/school/baseball_captain.png", "talk target uses the baseball captain sprite")
	_runner.assert_eq(scene.get_school_character_texture_paths(), [
		"res://assets/characters/school/baseball_captain.png",
		"res://assets/characters/school/people3.png",
		"res://assets/characters/school/people4.png",
	], "school corridor wires the selected people assets")
	_runner.assert_eq(scene.get_left_school_character_count(), 1, "left corridor keeps only the talk target after people1 removal")
	_runner.assert_eq(scene.get_right_school_character_count(), 2, "right corridor balances two school character sprites")
	_runner.assert_true(scene.do_school_characters_match_background_tint(), "school characters share the corridor background tint")
	_runner.assert_true(scene.do_school_characters_match_player_scale(), "school characters use the same configured scale as the player")
	_runner.assert_true(scene.is_left_school_character_group_visible(), "left school character group starts visible")
	_runner.assert_false(scene.is_right_school_character_group_visible(), "right school character group starts hidden")
	_runner.assert_true(scene.is_talk_target_visible(), "left room starts with the talk target visible")
	_runner.assert_eq(scene.get_background_game_tint(), Color(0.94, 0.92, 0.88, 1), "day corridor uses an in-game background tint")
	_runner.assert_true(is_equal_approx(scene.get_background_wash_alpha(), 0.06), "day corridor applies a light focus wash before dialogue")
	_runner.assert_not_null(scene.get_node("%Player"), "placeholder player is mounted")
	_runner.assert_not_null(scene.get_node("%DayCharacterRoot"), "day-only character visual root is mounted")
	_runner.assert_not_null(scene.get_node("%CharacterSprite"), "student character sprite is mounted")
	_runner.assert_not_null(scene.get_node("%TalkTargetSprite"), "talk target sprite is mounted")
	_runner.assert_not_null(scene.get_node("%TouchControls"), "touch controls are mounted")
	_runner.assert_not_null(scene.get_node("%HubDialogueUi"), "hub dialogue UI is mounted")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "dialogue UI starts hidden")
	_runner.assert_eq(scene.get_objective_text(), "목표: 야구부 주장과 이야기하고, 밤의 궁으로 갈 준비를 하자", "first objective tells the player who to talk to")


func test_day_corridor_shows_only_day_character_visual_under_player() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: Node = scene.get_node("%Player")
	var day_root: Node = scene.get_node("%DayCharacterRoot")
	var character_sprite: Node = scene.get_node("%CharacterSprite")
	var visible_visual_roots: Array[Node] = []

	for child: Node in player.get_children():
		if child is CollisionShape2D:
			continue
		var item := child as CanvasItem
		if item != null and item.visible:
			visible_visual_roots.append(child)

	_runner.assert_eq(character_sprite.get_parent(), day_root, "student sprite is grouped under the day-only root")
	_runner.assert_eq(visible_visual_roots.size(), 1, "day scene hides default player visual roots")
	if visible_visual_roots.size() == 1:
		_runner.assert_eq(visible_visual_roots[0], day_root, "only the day-only visual root remains visible")


func test_day_corridor_routes_touch_attack_to_dialogue_not_combat() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: Node = scene.get_node("%Player")
	var proxy: Node = scene.get_node("%MoveOnlyTouchProxy")
	var touch_controls: Node = scene.get_node("%TouchControls")
	var attack_button: Control = touch_controls.get_node("AttackButton")
	var skill_button: Control = touch_controls.get_node("SkillButton")
	var interaction_prompt := scene.get_node("%InteractionPrompt") as Label
	var talk_button_label := scene.get_node("%TalkButtonLabel") as Label

	_runner.assert_eq(player.get("touch_controls_path"), NodePath("../MoveOnlyTouchProxy"), "player reads touch movement through the move-only proxy")
	_runner.assert_eq(touch_controls.get_control_category(), "day_dialogue", "day corridor uses the movement/dialogue touch control category")
	_runner.assert_true(attack_button.visible, "day corridor keeps the touch dialogue button visible")
	_runner.assert_false(skill_button.visible, "day corridor hides the dodge button")
	_runner.assert_false(interaction_prompt.visible, "world interaction helper starts hidden while out of range")
	_runner.assert_eq(talk_button_label.text, "", "touch action helper does not render the word 대화")
	_runner.assert_false(proxy.is_attack_pressed(), "proxy never forwards the touch attack button to player firing")
	_runner.assert_false(touch_controls.is_skill_pressed(), "day corridor does not expose dodge input through touch controls")
	_runner.assert_true(scene.is_combat_output_disabled(), "day scene removes projectile output and recoil")


func test_day_corridor_character_animates_and_flips_with_side_movement() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var sprite: Sprite2D = scene.get_node("%CharacterSprite")

	_runner.assert_eq(scene.get_character_frame_count(), 8, "walking sheet uses all eight frames")
	_runner.assert_true(scene.get_character_idle_frame_count() > 1, "idle has a visible frame loop")

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
	scene.call("_update_character_sprite", 0.0)
	var idle_start_frame := sprite.frame
	scene.call("_update_character_sprite", 0.7)
	# idle 생존 신호는 전용 idle 시트의 프레임 애니메이션으로 본다.
	# (position bob/둥둥은 idle 시트 도입으로 제거됨 — 튜닝값이라 단언하지 않는다.)
	_runner.assert_true(sprite.frame != idle_start_frame, "idle animates frames via the idle sheet")


func test_day_corridor_swaps_to_idle_sheet_when_standing() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var sprite: Sprite2D = scene.get_node("%CharacterSprite")
	var idle_texture: Texture2D = scene.get("character_idle_texture")
	_runner.assert_not_null(idle_texture, "scene wires a dedicated idle sheet")

	# 이동 중에는 걷기 시트(8프레임).
	player.velocity.x = 80.0
	scene.call("_update_character_sprite", 0.2)
	_runner.assert_eq(sprite.hframes, 8, "moving uses the 8-frame walking sheet")

	# 멈추면 idle 전용 시트(7프레임)로 스왑.
	player.velocity.x = 0.0
	scene.call("_update_character_sprite", 0.1)
	_runner.assert_eq(sprite.texture, idle_texture, "standing swaps to the idle sheet")
	_runner.assert_eq(sprite.hframes, 7, "idle sheet exposes its 7 frames")

	# 다시 이동하면 걷기 시트로 복귀.
	player.velocity.x = 80.0
	scene.call("_update_character_sprite", 0.1)
	_runner.assert_eq(sprite.hframes, 8, "moving again restores the walking sheet")


func test_day_corridor_plays_footstep_pair_on_walk_loop() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)
	AudioManager.reset()

	var player: CharacterBody2D = scene.get_node("%Player")
	player.velocity.x = 80.0

	scene.call("_update_character_sprite", 0.1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"corridor_footstep"], "walking starts one footstep pair")

	scene.call("_update_character_sprite", 0.2)
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"corridor_footstep"], "same walk loop does not retrigger footsteps")

	scene.call("_update_character_sprite", 0.8)
	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[&"corridor_footstep", &"corridor_footstep"],
		"next walk loop plays the next footstep pair"
	)

	AudioManager.reset()
	player.velocity.x = 0.0
	scene.call("_update_character_sprite", 0.2)
	_runner.assert_eq(AudioManager.get_played_sfx(), [], "standing does not play footsteps")


func test_day_corridor_internal_edges_fade_between_corridor_rooms() -> void:
	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	scene.outer_edge_scene_transition_enabled = false
	var maintenance_payloads: Array[Dictionary] = []
	add_child(scene)
	scene.maintenance_requested.connect(func(payload: Dictionary) -> void:
		maintenance_payloads.append(payload)
	)

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
	_runner.assert_false(scene.is_left_school_character_group_visible(), "left school characters hide after transition")
	_runner.assert_true(scene.is_right_school_character_group_visible(), "right school characters show after transition")
	_runner.assert_true(player.global_position.x < 520.0, "right room starts near its left entry")
	_runner.assert_true(sprite.flip_h, "right room entry faces back toward the connection")

	player.global_position = Vector2(scene.get_player_left_bound() - 1.0, scene.get_floor_y())
	player.velocity.x = -80.0
	_runner.assert_true(scene.update_room_transition_request(), "right room left edge transitions to left room")
	_runner.assert_eq(scene.get_current_room_id(), &"left", "transition lands back on left room")
	_runner.assert_true(scene.is_left_school_character_group_visible(), "left school characters restore after transition back")
	_runner.assert_false(scene.is_right_school_character_group_visible(), "right school characters hide after transition back")
	_runner.assert_true(player.global_position.x > scene.get_player_right_bound() - 520.0, "left room starts near its right entry")
	_runner.assert_false(sprite.flip_h, "left room entry faces back toward the connection")

	player.global_position = Vector2(scene.get_player_left_bound() - 1.0, scene.get_floor_y())
	player.velocity.x = -80.0
	_runner.assert_true(scene.update_room_transition_request(), "outer left edge opens the locker maintenance flow")
	_runner.assert_eq(scene.get_last_maintenance_edge(), &"outer_left", "outer left edge is reported")
	_runner.assert_eq(scene.get_current_room_id(), &"left", "maintenance request does not change the corridor room locally")
	_runner.assert_eq(maintenance_payloads.size(), 1, "maintenance request emits one payload")
	if maintenance_payloads.size() == 1:
		_runner.assert_eq(maintenance_payloads[0]["source"], &"day_corridor", "maintenance payload identifies the source")
		_runner.assert_eq(maintenance_payloads[0]["edge"], &"outer_left", "maintenance payload identifies the edge")
	_runner.assert_false(scene.update_room_transition_request(), "outer left maintenance request is gated after the first request")
	_runner.assert_eq(maintenance_payloads.size(), 1, "outer left does not emit repeated maintenance requests")


func test_day_corridor_outer_right_edge_requests_locker_maintenance() -> void:
	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	scene.outer_edge_scene_transition_enabled = false
	var maintenance_payloads: Array[Dictionary] = []
	add_child(scene)
	scene.maintenance_requested.connect(func(payload: Dictionary) -> void:
		maintenance_payloads.append(payload)
	)

	scene.call("_finish_room_transition", &"right")
	var player: CharacterBody2D = scene.get_node("%Player")
	player.global_position = Vector2(scene.get_player_right_bound() + 1.0, scene.get_floor_y())
	player.velocity.x = 80.0

	_runner.assert_true(scene.update_room_transition_request(), "outer right edge opens the locker maintenance flow")
	_runner.assert_eq(scene.get_last_maintenance_edge(), &"outer_right", "outer right edge is reported")
	_runner.assert_eq(scene.get_current_room_id(), &"right", "maintenance request does not change the corridor room locally")
	_runner.assert_eq(maintenance_payloads.size(), 1, "outer right emits one maintenance request")
	if maintenance_payloads.size() == 1:
		_runner.assert_eq(maintenance_payloads[0]["room_id"], &"right", "maintenance payload keeps the current corridor room")
	_runner.assert_false(scene.update_room_transition_request(), "outer right maintenance request is gated after the first request")
	_runner.assert_eq(maintenance_payloads.size(), 1, "outer right does not emit repeated maintenance requests")


func test_day_corridor_return_context_restores_room_and_spawn() -> void:
	SceneTransition.set_pending_day_corridor_context({
		SceneTransition.DAY_CORRIDOR_CONTEXT_ROOM_ID: &"right",
		SceneTransition.DAY_CORRIDOR_CONTEXT_EDGE_ID: &"outer_right",
	})

	var scene := DayCorridorScene.instantiate()
	add_child(scene)
	var player: CharacterBody2D = scene.get_node("%Player")

	_runner.assert_eq(scene.get_current_room_id(), &"right", "return context restores the right corridor room")
	_runner.assert_false(scene.is_left_school_character_group_visible(), "return context hides left school characters in the right room")
	_runner.assert_true(scene.is_right_school_character_group_visible(), "return context shows right school characters in the right room")
	_runner.assert_true(player.global_position.x < scene.get_player_right_bound(), "return context spawns inside the right outer edge")
	_runner.assert_true(player.global_position.x > scene.get_player_right_bound() - 520.0, "return context keeps the player near the right edge")
	_runner.assert_true(SceneTransition.get_pending_day_corridor_context().is_empty(), "return context is consumed after restore")


func test_day_corridor_dialogue_signal_updates_state() -> void:
	var scene := DayCorridorScene.instantiate()
	var payloads: Array[Dictionary] = []
	add_child(scene)
	scene.dialogue_requested.connect(func(payload: Dictionary) -> void:
		payloads.append(payload)
	)

	scene.trigger_dialogue()

	_runner.assert_eq(scene.get_dialogue_count(), 1, "dialogue count increments")
	_runner.assert_eq(scene.get_objective_text(), "목표: 복도 끝 사물함에서 기억 무기를 챙기자", "objective advances after the first memory beat")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "dialogue trigger opens the hub dialogue UI")
	_runner.assert_false(scene.is_touch_controls_visible(), "touch controls hide while the dialogue bar is open")
	_runner.assert_true(scene.is_talk_target_visible(), "world talk target remains visible behind the dialogue focus")
	_runner.assert_false(scene.get_node("%TalkButtonLabel").visible, "talk button helper label hides behind dialogue UI")
	_runner.assert_true(scene.get_node("%HubDialogueUi").is_dialogue_overlay_visible(), "dialogue UI dims the corridor behind it")
	_runner.assert_false(scene.get_node("%HubDialogueUi").is_dialogue_overlay_modal(), "dialogue overlay does not block the choice button")
	_runner.assert_false(scene.get_node("%HubDialogueUi").is_stage_row_visible(), "day corridor dialogue hides abstract stage labels")
	_runner.assert_true(scene.get_node("%HubDialogueUi").is_portrait_sprite_visible(), "dialogue UI shows the talk target sprite portrait")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_portrait_frame_count(), 6, "dialogue portrait uses the six-frame captain sprite sheet")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_portrait_texture_path(), "res://assets/characters/school/baseball_captain.png", "dialogue portrait uses the same sprite asset")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_portrait_frame(), 1, "dialogue portrait stays on the open-eye frame")
	_runner.assert_false(scene.get_node("%HubDialogueUi").is_portrait_animating(), "dialogue portrait does not blink while talking")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 0, "first trigger starts at the first dialogue line")
	_runner.assert_eq(scene.get_active_dialogue_text(), "낮엔 뛰지 말고, 얘기부터 하자.", "dialogue text is rendered without duplicating the speaker name")
	_runner.assert_eq(scene.get_active_dialogue_memory_text(), "기억: 창밖으로 밀려드는 낮빛", "memory text is rendered through HubDialogueUi")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "dialogue UI exposes only the currently available action")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_choice_texts(), [HubDialogueScript.CONTINUE_HINT_TOUCH], "first dialogue line exposes a tap-to-continue hint")
	_runner.assert_true(scene.get_node("%HubDialogueUi").is_tap_to_continue_active(), "first dialogue line advances from any dialogue tap")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(scene, "day_corridor.dialogue.next_button"), "next choice exposes a stable test id")
	_runner.assert_eq(payloads.size(), 1, "dialogue request signal emits once")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0]["source"], &"day_corridor", "dialogue payload identifies the day corridor")
		_runner.assert_eq(payloads[0]["line_index"], 0, "dialogue payload includes the current line index")


func test_day_corridor_onboarding_reward_dialogue_grants_bat_and_clue() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	_runner.assert_eq(scene.get_objective_text(), "목표: 야구부 주장에게 돌아가 배트와 단서를 받자", "onboarding completion directs player back to the captain")
	_runner.assert_false(SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED), "reward starts pending")

	scene.trigger_dialogue()
	_runner.assert_true(scene.is_dialogue_ui_visible(), "reward dialogue opens")
	_runner.assert_eq(scene.get_active_dialogue_text(), "고마워. 아까는 내가 제정신이 아니었던 것 같아.", "captain thanks the player without awkward repetition")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "reward dialogue starts with next")

	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to bat line")
	_runner.assert_true(scene.get_active_dialogue_text().contains("금 간 나무 배트"), "captain names the cracked wooden bat")
	_runner.assert_true(scene.get_active_dialogue_text().contains("이 배트는 적의 공격을 튕겨내거나 돌진하는 적을 효과적으로 막을 수 있어!"), "captain explains the bat's defensive combat role")
	_runner.assert_true(scene.get_node("%HubDialogueUi").get_dialogue_markup_text().contains("[b]이 배트는 적의 공격을 튕겨내거나 돌진하는 적을 효과적으로 막을 수 있어![/b]"), "bat defensive role line is bolded")
	_runner.assert_true(scene.perform_uat_action("day_corridor.dialogue.dismiss_unlock"), "bat pickup popup can be dismissed before clue line")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to clue line")
	_runner.assert_true(scene.get_active_dialogue_text().contains("도깨비왕"), "captain gives the goblin king clue")
	_runner.assert_true(scene.get_node("%HubDialogueUi").get_dialogue_markup_text().contains("[b]도깨비왕[/b]"), "goblin king clue bolds 도깨비왕")
	_runner.assert_true(scene.get_active_dialogue_text().contains("더 큰"), "captain leaves room for a stronger culprit")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"close"], "final reward line closes")

	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.dialogue.close_button"), "closing reward dialogue is testable")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "reward dialogue closes")
	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED), "bat and clue reward is claimed after the full dialogue")
	_runner.assert_eq(scene.get_objective_text(), "목표: 복도 끝 사물함에서 배트를 챙기고 경복궁으로 다시 가자", "post-reward objective points to the next MVP run")


func test_day_corridor_hides_gyeongbokgung_navigation_before_reward_claimed() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var arrow_label := scene.get_node_or_null("%GyeongbokgungRunArrowLabel") as Label
	_runner.assert_not_null(arrow_label, "day corridor exposes the Gyeongbokgung run navigation arrow")
	if arrow_label != null:
		_runner.assert_false(arrow_label.visible, "Gyeongbokgung navigation stays hidden while captain reward is pending")


func test_day_corridor_post_reward_guides_player_to_gyeongbokgung_entry_with_black_arrows() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var arrow_label := scene.get_node_or_null("%GyeongbokgungRunArrowLabel") as Label
	_runner.assert_not_null(arrow_label, "day corridor exposes the Gyeongbokgung run navigation arrow")
	if arrow_label != null:
		_runner.assert_true(arrow_label.visible, "post-reward state shows the Gyeongbokgung run navigation arrow")
		_runner.assert_eq(arrow_label.text, ">>>", "navigation uses the requested triple arrow")
		_runner.assert_eq(arrow_label.get_theme_color("font_color"), Color.BLACK, "navigation arrow is black")
		var glow_color := arrow_label.get_theme_color("font_shadow_color")
		_runner.assert_true(glow_color.r > 0.8 and glow_color.g > 0.55 and glow_color.b < 0.35, "navigation arrow uses a warm glow color")
		_runner.assert_true(glow_color.a >= 0.65, "navigation arrow glow is visible enough")
		_runner.assert_true(arrow_label.get_theme_constant("shadow_outline_size") >= 16, "navigation arrow has a broad glow halo")
		_runner.assert_eq(arrow_label.get_theme_constant("shadow_offset_x"), 0, "navigation glow is centered horizontally")
		_runner.assert_eq(arrow_label.get_theme_constant("shadow_offset_y"), 0, "navigation glow is centered vertically")
		_runner.assert_true(scene.has_method("is_run_navigation_arrow_glow_active"), "scene exposes arrow glow animation state")
		if scene.has_method("is_run_navigation_arrow_glow_active"):
			_runner.assert_true(scene.call("is_run_navigation_arrow_glow_active"), "navigation arrow glow pulse runs while visible")
		_runner.assert_true(arrow_label.anchor_left >= 0.85, "navigation arrow sits on the right side of the mobile landscape view")
		var arrow_right_edge: float = arrow_label.anchor_right * scene.get_reference_viewport_size().x + arrow_label.offset_right
		_runner.assert_true(arrow_right_edge <= scene.get_reference_viewport_size().x - 60.0, "navigation arrow respects the right phone safe-area inset")


func test_day_corridor_boss_resolved_prompts_report_to_captain_and_hides_run_arrow() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	SaveManager.save_session_result({
		"reason": "boss_resolved",
		"completed": true,
		"boss_id": &"gyeongbokgung_boss",
	})
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	_runner.assert_eq(scene.get_objective_text(), "목표: 야구부 주장에게 도깨비왕의 결말을 전하자", "boss clear return tells the player to report back")
	var arrow_label := scene.get_node_or_null("%GyeongbokgungRunArrowLabel") as Label
	_runner.assert_not_null(arrow_label, "day corridor exposes the Gyeongbokgung run navigation arrow")
	if arrow_label != null:
		_runner.assert_false(arrow_label.visible, "boss clear return hides the Gyeongbokgung re-entry arrow")
	var captain_arrow := scene.get_node_or_null("%BossReportArrowLabel") as Label
	_runner.assert_not_null(captain_arrow, "boss clear return exposes a captain report navigation arrow")
	if captain_arrow != null:
		_runner.assert_true(captain_arrow.visible, "boss clear return guides the player toward the captain")
		_runner.assert_eq(captain_arrow.text, "<<<", "captain report arrow points left toward the captain")
		var talk_target := scene.get_node("%TalkTarget") as Node2D
		_runner.assert_true(captain_arrow.global_position.x > talk_target.global_position.x, "captain report arrow sits right of the captain so its left arrows point at him")
		var glow_color := captain_arrow.get_theme_color("font_shadow_color")
		_runner.assert_true(glow_color.r > 0.8 and glow_color.g > 0.55 and glow_color.b < 0.35, "captain report arrow uses the same warm glow")
		_runner.assert_true(captain_arrow.get_theme_constant("shadow_outline_size") >= 16, "captain report arrow has a broad glow halo")
		_runner.assert_true(scene.has_method("is_boss_report_arrow_glow_active"), "scene exposes boss report arrow glow animation state")
		if scene.has_method("is_boss_report_arrow_glow_active"):
			_runner.assert_true(scene.call("is_boss_report_arrow_glow_active"), "captain report arrow glow pulse runs while visible")
	var callout_label := scene.get_node_or_null("%TalkTargetCalloutLabel") as Label
	_runner.assert_not_null(callout_label, "baseball captain callout exists")
	if callout_label != null:
		_runner.assert_true(callout_label.visible, "boss clear return marks the captain as the next action")
		_runner.assert_true(callout_label.text.contains("!"), "boss clear return uses an important callout")

	scene.trigger_dialogue()
	_runner.assert_true(scene.is_dialogue_ui_visible(), "boss clear report dialogue opens")
	_runner.assert_true(scene.get_active_dialogue_text().contains("도깨비왕"), "report dialogue reacts to the goblin king result")
	_runner.assert_true(scene.get_active_dialogue_text().contains("친구"), "report dialogue keeps the missing friend thread")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "boss report advances to the ending line")
	_runner.assert_true(scene.get_active_dialogue_text().contains("다음 단서"), "report dialogue lands on the open ending")
	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.dialogue.close_button"), "boss report can be closed")

	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_GYEONGBOKGUNG_BOSS_RESULT_ACKNOWLEDGED), "boss report is acknowledged after dialogue")
	_runner.assert_eq(scene.get_objective_text(), "목표: 친구의 행방은 아직 미궁 속이다", "post-boss report keeps the open ending state")
	if arrow_label != null:
		_runner.assert_false(arrow_label.visible, "acknowledged boss result still keeps the re-entry arrow hidden")
	if captain_arrow != null:
		_runner.assert_false(captain_arrow.visible, "acknowledged boss result hides the captain report arrow")


func test_day_corridor_boss_report_persists_after_later_run_until_acknowledged() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	SaveManager.save_session_result({
		"reason": "boss_resolved",
		"completed": true,
		"boss_id": &"gyeongbokgung_boss",
	})
	SaveManager.save_session_result({
		"outcome": "death",
		"died": true,
	})
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	_runner.assert_eq(scene.get_objective_text(), "목표: 야구부 주장에게 도깨비왕의 결말을 전하자", "unacknowledged boss report survives later run results")
	var arrow_label := scene.get_node_or_null("%GyeongbokgungRunArrowLabel") as Label
	_runner.assert_not_null(arrow_label, "day corridor exposes the Gyeongbokgung run navigation arrow")
	if arrow_label != null:
		_runner.assert_false(arrow_label.visible, "unacknowledged boss report keeps the re-entry arrow hidden after later runs")


func test_day_corridor_onboarding_reward_marks_baseball_captain_as_talk_target() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var callout_label := scene.get_node_or_null("%TalkTargetCalloutLabel") as Label
	_runner.assert_not_null(callout_label, "baseball captain has a visible world callout label")
	if callout_label != null:
		_runner.assert_true(callout_label.visible, "reward pending callout starts visible over the captain")
		_runner.assert_true(callout_label.text.contains("!"), "reward pending callout marks the captain as important")
		_runner.assert_true(callout_label.text.contains("야구부 주장"), "reward pending callout names the captain")

	var player := scene.get_node("%Player") as CharacterBody2D
	var talk_target := scene.get_node("%TalkTarget") as Node2D
	player.global_position = talk_target.global_position + Vector2(16.0, 0.0)
	scene.call("_update_interaction_prompt")

	var interaction_prompt := scene.get_node("%InteractionPrompt") as Label
	_runner.assert_true(interaction_prompt.visible, "approaching the captain shows an interaction prompt")
	_runner.assert_true(interaction_prompt.text.contains("야구부 주장"), "interaction prompt names the captain")
	_runner.assert_true(interaction_prompt.text.contains("말 걸기"), "interaction prompt tells the player they can talk")


func test_day_corridor_onboarding_reward_bat_line_shows_cracked_bat_pickup_popup() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to bat line")

	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")
	_runner.assert_true(dialogue_ui.is_unlock_visible(), "bat line shows a pickup popup")
	_runner.assert_eq(dialogue_ui.get_unlock_items().size(), 1, "bat pickup popup contains one reward item")
	if dialogue_ui.get_unlock_items().size() == 1:
		_runner.assert_eq(dialogue_ui.get_unlock_items()[0]["name"], "금 간 나무 배트", "bat pickup popup uses the established regular bat name")
	_runner.assert_false(scene.perform_uat_action("day_corridor.dialogue.next"), "pickup popup blocks advancing to the clue line")

	_runner.assert_true(scene.perform_uat_action("day_corridor.dialogue.dismiss_unlock"), "pickup popup can be dismissed without coordinates")
	_runner.assert_false(dialogue_ui.is_unlock_visible(), "pickup popup hides after dismissal")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "after pickup dismissal the dialogue advances to the clue line")
	_runner.assert_true(scene.get_active_dialogue_text().contains("도깨비왕"), "clue line remains after pickup popup")


func test_day_corridor_onboarding_reward_bridge_blocks_next_behind_bat_pickup_popup() -> void:
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var bridge: Node = scene.get_node("%UatCommandBridge")
	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")
	scene.trigger_dialogue()

	_runner.assert_true(bridge.press_by_uat_action("day_corridor.dialogue.next"), "bridge advances reward dialogue to bat line")
	_runner.assert_true(dialogue_ui.is_unlock_visible(), "bat pickup popup is visible")
	_runner.assert_false(bridge.press_by_uat_action("day_corridor.dialogue.next"), "bridge cannot advance behind the pickup popup")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "dialogue stays on the bat line while popup is visible")


func test_day_corridor_onboarding_reward_dialogue_completes_baseball_lobby_quest() -> void:
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to bat line")
	_runner.assert_true(scene.perform_uat_action("day_corridor.dialogue.dismiss_unlock"), "bat pickup popup is dismissed before clue line")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to clue line")
	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.dialogue.close_button"), "final reward line triggers quest completion")

	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")
	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED), "reward flag is claimed before the unlock popup closes")
	_runner.assert_true(ProgressionSystem.is_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY), "captain reward dialogue completes the lobby quest")
	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "lobby quest completion unlocks awakened bat")
	_runner.assert_true(dialogue_ui.is_unlock_visible(), "awakened bat popup is shown after the dialogue closes")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "dialogue content is closed before the awakened bat popup appears")
	_runner.assert_false(dialogue_ui.is_dialogue_content_visible(), "dialogue bar stays hidden behind the awakened bat popup")

	_runner.assert_true(scene.perform_uat_action("day_corridor.dialogue.dismiss_unlock"), "UAT can dismiss the unlock popup without coordinates")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "unlock dismiss closes the completed reward dialogue")
	_runner.assert_eq(scene.get_objective_text(), "목표: 복도 끝 사물함에서 배트를 챙기고 경복궁으로 다시 가자", "quest completion keeps the post-reward objective")


func test_day_corridor_onboarding_reward_back_close_completes_baseball_lobby_quest() -> void:
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to bat line")
	_runner.assert_true(scene.perform_uat_action("day_corridor.dialogue.dismiss_unlock"), "bat pickup popup is dismissed before clue line")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "reward dialogue advances to clue line")
	scene.call("_handle_back_request")

	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")
	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED), "back close claims the reward")
	_runner.assert_true(ProgressionSystem.is_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY), "back close completes the lobby quest")
	_runner.assert_true(ProgressionSystem.is_weapon_unlocked(&"awakened_bat"), "back close unlocks awakened bat")
	_runner.assert_true(dialogue_ui.is_unlock_visible(), "back close shows the unlock popup after closing the dialogue")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "back close hides dialogue content before the unlock popup")
	_runner.assert_false(dialogue_ui.is_dialogue_content_visible(), "back close keeps the dialogue bar hidden behind the unlock popup")

	scene.call("_handle_back_request")
	_runner.assert_false(dialogue_ui.is_unlock_visible(), "back while unlock is visible dismisses the unlock popup")
	_runner.assert_false(scene.is_return_confirm_visible(), "back while unlock is visible does not open the lobby return confirm")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "unlock back dismiss closes the completed reward dialogue")
	_runner.assert_eq(scene.get_objective_text(), "목표: 복도 끝 사물함에서 배트를 챙기고 경복궁으로 다시 가자", "back close keeps the post-reward objective")


func test_day_corridor_exit_button_confirms_lobby_return() -> void:
	var scene := DayCorridorScene.instantiate()
	var counts := {"return": 0}
	scene.return_to_lobby_callable = func() -> void: counts["return"] += 1
	add_child(scene)

	var exit_button := UiTestHarness.find_by_test_id(scene, "day_corridor.exit_button") as Button
	_runner.assert_not_null(exit_button, "exit button exposes a stable test id")
	_assert_pixel_button_style(exit_button, PixelButtonStyle.VARIANT_PRIMARY, "day exit")
	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.exit_to_lobby"), "exit action opens confirmation")
	_runner.assert_true(scene.is_return_confirm_visible(), "return confirmation opens")
	_runner.assert_eq(scene.get_return_confirm_message(), "로비로 돌아갈까요? 진행 상황은 자동으로 저장됩니다.", "return copy matches issue")

	_runner.assert_true(UiTestHarness.press_by_test_id(scene, ConfirmModal.TEST_ID_NO), "no keeps player in day corridor")
	_runner.assert_false(scene.is_return_confirm_visible(), "no closes confirmation")
	_runner.assert_eq(counts["return"], 0, "no does not return")

	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.exit_button"), "exit button can reopen confirmation")
	_runner.assert_true(UiTestHarness.press_by_test_id(scene, ConfirmModal.TEST_ID_YES), "yes confirms lobby return")
	_runner.assert_eq(counts["return"], 1, "yes returns once")


func test_day_corridor_dialogue_choices_advance_and_close_ui() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()
	_runner.assert_true(scene.is_talk_target_visible(), "open dialogue keeps the world talk target visible")

	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "harness presses next by action id")
	_runner.assert_eq(scene.get_dialogue_count(), 2, "next choice advances the dialogue counter")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "next choice advances to the second line")
	_runner.assert_eq(scene.get_active_dialogue_text(), "복도 끝 교실에 들르면 준비할 수 있어.", "second dialogue line is rendered")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "next choice keeps dialogue UI open")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "middle dialogue line still exposes only next")

	_runner.assert_true(UiTestHarness.press_by_uat_action(scene, "day_corridor.dialogue.next"), "harness presses next to the final line")
	_runner.assert_eq(scene.get_dialogue_count(), 3, "second next advances the dialogue counter")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 2, "second next advances to the final line")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"close"], "final dialogue line exposes only close")
	_runner.assert_eq(scene.get_node("%HubDialogueUi").get_choice_texts(), [HubDialogueScript.CONTINUE_HINT_TOUCH], "final dialogue line keeps the tap-to-continue affordance")
	_runner.assert_not_null(UiTestHarness.find_by_test_id(scene, "day_corridor.dialogue.close_button"), "close choice exposes a stable test id on the final line")

	_runner.assert_true(UiTestHarness.press_by_test_id(scene, "day_corridor.dialogue.close_button"), "harness presses close by test id")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "close choice hides dialogue UI")
	_runner.assert_true(scene.is_touch_controls_visible(), "touch controls return after dialogue closes")
	_runner.assert_true(scene.is_talk_target_visible(), "closing dialogue restores the world talk target")
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


func test_day_corridor_dialogue_tap_anywhere_advances_and_closes() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	scene.trigger_dialogue()
	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")

	_tap_dialogue(dialogue_ui)
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "first dialogue tap advances to the second line")

	_tap_dialogue(dialogue_ui)
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 2, "second dialogue tap advances to the final line")

	_tap_dialogue(dialogue_ui)
	_runner.assert_false(scene.is_dialogue_ui_visible(), "final dialogue tap closes the dialogue")


func test_day_corridor_final_tap_does_not_reopen_from_held_touch_attack() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var attack_button: Control = scene.get_node("%TouchControls/AttackButton")
	player.global_position = Vector2(1010.0, scene.get_floor_y())
	scene.trigger_dialogue()
	var dialogue_ui: Node = scene.get_node("%HubDialogueUi")

	_tap_dialogue(dialogue_ui)
	_tap_dialogue(dialogue_ui)
	attack_button.set("_active_index", 0)
	_tap_dialogue(dialogue_ui)
	scene.call("_process_dialogue_input")

	_runner.assert_false(scene.is_dialogue_ui_visible(), "final dialogue tap is consumed and does not immediately reopen dialogue")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), -1, "dialogue remains closed while the closing touch is still held")

	attack_button.set("_active_index", -1)


func test_day_corridor_uat_dispatcher_drives_dialogue_by_test_id() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var bridge: Node = scene.get_node("%UatCommandBridge")
	player.global_position = Vector2(950.0, scene.get_floor_y())

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.open_button"), "in-process dispatcher opens dialogue by test id")
	_runner.assert_true(scene.is_dialogue_ui_visible(), "test id open action opens the dialogue UI")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"next"], "first UAT state exposes next only")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.next_button"), "in-process dispatcher presses next by test id")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 1, "first next advances to the second line")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.next_button"), "in-process dispatcher presses next on the second line by test id")
	_runner.assert_eq(scene.get_active_dialogue_line_index(), 2, "second next advances to the final line")
	_runner.assert_eq(scene.get_dialogue_choice_ids(), [&"close"], "final UAT state exposes close only")

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.close_button"), "in-process dispatcher closes dialogue by test id")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "test id close action hides the dialogue UI")


func test_day_corridor_uat_dispatcher_rejects_hidden_dialogue_buttons() -> void:
	var scene := DayCorridorScene.instantiate()
	add_child(scene)

	var player: CharacterBody2D = scene.get_node("%Player")
	var bridge: Node = scene.get_node("%UatCommandBridge")
	player.global_position = Vector2(950.0, scene.get_floor_y())

	_runner.assert_true(bridge.press_by_test_id("day_corridor.dialogue.open_button"), "test setup opens dialogue by test id")
	scene.close_dialogue()

	_runner.assert_false(bridge.press_by_test_id("day_corridor.dialogue.next_button"), "닫힌 대화 UI의 남은 next 버튼은 누르지 않는다")
	_runner.assert_false(scene.is_dialogue_ui_visible(), "숨겨진 next 버튼 누름 시도는 대화를 다시 열지 않는다")
	_runner.assert_eq(scene.get_dialogue_count(), 1, "숨겨진 next 버튼은 대화 상태를 진행시키지 않는다")


func _tap_dialogue(dialogue_ui: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(32.0, 32.0)
	dialogue_ui.call("_input", event)


func _assert_pixel_button_style(button: Button, variant: StringName, label: String) -> void:
	_assert_pixel_button_texture(button.get_theme_stylebox("normal"), PixelButtonStyle.normal_texture_path(variant), "%s normal" % label)
	_assert_pixel_button_texture(button.get_theme_stylebox("pressed"), PixelButtonStyle.pressed_texture_path(variant), "%s pressed" % label)


func _assert_pixel_button_texture(style: StyleBox, texture_path: String, message: String) -> void:
	var texture_style := style as StyleBoxTexture
	_runner.assert_not_null(texture_style, "%s uses pixel button texture style" % message)
	if texture_style == null:
		return
	_runner.assert_eq(texture_style.texture.resource_path, texture_path, message)
	_runner.assert_eq(texture_style.texture_margin_left, 60.0, "%s left 9-slice margin" % message)
	_runner.assert_eq(texture_style.texture_margin_top, 12.0, "%s top 9-slice margin" % message)


# ── #202 ambient 소문 라벨 (people3 근접 / people4 군중) ──

func _enter_right_room(scene: Node) -> void:
	var player: CharacterBody2D = scene.get_node("%Player")
	player.global_position = Vector2(scene.get_player_right_bound() + 1.0, scene.get_floor_y())
	player.velocity.x = 80.0
	scene.update_room_transition_request()


## 조건(condition) 무관하게 화자+tier에 속한 소문인지 확인 (동적 소문 포함).
func _text_in_pool(rumors: GDScript, speaker: StringName, tier: StringName, text: String) -> bool:
	for entry: Dictionary in rumors.ENTRIES:
		if entry.get("speaker", &"") == speaker and entry.get("tier", &"") == tier:
			if String(entry.get("text", "")) == text:
				return true
	return false


func test_day_corridor_right_room_shows_ambient_rumors_first_visit() -> void:
	ProgressionSystem.reset_for_tests()
	SaveManager.reset_profile()
	var rumors: GDScript = load("res://resources/dialogue/day_school_rumors.gd")
	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	scene.outer_edge_scene_transition_enabled = false
	add_child(scene)

	_runner.assert_eq(scene.get_student3_rumor_label_text(), "", "people3 라벨은 시작 시 비어 있다")
	_runner.assert_eq(scene.get_crowd_rumor_label_text(), "", "people4 라벨은 시작 시 비어 있다")

	_enter_right_room(scene)
	_runner.assert_eq(scene.get_current_room_id(), &"right", "우측 방으로 진입한다")
	_runner.assert_eq(scene.get_ambient_tier(), rumors.TIER_FIRST_VISIT, "정화 전 ambient tier는 first_visit")

	var p3_text: String = scene.debug_show_student3_rumor()
	_runner.assert_true(p3_text != "", "people3 근접 라벨 텍스트가 채워진다")
	_runner.assert_true(
		_text_in_pool(rumors, rumors.SPEAKER_PEOPLE3, rumors.TIER_FIRST_VISIT, p3_text),
		"people3 라벨은 first_visit 풀 소속"
	)

	var p4_text: String = scene.debug_rotate_crowd_rumor()
	_runner.assert_true(p4_text != "", "people4 군중 조각이 채워진다")
	_runner.assert_true(
		_text_in_pool(rumors, rumors.SPEAKER_PEOPLE4, rumors.TIER_FIRST_VISIT, p4_text),
		"people4 조각은 first_visit 풀 소속"
	)

	ProgressionSystem.reset_for_tests()


func test_day_corridor_ambient_tier_reflects_progression() -> void:
	var rumors: GDScript = load("res://resources/dialogue/day_school_rumors.gd")
	ProgressionSystem.reset_for_tests()
	SaveManager.reset_profile()
	ProgressionSystem.record_friend_purified(rumors.FRIEND_BASEBALL_CAPTAIN)

	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	scene.outer_edge_scene_transition_enabled = false
	add_child(scene)
	_enter_right_room(scene)

	# #243: 정화만으론 강화배트 미해금 → ambient tier 는 post_purify
	_runner.assert_eq(
		scene.get_ambient_tier(), rumors.TIER_POST_PURIFY,
		"정화만으론 ambient tier 는 post_purify (#243)"
	)

	ProgressionSystem.reset_for_tests()


func test_day_corridor_ambient_tier_post_enhanced_after_lobby_quest() -> void:
	var rumors: GDScript = load("res://resources/dialogue/day_school_rumors.gd")
	ProgressionSystem.reset_for_tests()
	SaveManager.reset_profile()
	ProgressionSystem.record_friend_purified(rumors.FRIEND_BASEBALL_CAPTAIN)
	ProgressionSystem.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)

	var scene := DayCorridorScene.instantiate()
	scene.room_transition_fade_time = 0.0
	scene.outer_edge_scene_transition_enabled = false
	add_child(scene)
	_enter_right_room(scene)

	# 로비 퀘스트 완료로 강화배트 해금 → ambient tier 는 post_enhanced
	_runner.assert_eq(
		scene.get_ambient_tier(), rumors.TIER_POST_ENHANCED,
		"로비 퀘스트 완료 후 ambient tier 는 post_enhanced (#243)"
	)

	ProgressionSystem.reset_for_tests()
