extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")
const SETTINGS_UI_SCENE := preload("res://scenes/ui/settings_ui.tscn")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _mode := "damage"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	Settings.reset_defaults()
	GameManager.reset_session()
	GameManager.start_session({"source": "damage_vignette_web_fixture", SceneTransition.RUN_CONFIG_LAYOUT_SEED: 524})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var player := session.get_node("%Player")
	var vignette := session.get_node("%DamageVignette") as DamageVignette

	match _mode:
		"healthy":
			_emit_vignette_marker(vignette)
		"damage":
			player.call("take_damage", 2)
			_freeze_pulse_for_capture(vignette)
			_emit_vignette_marker(vignette)
		"critical":
			player.call("take_damage", 4)
			_freeze_pulse_for_capture(vignette)
			_emit_vignette_marker(vignette)
		"fade_mid":
			_run_fade_mid(player, vignette)
		"healed":
			_run_healed(player, vignette)
		"max_health_reset":
			_run_max_health_reset(player, vignette)
		"disabled":
			player.call("take_damage", 4)
			Settings.set_screen_effects_enabled(false)
			_emit_vignette_marker(vignette)
		"reenabled":
			player.call("take_damage", 4)
			Settings.set_screen_effects_enabled(false)
			Settings.set_screen_effects_enabled(true)
			_emit_vignette_marker(vignette)
		"pause_after":
			_run_pause_after(player, vignette)
		"scene_exit":
			_run_scene_exit(session, vignette)
		"settings":
			var settings_ui := SETTINGS_UI_SCENE.instantiate() as SettingsUI
			add_child(settings_ui)
			settings_ui.open()
			_run_settings(settings_ui)
		_:
			push_error("Unknown damage vignette UAT mode: %s" % _mode)


func _run_healed(player: Node, vignette: DamageVignette) -> void:
	player.call("take_damage", 4)
	player.set("_health", 4)
	player.call("_broadcast_health")
	await get_tree().create_timer(0.5, true, false, true).timeout
	_emit_vignette_marker(vignette)


func _run_fade_mid(player: Node, vignette: DamageVignette) -> void:
	var warmup_frames := 5 if OS.has_feature("web") else 1
	for _frame: int in range(warmup_frames):
		await get_tree().process_frame
	player.call("take_damage", 2)
	if DisplayServer.get_name() == "headless":
		vignette.call("_advance_damage_pulse", 0.21)
	else:
		await get_tree().create_timer(0.21, true, false, true).timeout
		await get_tree().process_frame
	_freeze_pulse_for_capture(vignette)
	_emit_vignette_marker(vignette)


func _run_max_health_reset(player: Node, vignette: DamageVignette) -> void:
	player.set("max_health", 6)
	player.set("_health", 6)
	player.call("_broadcast_health")
	player.set("max_health", 5)
	player.set("_health", 5)
	player.call("_broadcast_health")
	_emit_vignette_marker(vignette)


func _run_pause_after(player: Node, vignette: DamageVignette) -> void:
	if OS.has_feature("web"):
		for _frame: int in range(5):
			await get_tree().process_frame
	player.call("take_damage", 2)
	get_tree().paused = true
	if DisplayServer.get_name() == "headless":
		vignette.call("_advance_damage_pulse", 0.55)
	else:
		await get_tree().create_timer(0.55, true, false, true).timeout
		await get_tree().process_frame
	_emit_vignette_marker(vignette)


func _run_scene_exit(session: Node, vignette: DamageVignette) -> void:
	var health_callback := Callable(vignette, "_on_player_health_changed")
	var settings_callback := Callable(vignette, "_on_settings_changed")
	remove_child(session)
	session.free()
	var health_connected := EventBus.player_health_changed.is_connected(health_callback)
	var settings_connected := EventBus.settings_changed.is_connected(settings_callback)
	var valid := not health_connected and not settings_connected
	if not valid:
		push_error("Damage vignette scene-exit UAT left signal connections")
	print(
		"UAT_DAMAGE_VIGNETTE_READY mode=scene_exit health_connected=%s settings_connected=%s valid=%s"
		% [str(health_connected).to_lower(), str(settings_connected).to_lower(), str(valid).to_lower()]
	)
	_finish_or_pause()


func _run_settings(settings_ui: SettingsUI) -> void:
	await get_tree().process_frame
	_emit_settings_marker(settings_ui)


func _emit_vignette_marker(vignette: DamageVignette) -> void:
	var snapshot := vignette.get_snapshot()
	var valid := false
	match _mode:
		"healthy":
			valid = not snapshot["damage_pulse_active"] and not snapshot["low_health_visible"]
		"damage":
			valid = snapshot["damage_pulse_active"] and not snapshot["low_health_visible"] and snapshot["pulse_alpha"] > 0.0
		"critical":
			valid = snapshot["damage_pulse_active"] and snapshot["low_health_visible"] and snapshot["pulse_alpha"] > 0.0
		"fade_mid":
			valid = snapshot["damage_pulse_active"] and snapshot["pulse_alpha"] > 0.05 and snapshot["pulse_alpha"] < 0.95
		"healed":
			valid = not snapshot["damage_pulse_active"] and not snapshot["low_health_visible"] and snapshot["current_health"] == 4
		"max_health_reset":
			valid = not snapshot["damage_pulse_active"] and not snapshot["low_health_visible"] and snapshot["current_health"] == 5 and snapshot["max_health"] == 5
		"disabled":
			valid = not snapshot["screen_effects_enabled"] and not snapshot["damage_pulse_active"] and not snapshot["low_health_visible"] and snapshot["pulse_alpha"] == 0.0
		"reenabled":
			valid = snapshot["screen_effects_enabled"] and not snapshot["damage_pulse_active"] and snapshot["low_health_visible"]
		"pause_after":
			valid = get_tree().paused and not snapshot["damage_pulse_active"] and snapshot["pulse_alpha"] == 0.0
	if not valid:
		push_error("Damage vignette UAT mismatch: mode=%s snapshot=%s" % [_mode, snapshot])
	print(
		"UAT_DAMAGE_VIGNETTE_READY mode=%s current=%d max=%d pulse=%s low=%s enabled=%s pulse_alpha=%.3f layer=%d mouse_filter=%d paused=%s valid=%s"
		% [
			_mode,
			int(snapshot["current_health"]),
			int(snapshot["max_health"]),
			str(snapshot["damage_pulse_active"]).to_lower(),
			str(snapshot["low_health_visible"]).to_lower(),
			str(snapshot["screen_effects_enabled"]).to_lower(),
			float(snapshot["pulse_alpha"]),
			int(snapshot["layer"]),
			int(snapshot["mouse_filter"]),
			str(get_tree().paused).to_lower(),
			str(valid).to_lower(),
		]
	)
	_finish_or_pause()


func _emit_settings_marker(settings_ui: SettingsUI) -> void:
	var screen_toggle: Node = _find_by_test_id(settings_ui, SettingsUI.TEST_ID_SCREEN_EFFECTS_TOGGLE)
	var panel := settings_ui.get_node("Root/Panel") as Control
	var panel_rect := panel.get_global_rect()
	var actual_safe := MobileSafeArea.meets_landscape_minimum(panel_rect) if OS.has_feature("web") else true
	var valid := (
		screen_toggle != null
		and settings_ui.get_toggle_text(Settings.KEY_SCREEN_EFFECTS) == "ON"
		and panel.offset_top == -246.0
		and panel.offset_bottom == 236.0
		and actual_safe
	)
	if not valid:
		push_error("Damage vignette settings UAT mismatch")
	print(
		"UAT_DAMAGE_VIGNETTE_READY mode=settings toggle=%s text=%s panel_top=%.1f panel_bottom=%.1f global_rect=%s actual_safe=%s valid=%s"
		% [str(screen_toggle != null).to_lower(), settings_ui.get_toggle_text(Settings.KEY_SCREEN_EFFECTS), panel.offset_top, panel.offset_bottom, str(panel_rect), str(actual_safe).to_lower(), str(valid).to_lower()]
	)
	_finish_or_pause()


func _freeze_pulse_for_capture(vignette: DamageVignette) -> void:
	vignette.set_process(false)


func _find_by_test_id(root: Node, test_id: String) -> Node:
	if String(root.get_meta("test_id", "")) == test_id:
		return root
	for child: Node in root.get_children():
		var found := _find_by_test_id(child, test_id)
		if found != null:
			return found
	return null


func _finish_or_pause() -> void:
	if OS.has_feature("web"):
		get_tree().paused = true
	else:
		call_deferred("_finish_headless")


func _finish_headless() -> void:
	get_tree().paused = false
	for child: Node in get_children():
		remove_child(child)
		child.free()
	PoolManager.clear_all()
	HitStopManager.restore()
	GameManager.reset_session()
	Settings.reset_defaults()
	get_tree().quit()


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_damage_vignette_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-damage-vignette-mode="):
			return argument.trim_prefix("--uat-damage-vignette-mode=")
	return "damage"
