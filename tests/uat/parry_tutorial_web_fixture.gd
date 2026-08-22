extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")

var _mode := "desktop_prepare"


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	GameManager.reset_session()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	GameManager.start_session({
		"source": "parry_tutorial_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 510,
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var manager := session.get_node("%RoomManager") as RoomManager
	var combat_room_id := _first_combat_room_id(manager.layout)
	if combat_room_id == &"" or not manager.enter_room(combat_room_id):
		print("UAT_PARRY_ERROR mode=%s reason=combat_room_missing" % _mode)
		return
	var room := manager.current_room
	var actor := session.get_node("%Player") as Node2D
	var first_wolf := _last_wolf(room)
	if first_wolf == null:
		print("UAT_PARRY_ERROR mode=%s reason=wolf_missing" % _mode)
		return
	_prepare_wolf(first_wolf, actor)
	var tutorial := session.get_node("%ParryOnboarding") as ParryOnboarding

	match _mode:
		"touch_prepare":
			session.get_node("%TouchControls").visible = true
			tutorial.show_for_wolf(first_wolf, &"touch")
		"miss":
			tutorial.call("_process", 3.5)
		"retry":
			first_wolf.call("take_damage", 99)
			room.call("_spawn_enemy_entry", {"enemy_type": &"wolf", "elite_variant": false, "sequence": 99})
			var retry_wolf := _last_wolf(room)
			if retry_wolf != null:
				_prepare_wolf(retry_wolf, actor)
		"success":
			first_wolf.call("tick_dash_ai", float(first_wolf.get("dash_windup_time")), first_wolf.global_position, actor.global_position)
			actor.call("_attack_melee", Vector2.RIGHT)

	await get_tree().process_frame
	await get_tree().process_frame
	var snapshot: Dictionary = session.call("get_parry_tutorial_snapshot")
	print(
		"UAT_PARRY_READY mode=%s active=%s complete=%s input_mode=%s target=%s tree_paused=%s"
		% [
			_mode,
			str(snapshot.get("active", false)).to_lower(),
			str(SaveManager.get_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE)).to_lower(),
			String(snapshot.get("input_mode", &"desktop")),
			String(snapshot.get("target_name", "")),
			str(get_tree().paused).to_lower(),
		]
	)


func _prepare_wolf(wolf: Node2D, actor: Node2D) -> void:
	actor.global_position = Vector2(100.0, 100.0)
	wolf.global_position = Vector2(140.0, 100.0)
	wolf.call("tick_dash_ai", 0.01, wolf.global_position, actor.global_position)


func _last_wolf(room: Node) -> Node2D:
	var enemies: Array = room.call("get_active_enemies") if room != null and room.has_method("get_active_enemies") else []
	for index: int in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index] as Node2D
		if enemy != null and String(enemy.name).contains("Wolf"):
			return enemy
	return null


func _first_combat_room_id(layout: RoomLayout) -> StringName:
	if layout == null:
		return &""
	for room_def: RoomDef in layout.room_defs:
		if room_def.room_type == RoomLayout.TYPE_COMBAT:
			return room_def.room_id
	return &""


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_parry_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-parry-mode="):
			return argument.trim_prefix("--uat-parry-mode=")
	return "desktop_prepare"
