extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")

var _mode := "before"


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	HitStopManager.set_process(true)
	HitStopManager.restore()
	PoolManager.clear_all()
	AudioManager.reset()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	GameManager.start_session({
		"source": "parry_feedback_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 512,
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var manager := session.get_node("%RoomManager") as RoomManager
	manager.enter_room(_first_combat_room_id(manager.layout))
	var wolf := _last_wolf(manager.current_room)
	var actor := session.get_node("%Player") as Node2D
	actor.global_position = Vector2(100.0, 100.0)
	wolf.global_position = Vector2(140.0, 100.0)
	wolf.call("tick_dash_ai", 0.01, wolf.global_position, actor.global_position)
	var controller := session.get_node("%ParryFeedbackController") as ParryFeedbackController

	match _mode:
		"before":
			_print_marker(session, controller)
		"impact":
			_perform_actual_parry(actor, wolf)
			_freeze_impact(session, controller)
			_print_marker(session, controller)
		"recovery":
			_perform_actual_parry(actor, wolf)
			session.call("_reset_parry_feedback_state", false)
			_print_marker(session, controller)
		"repeated":
			for index: int in range(25):
				controller.present({
					"player_position": Vector2(100.0 + index * 2.0, 100.0),
					"enemy_position": Vector2(140.0 + index * 2.0, 100.0),
					"direction": Vector2.RIGHT,
				})
			_freeze_impact(session, controller)
			_print_marker(session, controller)
		"teardown":
			controller.present({
				"player_position": Vector2(100.0, 100.0),
				"enemy_position": Vector2(140.0, 100.0),
				"direction": Vector2.RIGHT,
			})
			session.call("_exit_tree")
			_print_marker(session, controller)
		_:
			push_error("Unknown parry feedback mode: %s" % _mode)


func _perform_actual_parry(actor: Node2D, wolf: Node2D) -> void:
	wolf.call("tick_dash_ai", float(wolf.get("dash_windup_time")), wolf.global_position, actor.global_position)
	AudioManager.reset()
	actor.call("_attack_melee", Vector2.RIGHT)


func _freeze_impact(session: Node, controller: ParryFeedbackController) -> void:
	HitStopManager.set_process(false)
	var flash_tween := controller.get("_flash_tween") as Tween
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	controller.set("_flash_tween", null)
	var active_texts: Array = (PoolManager.get("_active") as Dictionary).get(&"floating_combat_text", [])
	for text_node: Node in active_texts:
		var lifetime_tween := text_node.get("_lifetime_tween") as Tween
		if lifetime_tween != null and lifetime_tween.is_valid():
			lifetime_tween.kill()
		text_node.set("_lifetime_tween", null)
	var camera_tween := session.get("_camera_feedback_tween") as Tween
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
	session.set("_camera_feedback_tween", null)


func _print_marker(session: Node, controller: ParryFeedbackController) -> void:
	var camera := session.get_node("%PlayerCamera") as Camera2D
	var flash_snapshot: Dictionary = controller.get_flash_snapshot()
	print(
		"UAT_PARRY_FEEDBACK_READY mode=%s time_scale=%.2f text_count=%d flash=%s camera_offset=%s pool_registered=%s"
		% [
			_mode,
			Engine.time_scale,
			PoolManager.get_active_count(&"floating_combat_text"),
			str(flash_snapshot.get("visible", false)).to_lower(),
			str(camera.offset),
			str(PoolManager.has_pool(&"floating_combat_text")).to_lower(),
		]
	)


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
				if pair.size() == 2 and pair[0] == "uat_parry_feedback_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-parry-feedback-mode="):
			return argument.trim_prefix("--uat-parry-feedback-mode=")
	return "before"
