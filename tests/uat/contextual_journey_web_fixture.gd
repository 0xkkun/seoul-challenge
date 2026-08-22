extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")
const DAY_CORRIDOR_SCENE := preload("res://scenes/dev/day_corridor_movement_test.tscn")

var _mode := "purify_groggy"


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup_mode")


func _setup_mode() -> void:
	match _mode:
		"day_talk":
			_setup_day_talk(false)
		"day_bat_popup":
			_setup_day_talk(true)
		_:
			_setup_purify_groggy()


func _setup_purify_groggy() -> void:
	GameManager.reset_session()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	GameManager.start_session({
		"source": "contextual_journey_web_fixture",
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var control_onboarding := session.get_node("%IngameControlOnboarding") as IngameControlOnboarding
	control_onboarding.finish()
	session.call("_advance_onboarding_journey", &"combat", &"reward")
	session.call("_advance_onboarding_journey", &"reward", &"friend_intro")
	var manager := session.get_node("%RoomManager") as RoomManager
	manager.enter_room(&"friend_1")
	for _index in range(4):
		if not bool(session.call("is_encounter_dialogue_visible")):
			break
		session.call("advance_encounter_dialogue_for_tests")
	if bool(session.call("is_purify_onboarding_spotlight_visible")):
		session.call("dismiss_purify_onboarding_for_tests")
	var friends: Array = manager.current_room.call("get_active_friends")
	if friends.size() == 1:
		var friend := friends[0] as Node
		friend.call("take_damage", int(friend.get("max_stun")))
	print("UAT_JOURNEY_READY mode=purify_groggy phase=%s" % [session.call("get_onboarding_journey_snapshot").get("phase")])


func _setup_day_talk(show_bat_popup: bool) -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	ProgressionSystem.record_friend_purified(&"baseball_captain")
	SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	var scene := DAY_CORRIDOR_SCENE.instantiate()
	add_child(scene)
	var player := scene.get_node("%Player") as CharacterBody2D
	var talk_target := scene.get_node("%TalkTarget") as Node2D
	player.global_position = talk_target.global_position + Vector2(16.0, 0.0)
	scene.call("_update_interaction_prompt")
	if show_bat_popup:
		scene.call("perform_uat_action", "day_corridor.dialogue.open")
		await get_tree().process_frame
		await get_tree().process_frame
		scene.call("perform_uat_action", "day_corridor.dialogue.next")
	print("UAT_JOURNEY_READY mode=%s phase=%s" % [_mode, scene.call("get_onboarding_journey_snapshot").get("phase")])


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_journey_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-journey-mode="):
			return argument.trim_prefix("--uat-journey-mode=")
	return "purify_groggy"
