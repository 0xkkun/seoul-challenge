extends Node2D

const LAYOUT_PATH := "res://resources/layouts/gyeongbokgung.tres"
const COMBAT_ROOM_SCENE := preload("res://scenes/interactables/combat_room.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _mode := "wave_one"
var _spawn_payloads: Array[Dictionary] = []


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	var layout := load(LAYOUT_PATH) as RoomLayout
	var combat_def := layout.get_room(&"combat_2") if layout != null else null
	if combat_def == null:
		push_error("Combat wave fixture cannot find authored combat_2")
		return
	var room := COMBAT_ROOM_SCENE.instantiate() as CombatRoom
	room.room_id = combat_def.room_id
	room.apply_room_config(combat_def.room_config)
	room.enemy_spawned.connect(func(enemy: Node, enemy_type: StringName, wave_index: int) -> void:
		_spawn_payloads.append({"enemy": enemy, "enemy_type": enemy_type, "wave_index": wave_index})
	)
	add_child(room)
	var actor := PLAYER_SCENE.instantiate() as Node2D
	actor.global_position = Vector2(0.0, 180.0)
	add_child(actor)
	var camera := Camera2D.new()
	camera.name = "FixtureCamera"
	camera.global_position = Vector2(0.0, 50.0)
	add_child(camera)
	camera.make_current()
	room.configure_actor(actor)
	room.enter()

	match _mode:
		"wave_one":
			pass
		"wave_two":
			_defeat_current_wave(room)
			_clear_death_fx()
		"cleared":
			_defeat_current_wave(room)
			_defeat_current_wave(room)
			_clear_death_fx()
		_:
			push_error("Unknown combat wave UAT mode: %s" % _mode)
			return
	_emit_marker(room)


func _defeat_current_wave(room: CombatRoom) -> void:
	for enemy: Node in room.get_active_enemies():
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", 999)


func _clear_death_fx() -> void:
	for effect: Node in get_tree().get_nodes_in_group(&"enemy_death_fx"):
		effect.queue_free()


func _emit_marker(room: CombatRoom) -> void:
	var snapshot := room.get_wave_snapshot()
	var wave_zero_events := 0
	var wave_one_events := 0
	for payload: Dictionary in _spawn_payloads:
		if int(payload.get("wave_index", -1)) == 0:
			wave_zero_events += 1
		elif int(payload.get("wave_index", -1)) == 1:
			wave_one_events += 1
	var valid := false
	match _mode:
		"wave_one":
			valid = snapshot == {"configured": 2, "spawned": 1, "pending": 3, "active": 3} and wave_zero_events == 3 and not room.is_cleared()
		"wave_two":
			valid = snapshot == {"configured": 2, "spawned": 2, "pending": 0, "active": 3} and wave_zero_events == 3 and wave_one_events == 3 and not room.is_cleared()
		"cleared":
			valid = snapshot == {"configured": 2, "spawned": 2, "pending": 0, "active": 0} and _spawn_payloads.size() == 6 and room.is_cleared()
	if not valid:
		push_error("Combat wave UAT state mismatch: mode=%s snapshot=%s events=%s" % [_mode, snapshot, _spawn_payloads])
	print(
		"UAT_COMBAT_WAVE_READY mode=%s configured=%d spawned=%d pending=%d active=%d total_events=%d wave0_events=%d wave1_events=%d cleared=%s valid=%s"
		% [
			_mode,
			int(snapshot.get("configured", 0)),
			int(snapshot.get("spawned", 0)),
			int(snapshot.get("pending", 0)),
			int(snapshot.get("active", 0)),
			_spawn_payloads.size(),
			wave_zero_events,
			wave_one_events,
			str(room.is_cleared()).to_lower(),
			str(valid).to_lower(),
		]
	)
	if not OS.has_feature("web"):
		call_deferred("_finish_headless")


func _finish_headless() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	PoolManager.clear_all()
	HitStopManager.restore()
	get_tree().quit()


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_combat_wave_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-combat-wave-mode="):
			return argument.trim_prefix("--uat-combat-wave-mode=")
	return "wave_one"
