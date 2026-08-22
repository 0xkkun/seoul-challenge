extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")
const INTRO_SCRIPT := preload("res://scripts/cutscene/night_intro_cutscene.gd")
const SETTINGS_SCENE := preload("res://scenes/ui/settings_ui.tscn")

var _mode := "controls_pc"


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup_mode")


func _setup_mode() -> void:
	_reset_state()
	match _mode:
		"controls_pc":
			_setup_controls(false, false)
		"controls_touch":
			_setup_controls(true, false)
		"objective":
			_setup_objective()
		"reward":
			_setup_reward()
		"purify_intro":
			_setup_purify(false)
		"purify_groggy":
			_setup_purify(true)
		"parry_pc":
			_setup_parry(false)
		"parry_touch":
			_setup_parry(true)
		"intro_pc":
			_setup_intro(false)
		"intro_touch":
			_setup_intro(true)
		"reduced_motion":
			_setup_controls(false, true)
		"settings":
			_setup_settings()
		_:
			push_error("Unknown coachmark UAT mode: %s" % _mode)


func _reset_state() -> void:
	get_tree().paused = false
	GameManager.reset_session()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	Settings.reset_defaults()


func _setup_controls(touch_mode: bool, reduced_motion: bool) -> void:
	Settings.set_reduced_motion_enabled(reduced_motion)
	var session := _new_onboarding_session()
	var onboarding := session.get_node("%IngameControlOnboarding") as IngameControlOnboarding
	var touch := session.get_node("%TouchControls") as CanvasLayer
	if touch_mode:
		onboarding.finish()
		touch.visible = true
		onboarding.configure(touch, session.get_node("%PlayerCamera"), session.get_node("%Player"), session.get_node("MinimapLayer/Minimap"))
		onboarding.start()
	await _settle()
	var snapshot: Dictionary = onboarding.get_current_step_snapshot()
	_emit_ready(snapshot, "이동")


func _setup_objective() -> void:
	var session := _new_onboarding_session()
	(session.get_node("%IngameControlOnboarding") as IngameControlOnboarding).finish()
	var manager := session.get_node("%RoomManager") as RoomManager
	manager.enter_room(&"combat_1")
	await _settle()
	_emit_ready(session.get_node("%SessionUIRoot").get_onboarding_journey_hint_snapshot(), "길 열기")


func _setup_reward() -> void:
	var session := _new_onboarding_session()
	(session.get_node("%IngameControlOnboarding") as IngameControlOnboarding).finish()
	var manager := session.get_node("%RoomManager") as RoomManager
	manager.enter_room(&"combat_1")
	session.call("_on_room_cleared_for_reward", {"room_id": &"combat_1", "room_type": &"combat"})
	session.call("flush_pending_reward_choice_for_tests")
	await _settle()
	var snapshot: Dictionary = session.get_node("%SessionUIRoot").get_reward_choice_snapshot()
	if not bool(snapshot.get("onboarding_eyebrow_visible")):
		push_error("Reward eyebrow did not open")
		return
	print("UAT_COACHMARK_READY mode=%s surface=reward reduced_motion=false" % _mode)


func _setup_purify(groggy: bool) -> void:
	var session := _new_onboarding_session()
	(session.get_node("%IngameControlOnboarding") as IngameControlOnboarding).finish()
	session.call("_advance_onboarding_journey", &"combat", &"reward")
	session.call("_advance_onboarding_journey", &"reward", &"friend_intro")
	var manager := session.get_node("%RoomManager") as RoomManager
	manager.enter_room(&"friend_1")
	for _index: int in range(6):
		if not bool(session.call("is_encounter_dialogue_visible")):
			break
		session.call("advance_encounter_dialogue_for_tests")
	if groggy:
		if bool(session.call("is_purify_onboarding_spotlight_visible")):
			session.call("dismiss_purify_onboarding_for_tests")
		var friends: Array = manager.current_room.call("get_active_friends")
		if friends.size() == 1:
			var friend := friends[0] as Node
			friend.call("take_damage", int(friend.get("max_stun")))
	await _settle()
	_emit_ready(session.call("get_purify_onboarding_snapshot"), "곁을 지켜 정화" if groggy else "기절시키기")


func _setup_parry(touch_mode: bool) -> void:
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	GameManager.start_session({
		"source": "coachmark_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 513,
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var manager := session.get_node("%RoomManager") as RoomManager
	var combat_room_id := _first_combat_room_id(manager.layout)
	manager.enter_room(combat_room_id)
	var room := manager.current_room
	var wolf := _last_wolf(room)
	var actor := session.get_node("%Player") as Node2D
	actor.global_position = Vector2(100.0, 100.0)
	wolf.global_position = Vector2(140.0, 100.0)
	wolf.call("tick_dash_ai", 0.01, wolf.global_position, actor.global_position)
	if touch_mode:
		session.get_node("%TouchControls").visible = true
		(session.get_node("%ParryOnboarding") as ParryOnboarding).show_for_wolf(wolf, &"touch")
	await _settle()
	_emit_ready((session.get_node("%ParryOnboarding") as ParryOnboarding).get_snapshot(), "받아치기")


func _setup_intro(touch_mode: bool) -> void:
	var intro := INTRO_SCRIPT.new() as NightIntroCutscene
	add_child(intro)
	var plate := intro.get_node("Plate") as TextureRect
	plate.texture = load(NightIntroCutscene.PLATES[0])
	plate.modulate.a = NightIntroCutscene.BACKDROP_ALPHA
	var subtitle := intro.get_node("Subtitle") as Label
	subtitle.text = "도시가 잠들면,"
	subtitle.modulate.a = 1.0
	var hint := intro.get_node("AdvanceHint") as Label
	hint.text = intro.continue_chip_text_for_mode(&"touch" if touch_mode else &"desktop")
	hint.modulate.a = 1.0
	await _settle()
	print("UAT_COACHMARK_READY mode=%s surface=intro reduced_motion=false" % _mode)


func _setup_settings() -> void:
	var settings_ui := SETTINGS_SCENE.instantiate() as SettingsUI
	add_child(settings_ui)
	settings_ui.open()
	await _settle()
	if settings_ui.get_toggle_text(Settings.KEY_REDUCED_MOTION) != "OFF":
		push_error("Reduced-motion settings row did not render")
		return
	print("UAT_COACHMARK_READY mode=settings surface=settings reduced_motion=false")


func _new_onboarding_session() -> Node:
	GameManager.start_session({
		"source": "coachmark_web_fixture",
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	return session


func _emit_ready(snapshot: Dictionary, expected_action: String) -> void:
	if not bool(snapshot.get("active", snapshot.get("visible", false))) or String(snapshot.get("action", "")) != expected_action:
		push_error("UAT coachmark state mismatch: mode=%s snapshot=%s" % [_mode, snapshot])
		return
	print("UAT_COACHMARK_READY mode=%s surface=%s reduced_motion=%s" % [
		_mode,
		String(snapshot.get("step_id", snapshot.get("id", snapshot.get("variant", &"coach")))),
		str(snapshot.get("reduced_motion", false)).to_lower(),
	])


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _first_combat_room_id(layout: RoomLayout) -> StringName:
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type == RoomLayout.TYPE_COMBAT:
			return room_def.room_id
	return &""


func _last_wolf(room: Node) -> Node2D:
	var enemies: Array = room.call("get_active_enemies")
	for index: int in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index] as Node2D
		if enemy != null and String(enemy.name).contains("Wolf"):
			return enemy
	return null


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_coachmark_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-coachmark-mode="):
			return argument.trim_prefix("--uat-coachmark-mode=")
	return "controls_pc"
