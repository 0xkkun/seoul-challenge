extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")
const WOLF_SCENE := preload("res://scenes/enemies/wolf.tscn")

var _mode := "normal_active"
var _session: Node = null
var _actor: Node2D = null
var _enemy: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	HitStopManager.set_process(true)
	HitStopManager.restore()
	AudioManager.reset()
	PoolManager.clear_all()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	GameManager.start_session({
		"source": "general_hit_stop_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 526,
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	_session = SESSION_SCENE.instantiate()
	add_child(_session)
	_actor = _session.get_node("%Player") as Node2D
	_enemy = WOLF_SCENE.instantiate() as Node2D
	_enemy.set("max_hp", 20)
	_session.add_child(_enemy)
	_enemy.set_physics_process(false)
	_actor.global_position = Vector2(100.0, 100.0)
	_enemy.global_position = Vector2(148.0, 100.0)
	_run_mode()


func _run_mode() -> void:
	await _warm_up_web_frames()
	AudioManager.reset()
	match _mode:
		"normal_active":
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_hit_stop()
			_emit_marker()
		"power_active":
			_actor.call("try_start_special_skill", Vector2.RIGHT)
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_hit_stop()
			_emit_marker()
		"player_hurt_active":
			_actor.call("take_damage", 2)
			_freeze_active_hit_stop()
			_emit_marker()
		"rejected":
			_enemy.call("take_damage", 1)
			AudioManager.reset()
			_actor.call("_attack_melee", Vector2.RIGHT)
			_emit_marker()
		"parry_priority":
			HitStopManager.request(0.10, 0.05)
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_hit_stop()
			_emit_marker()
		"recovery":
			_run_recovery()
		"scene_exit":
			_actor.call("_attack_melee", Vector2.RIGHT)
			remove_child(_session)
			_session.free()
			_session = null
			_emit_marker()
		_:
			push_error("Unknown general hit-stop UAT mode: %s" % _mode)
			_finish_or_pause()


func _run_recovery() -> void:
	_actor.call("_attack_melee", Vector2.RIGHT)
	var started_at_usec := Time.get_ticks_usec()
	if DisplayServer.get_name() == "headless":
		HitStopManager.call("_process", 0.0045)
	else:
		await get_tree().create_timer(0.10, true, false, true).timeout
		await get_tree().process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started_at_usec) / 1000.0
	_emit_marker(elapsed_ms)


func _emit_marker(elapsed_ms: float = 0.0) -> void:
	var remaining := HitStopManager.get_remaining_real_seconds()
	var scale := HitStopManager.get_active_scale()
	var active := HitStopManager.is_active()
	var engine_scale := Engine.time_scale
	var camera_offset := Vector2.ZERO
	var vignette_snapshot := {}
	if _session != null:
		camera_offset = (_session.get_node("%PlayerCamera") as Camera2D).offset
		vignette_snapshot = (_session.get_node("%DamageVignette") as DamageVignette).get_snapshot()
	var played := AudioManager.get_played_sfx()
	var valid := false
	match _mode:
		"normal_active":
			valid = active and is_equal_approx(remaining, 0.03) and is_equal_approx(scale, 0.15) and camera_offset.length() > 0.0 and played == [&"bat_swing", &"enemy_hit", &"bat_hit"]
		"power_active":
			valid = active and is_equal_approx(remaining, 0.06) and is_equal_approx(scale, 0.08) and camera_offset.length() > 0.0
		"player_hurt_active":
			valid = active and is_equal_approx(remaining, 0.05) and is_equal_approx(scale, 0.10) and bool(vignette_snapshot.get("damage_pulse_active", false)) and played == [&"player_hit"]
		"rejected":
			valid = not active and is_equal_approx(engine_scale, 1.0) and camera_offset == Vector2.ZERO and played == [&"bat_swing"]
		"parry_priority":
			valid = active and is_equal_approx(remaining, 0.10) and is_equal_approx(scale, 0.05)
		"recovery":
			valid = not active and is_equal_approx(engine_scale, 1.0) and (DisplayServer.get_name() == "headless" or elapsed_ms >= 80.0)
		"scene_exit":
			valid = not active and is_equal_approx(engine_scale, 1.0)
	if not valid:
		push_error(
			"General hit-stop UAT mismatch: mode=%s active=%s remaining=%.3f scale=%.2f engine=%.2f camera=%s played=%s vignette=%s elapsed_ms=%.1f"
			% [_mode, active, remaining, scale, engine_scale, camera_offset, played, vignette_snapshot, elapsed_ms]
		)
	print(
		"UAT_GENERAL_HIT_STOP_READY mode=%s active=%s remaining=%.3f scale=%.2f engine=%.2f camera=%s played=%s vignette_pulse=%s elapsed_ms=%.1f valid=%s"
		% [
			_mode,
			str(active).to_lower(),
			remaining,
			scale,
			engine_scale,
			camera_offset,
			played,
			str(vignette_snapshot.get("damage_pulse_active", false)).to_lower(),
			elapsed_ms,
			str(valid).to_lower(),
		]
	)
	_finish_or_pause()


func _freeze_active_hit_stop() -> void:
	HitStopManager.set_process(false)
	if _session != null:
		(_session.get_node("%DamageVignette") as DamageVignette).set_process(false)


func _warm_up_web_frames() -> void:
	var frame_count := 5 if OS.has_feature("web") else 1
	for _frame: int in range(frame_count):
		await get_tree().process_frame


func _finish_or_pause() -> void:
	if OS.has_feature("web"):
		get_tree().paused = true
	else:
		call_deferred("_finish_headless")


func _finish_headless() -> void:
	get_tree().paused = false
	HitStopManager.set_process(true)
	HitStopManager.restore()
	if _session != null and is_instance_valid(_session):
		remove_child(_session)
		_session.free()
		_session = null
	PoolManager.clear_all()
	AudioManager.reset()
	GameManager.reset_session()
	get_tree().quit()


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_general_hit_stop_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-general-hit-stop-mode="):
			return argument.trim_prefix("--uat-general-hit-stop-mode=")
	return "normal_active"
