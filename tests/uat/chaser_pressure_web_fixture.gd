extends Node2D

const COMBAT_ROOM_SCENE := preload("res://scenes/interactables/combat_room.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/ui/touch_controls.tscn")
const REGULAR_SPEED := 140.0
const TEACHING_SPEED := 92.0
const CONTACT_TIME_TOLERANCE_MS := 250.0
const EVADE_DISTANCE := 96.0

var _mode := "regular"
var _phase := "contact"
var _input_mode := "keyboard"
var _room: CombatRoom = null
var _actor: Node = null
var _enemy: Node2D = null
var _touch_controls: CanvasLayer = null
var _motion_started := false
var _motion_elapsed := 0.0
var _motion_start_distance := 0.0
var _actor_start_position := Vector2.ZERO
var _finished := false


func _ready() -> void:
	_mode = _read_query_value("uat_chaser_mode", "--uat-chaser-mode=", "regular")
	_phase = _read_query_value("uat_chaser_phase", "--uat-chaser-phase=", "contact")
	_input_mode = _read_query_value("uat_chaser_input", "--uat-chaser-input=", "keyboard")
	call_deferred("_setup")


func _process(delta: float) -> void:
	if _finished or _enemy == null or _actor == null:
		return
	if _enemy.has_method("is_spawn_protected") and bool(_enemy.call("is_spawn_protected")):
		return
	if not _motion_started:
		_motion_started = true
		_motion_start_distance = _enemy.global_position.distance_to((_actor as Node2D).global_position)
		if _phase == "start":
			_emit_marker()
		elif _phase == "evade":
			print("UAT_CHASER_INPUT_READY mode=%s input_mode=%s" % [_mode, _input_mode])
		return
	_motion_elapsed += delta
	if _phase == "evade":
		if (_actor as Node2D).global_position.distance_to(_actor_start_position) >= EVADE_DISTANCE:
			_emit_marker()
		return
	if int(_actor.call("get_health")) < int(_actor.get("max_health")):
		_emit_marker()


func _setup() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	HitStopManager.restore()
	PoolManager.clear_all()
	if _mode != "regular" and _mode != "teaching":
		push_error("Unknown chaser pressure UAT mode: %s" % _mode)
		return
	if _phase != "start" and _phase != "contact" and _phase != "evade":
		push_error("Unknown chaser pressure UAT phase: %s" % _phase)
		return
	if _phase == "evade" and _input_mode != "keyboard" and _input_mode != "touch":
		push_error("Unknown chaser pressure UAT input mode: %s" % _input_mode)
		return

	_room = COMBAT_ROOM_SCENE.instantiate() as CombatRoom
	var config := {
		"chaser_count": 1,
		"ranged_count": 0,
		"wolf_count": 0,
		"elite_chaser_count": 0,
		"elite_ranged_count": 0,
		"elite_wolf_count": 0,
		"wave_count": 1,
	}
	if _mode == "teaching":
		config["chaser_speed_override"] = TEACHING_SPEED
	_room.apply_room_config(config)
	add_child(_room)

	_actor = PLAYER_SCENE.instantiate()
	if _phase == "evade" and _input_mode == "touch":
		_touch_controls = TOUCH_CONTROLS_SCENE.instantiate() as CanvasLayer
		add_child(_touch_controls)
		_touch_controls.visible = true
		_actor.set("touch_controls_path", NodePath("../TouchControls"))
	(_actor as Node2D).global_position = Vector2(0.0, 180.0)
	_actor_start_position = (_actor as Node2D).global_position
	add_child(_actor)
	var camera := Camera2D.new()
	camera.name = "FixtureCamera"
	camera.global_position = Vector2(0.0, 50.0)
	add_child(camera)
	camera.make_current()

	_room.configure_actor(_actor as Node2D)
	_room.enter()
	var enemies := _room.get_active_enemies()
	if enemies.size() != 1 or not enemies[0] is Node2D:
		push_error("Chaser pressure fixture did not spawn exactly one enemy")
		return
	_enemy = enemies[0] as Node2D
	_motion_start_distance = _enemy.global_position.distance_to((_actor as Node2D).global_position)


func _emit_marker() -> void:
	_finished = true
	var expected_speed := REGULAR_SPEED if _mode == "regular" else TEACHING_SPEED
	var actual_speed := float(_enemy.get("move_speed"))
	var contact_range := float(_enemy.get("contact_range"))
	var expected_contact_ms := maxf(0.0, (_motion_start_distance - contact_range) / actual_speed * 1000.0)
	var health := int(_actor.call("get_health"))
	var max_health := int(_actor.get("max_health"))
	var elapsed_ms := _motion_elapsed * 1000.0
	var displacement := (_actor as Node2D).global_position.distance_to(_actor_start_position)
	var input_active := false
	if _input_mode == "touch" and _touch_controls != null:
		input_active = (_touch_controls.call("get_move") as Vector2).length() > 0.2
	elif _input_mode == "keyboard":
		input_active = (
			Input.is_physical_key_pressed(KEY_D)
			or Input.is_key_pressed(KEY_RIGHT)
			or Input.is_physical_key_pressed(KEY_A)
			or Input.is_key_pressed(KEY_LEFT)
			or Input.is_physical_key_pressed(KEY_W)
			or Input.is_key_pressed(KEY_UP)
			or Input.is_physical_key_pressed(KEY_S)
			or Input.is_key_pressed(KEY_DOWN)
		)
	var valid := is_equal_approx(actual_speed, expected_speed)
	if _phase == "contact":
		valid = (
			valid
			and health == max_health - 1
			and health > 0
			and absf(elapsed_ms - expected_contact_ms) <= CONTACT_TIME_TOLERANCE_MS
		)
	elif _phase == "evade":
		valid = valid and health == max_health and displacement >= EVADE_DISTANCE and input_active
	else:
		valid = valid and health == max_health
	if not valid:
		push_error(
			"Chaser pressure UAT mismatch: mode=%s phase=%s speed=%.2f elapsed=%.1f expected=%.1f health=%d"
			% [_mode, _phase, actual_speed, elapsed_ms, expected_contact_ms, health]
		)
	print(
		"UAT_CHASER_PRESSURE_READY mode=%s phase=%s input_mode=%s speed=%.2f initial_distance=%.2f contact_ms=%.1f expected_ms=%.1f displacement=%.1f input_active=%s health=%d valid=%s"
		% [
			_mode,
			_phase,
			_input_mode,
			actual_speed,
			_motion_start_distance,
			elapsed_ms,
			expected_contact_ms,
			displacement,
			str(input_active).to_lower(),
			health,
			str(valid).to_lower(),
		]
	)
	if OS.has_feature("web"):
		get_tree().paused = true
	else:
		call_deferred("_finish_headless")


func _finish_headless() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()
	PoolManager.clear_all()
	HitStopManager.restore()
	get_tree().quit()


func _read_query_value(query_key: String, argument_prefix: String, fallback: String) -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == query_key:
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(argument_prefix):
			return argument.trim_prefix(argument_prefix)
	return fallback
