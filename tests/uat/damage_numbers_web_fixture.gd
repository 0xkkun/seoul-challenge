extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")
const WOLF_SCENE := preload("res://scenes/enemies/wolf.tscn")
const SETTINGS_UI_SCENE := preload("res://scenes/ui/settings_ui.tscn")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const TEXT_POOL_ID := &"floating_combat_text"

var _mode := "ordinary"
var _session: Node = null
var _actor: Node2D = null
var _enemy: Node2D = null
var _ordering := {"observed": false, "text_ready": false, "hit_stop_inactive": false}
var _reused_same_instance := false
var _settings_scroll_valid := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	HitStopManager.set_process(true)
	HitStopManager.restore()
	Settings.reset_defaults()
	AudioManager.reset()
	PoolManager.clear_all()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)
	GameManager.start_session({
		"source": "damage_numbers_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 528,
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
	_actor.connect(&"combat_text_requested", _observe_text_before_hit_stop)
	_run_mode()


func _run_mode() -> void:
	await _warm_up_web_frames()
	AudioManager.reset()
	match _mode:
		"ordinary":
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_feedback()
			_emit_marker()
		"power":
			_actor.call("try_start_special_skill", Vector2.RIGHT)
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_feedback()
			_emit_marker()
		"player_damage":
			_actor.call("take_damage", 2)
			_freeze_active_feedback()
			_emit_marker()
		"cap":
			for index: int in range(21):
				_session.call("spawn_combat_text", Vector2(80.0 + index * 12.0, 100.0 + (index % 4) * 18.0), str(index), &"ordinary")
			_freeze_text_lifetimes()
			_emit_marker()
		"reuse":
			for index: int in range(20):
				_session.call("spawn_combat_text", Vector2(float(index), 0.0), str(index), &"ordinary")
			var first := ((PoolManager.get("_active") as Dictionary).get(TEXT_POOL_ID, []) as Array)[0] as Node
			first.call("_on_lifetime_finished", int(first.get("_activation_generation")))
			_session.call("spawn_combat_text", Vector2.ONE, "reused", &"power")
			_reused_same_instance = ((PoolManager.get("_active") as Dictionary).get(TEXT_POOL_ID, []) as Array).has(first)
			_freeze_text_lifetimes()
			_emit_marker()
		"disabled":
			Settings.set_damage_numbers_enabled(false)
			_actor.call("_attack_melee", Vector2.RIGHT)
			_freeze_active_feedback()
			_emit_marker()
		"rejected":
			_enemy.call("take_damage", 1)
			AudioManager.reset()
			_actor.call("_attack_melee", Vector2.RIGHT)
			_emit_marker()
		"settings":
			var settings_ui := SETTINGS_UI_SCENE.instantiate() as SettingsUI
			add_child(settings_ui)
			_run_settings(settings_ui)
		_:
			push_error("Unknown damage-numbers UAT mode: %s" % _mode)
			_finish_or_pause()


func _observe_text_before_hit_stop(_position: Vector2, _text: String, style: StringName) -> void:
	if style != &"ordinary" or _ordering["observed"]:
		return
	_ordering["observed"] = true
	_ordering["text_ready"] = PoolManager.get_active_count(TEXT_POOL_ID) == 1
	_ordering["hit_stop_inactive"] = not HitStopManager.is_active()


func _emit_marker() -> void:
	var snapshots := _active_text_snapshots()
	var active_count := PoolManager.get_active_count(TEXT_POOL_ID)
	var available_count := PoolManager.get_available_count(TEXT_POOL_ID)
	var valid := false
	var player_text_screen_position := Vector2.ZERO
	match _mode:
		"ordinary":
			valid = active_count == 1 and _has_text(snapshots, "2", &"ordinary") and bool(_ordering["text_ready"]) and bool(_ordering["hit_stop_inactive"]) and HitStopManager.is_active() and is_equal_approx(HitStopManager.get_active_scale(), 0.15)
		"power":
			valid = active_count == 1 and _has_text(snapshots, "3", &"power") and HitStopManager.is_active() and is_equal_approx(HitStopManager.get_active_scale(), 0.08)
		"player_damage":
			player_text_screen_position = _player_text_screen_position()
			var health_panel := _session.get_node("%CombatHud").get_node("Root/HealthPanel") as Control
			var expected_position := Vector2(health_panel.get_global_rect().end.x + 24.0, health_panel.get_global_rect().get_center().y)
			valid = active_count == 1 and _has_text(snapshots, "2", &"player_damage") and player_text_screen_position.distance_to(expected_position) < 1.0 and HitStopManager.is_active() and is_equal_approx(HitStopManager.get_active_scale(), 0.10) and bool((_session.get_node("%DamageVignette") as DamageVignette).get_snapshot().get("damage_pulse_active", false))
		"cap":
			valid = active_count == 20 and available_count == 0
		"reuse":
			valid = active_count == 20 and available_count == 0 and _reused_same_instance and _has_text(snapshots, "reused", &"power")
		"disabled":
			valid = active_count == 0 and available_count == 20 and HitStopManager.is_active() and AudioManager.get_played_sfx() == [&"bat_swing", &"enemy_hit", &"bat_hit"]
		"rejected":
			valid = active_count == 0 and not HitStopManager.is_active() and AudioManager.get_played_sfx() == [&"bat_swing"]
	if not valid:
		push_error("Damage-numbers UAT mismatch: mode=%s active=%d available=%d snapshots=%s ordering=%s player_screen=%s hit_stop=%s scale=%.2f" % [_mode, active_count, available_count, snapshots, _ordering, player_text_screen_position, HitStopManager.is_active(), HitStopManager.get_active_scale()])
	print(
		"UAT_DAMAGE_NUMBERS_READY mode=%s active=%d available=%d snapshots=%s text_before_hit_stop=%s player_screen=%s hit_stop=%s scale=%.2f valid=%s"
		% [_mode, active_count, available_count, snapshots, str(bool(_ordering["text_ready"]) and bool(_ordering["hit_stop_inactive"])).to_lower(), player_text_screen_position, str(HitStopManager.is_active()).to_lower(), HitStopManager.get_active_scale(), str(valid).to_lower()]
	)
	_finish_or_pause()


func _run_settings(settings_ui: SettingsUI) -> void:
	settings_ui.open()
	if OS.has_feature("web"):
		await get_tree().create_timer(0.20, true, false, true).timeout
	await get_tree().process_frame
	var rows_scroll := settings_ui.get_node("Root/Panel/Margin/Stack/RowsScroll") as ScrollContainer
	var screen_toggle := _find_by_test_id(settings_ui, SettingsUI.TEST_ID_SCREEN_EFFECTS_TOGGLE) as Control
	var scroll_bar := rows_scroll.get_v_scroll_bar()
	var max_scroll := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	rows_scroll.scroll_vertical = int(ceil(max_scroll))
	await get_tree().process_frame
	_settings_scroll_valid = max_scroll > 0.0 and screen_toggle != null and rows_scroll.get_global_rect().has_point(screen_toggle.get_global_rect().get_center())
	rows_scroll.scroll_vertical = 0
	await get_tree().process_frame
	_emit_settings_marker(settings_ui)


func _emit_settings_marker(settings_ui: SettingsUI) -> void:
	var toggle := _find_by_test_id(settings_ui, SettingsUI.TEST_ID_DAMAGE_NUMBERS_TOGGLE)
	var panel := settings_ui.get_node("Root/Panel") as Control
	var panel_rect := panel.get_global_rect()
	var safe := MobileSafeArea.meets_landscape_minimum(panel_rect) if OS.has_feature("web") else true
	var content_fits := panel.get_combined_minimum_size().y <= panel.size.y and panel.size.y <= 482.0
	var valid := toggle != null and settings_ui.get_toggle_text(Settings.KEY_DAMAGE_NUMBERS) == "ON" and safe and content_fits and _settings_scroll_valid
	if not valid:
		push_error("Damage-numbers settings UAT mismatch: toggle=%s rect=%s safe=%s content_fits=%s minimum=%s size=%s" % [toggle != null, panel_rect, safe, content_fits, panel.get_combined_minimum_size(), panel.size])
	print("UAT_DAMAGE_NUMBERS_READY mode=settings toggle=%s text=%s rect=%s safe=%s content_fits=%s scroll_reaches_bottom=%s minimum=%s size=%s valid=%s" % [str(toggle != null).to_lower(), settings_ui.get_toggle_text(Settings.KEY_DAMAGE_NUMBERS), panel_rect, str(safe).to_lower(), str(content_fits).to_lower(), str(_settings_scroll_valid).to_lower(), panel.get_combined_minimum_size(), panel.size, str(valid).to_lower()])
	_finish_or_pause()


func _active_text_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for text_node: Node in (PoolManager.get("_active") as Dictionary).get(TEXT_POOL_ID, []):
		result.append(text_node.call("get_snapshot") as Dictionary)
	return result


func _has_text(snapshots: Array[Dictionary], text: String, style: StringName) -> bool:
	for snapshot: Dictionary in snapshots:
		if snapshot.get("text", "") == text and snapshot.get("style", &"") == style:
			return true
	return false


func _player_text_screen_position() -> Vector2:
	var active_nodes: Array = (PoolManager.get("_active") as Dictionary).get(TEXT_POOL_ID, [])
	if active_nodes.is_empty():
		return Vector2.ZERO
	return get_viewport().get_canvas_transform() * (active_nodes[0] as Node2D).global_position


func _freeze_active_feedback() -> void:
	HitStopManager.set_process(false)
	(_session.get_node("%DamageVignette") as DamageVignette).set_process(false)
	_freeze_text_lifetimes()


func _freeze_text_lifetimes() -> void:
	for text_node: Node in (PoolManager.get("_active") as Dictionary).get(TEXT_POOL_ID, []):
		var lifetime_tween := text_node.get("_lifetime_tween") as Tween
		if lifetime_tween != null and lifetime_tween.is_valid():
			lifetime_tween.kill()
		text_node.set("_lifetime_tween", null)


func _find_by_test_id(root: Node, test_id: String) -> Node:
	if String(root.get_meta("test_id", "")) == test_id:
		return root
	for child: Node in root.get_children():
		var found := _find_by_test_id(child, test_id)
		if found != null:
			return found
	return null


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
	Settings.reset_defaults()
	GameManager.reset_session()
	get_tree().quit()


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_damage_numbers_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-damage-numbers-mode="):
			return argument.trim_prefix("--uat-damage-numbers-mode=")
	return "ordinary"
