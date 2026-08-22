extends Node2D

const COMBAT_ROOM_SCENE := preload("res://scenes/interactables/combat_room.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CHASER_SCENE := preload("res://scenes/enemies/akgwi.tscn")

var _mode := "multi_hit"
var _web_audio_unlocked := false


func _ready() -> void:
	_mode = _read_mode()
	if OS.has_feature("web"):
		set_process_input(true)
		print("UAT_COMBAT_SFX_WAITING_FOR_GESTURE mode=%s" % _mode)
	else:
		call_deferred("_setup")


func _input(event: InputEvent) -> void:
	if not OS.has_feature("web") or _web_audio_unlocked:
		return
	if not is_audio_unlock_event(event):
		return
	_web_audio_unlocked = true
	set_process_input(false)
	call_deferred("_setup")


static func is_audio_unlock_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	return false


func _setup() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	AudioManager.reset()
	var room := COMBAT_ROOM_SCENE.instantiate() as CombatRoom
	room.apply_room_config({
		"chaser_count": 0,
		"ranged_count": 0,
		"wolf_count": 0,
		"elite_chaser_count": 0,
		"elite_ranged_count": 0,
		"elite_wolf_count": 0,
	})
	add_child(room)
	var player := PLAYER_SCENE.instantiate()
	player.global_position = Vector2(0.0, 160.0)
	add_child(player)
	var camera := Camera2D.new()
	camera.global_position = Vector2(0.0, 40.0)
	add_child(camera)
	camera.make_current()

	match _mode:
		"multi_hit":
			_run_multi_hit(player)
		"reaction_mix":
			_run_reaction_mix(player)
		_:
			push_error("Unknown combat SFX UAT mode: %s" % _mode)


func _run_multi_hit(player: Node2D) -> void:
	var defeated_count := [0]
	var offsets := [Vector2(28.0, -12.0), Vector2(36.0, 0.0), Vector2(28.0, 12.0)]
	for index: int in range(3):
		var enemy := CHASER_SCENE.instantiate()
		enemy.max_hp = 1
		enemy.global_position = player.global_position + offsets[index]
		enemy.defeated.connect(func(_node: Node) -> void: defeated_count[0] += 1)
		add_child(enemy)
	player.call("_attack_melee", Vector2.RIGHT)
	var played := AudioManager.get_played_sfx()
	var valid := (
		int(defeated_count[0]) == 3
		and played == [AudioManager.BARE_HAND_SWING, AudioManager.ENEMY_HIT, AudioManager.ENEMY_DEATH]
	)
	_emit_marker(valid, played, int(defeated_count[0]), player.get_health())


func _run_reaction_mix(player: Node2D) -> void:
	var enemy := CHASER_SCENE.instantiate()
	enemy.global_position = player.global_position + Vector2.RIGHT * 30.0
	add_child(enemy)
	enemy.call("_try_contact", player)
	AudioManager.play_sfx(AudioManager.AWAKENED_BAT_REVEAL)
	var played := AudioManager.get_played_sfx()
	var valid := played == [AudioManager.CHASER_ATTACK, AudioManager.PLAYER_HIT, AudioManager.AWAKENED_BAT_REVEAL]
	_emit_marker(valid, played, 0, player.get_health())


func _emit_marker(valid: bool, played: Array[StringName], defeated_count: int, health: int) -> void:
	var active_players := int((AudioManager.get("_sfx_players") as Array).size())
	valid = valid and (active_players == played.size() if OS.has_feature("web") else active_players == 0)
	if not valid:
		push_error("Combat SFX UAT mismatch: mode=%s played=%s defeated=%d health=%d" % [_mode, played, defeated_count, health])
	print(
		"UAT_COMBAT_SFX_READY mode=%s played=%s defeated=%d health=%d active_players=%d valid=%s"
		% [
			_mode,
			str(played),
			defeated_count,
			health,
			active_players,
			str(valid).to_lower(),
		]
	)
	if OS.has_feature("web"):
		get_tree().paused = true
	else:
		call_deferred("_finish_headless")


func _finish_headless() -> void:
	for effect: Node in get_tree().get_nodes_in_group(&"enemy_death_fx"):
		if is_instance_valid(effect):
			effect.free()
	for child: Node in get_children():
		if is_instance_valid(child):
			remove_child(child)
			child.free()
	PoolManager.clear_all()
	HitStopManager.restore()
	AudioManager.reset()
	get_tree().quit()


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_combat_sfx_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-combat-sfx-mode="):
			return argument.trim_prefix("--uat-combat-sfx-mode=")
	return "multi_hit"
