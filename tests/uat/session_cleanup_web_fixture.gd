extends Node

const SESSION_SCENE := preload("res://scenes/session/session_root.tscn")

var _mode := "portal_blocked"


func _ready() -> void:
	_mode = _read_mode()
	call_deferred("_setup")


func _setup() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	HitStopManager.set_process(true)
	HitStopManager.restore()
	PoolManager.clear_all()
	GameManager.reset_session()
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	match _mode:
		"portal_blocked", "portal_retry":
			_setup_portal_mode()
		"death_before", "death_after", "next_session":
			_setup_death_mode()
		_:
			push_error("Unknown session cleanup UAT mode: %s" % _mode)


func _setup_portal_mode() -> void:
	GameManager.start_session({"source": "portal_retry_web_fixture", SceneTransition.RUN_CONFIG_LAYOUT_SEED: 516})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	var manager := session.get_node("%RoomManager") as RoomManager
	var actor := session.get_node("%Player") as Node2D
	var doors: Array = manager.current_room.call("get_doors")
	var door := doors[0] as RoomDoor if not doors.is_empty() else null
	if door == null:
		push_error("Portal retry fixture has no start-room door")
		return
	var request_count := [0]
	door.transition_requested.connect(func(_door_dir: StringName) -> void: request_count[0] += 1)
	door.open()
	door.configure_actor(actor)
	actor.global_position = door.global_position
	get_tree().paused = true
	var first_transition := door.check_transition_for_actor(actor)
	if _mode == "portal_blocked":
		_emit_portal_marker(first_transition, false, request_count[0], manager.current_room_id)
		return
	get_tree().paused = false
	var retried := door.check_transition_for_actor(actor)
	_emit_portal_marker(first_transition, retried, request_count[0], manager.current_room_id)


func _setup_death_mode() -> void:
	GameManager.start_session({
		"source": "onboarding_death_web_fixture",
		SceneTransition.RUN_CONFIG_LAYOUT_SEED: 516,
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var session := SESSION_SCENE.instantiate()
	add_child(session)
	_arm_cleanup_surfaces(session)
	if _mode == "death_before":
		_freeze_feedback(session)
		_emit_death_marker(session)
		return
	(session.get_node("%DeathReturnController") as DeathReturnController).trigger_death_return()
	if _mode == "death_after":
		_emit_death_marker(session)
		return
	get_tree().paused = false
	remove_child(session)
	session.free()
	GameManager.reset_session()
	GameManager.start_session({"source": "cleanup_replacement_web_fixture", SceneTransition.RUN_CONFIG_LAYOUT_SEED: 517})
	var next_session := SESSION_SCENE.instantiate()
	add_child(next_session)
	var clean := (
		PoolManager.get_available_count(&"floating_combat_text") == 20
		and PoolManager.get_active_count(&"floating_combat_text") == 0
		and is_equal_approx(Engine.time_scale, 1.0)
		and (next_session.get_node("%PlayerCamera") as Camera2D).offset == Vector2.ZERO
	)
	if not clean:
		push_error("Replacement session inherited cleanup state")
	print(
		"UAT_SESSION_CLEANUP_READY mode=next_session pool_available=%d text_count=%d time_scale=%.2f camera_offset=%s clean=%s"
		% [
			PoolManager.get_available_count(&"floating_combat_text"),
			PoolManager.get_active_count(&"floating_combat_text"),
			Engine.time_scale,
			str((next_session.get_node("%PlayerCamera") as Camera2D).offset),
			str(clean).to_lower(),
		]
	)


func _arm_cleanup_surfaces(session: Node) -> void:
	var camera := session.get_node("%PlayerCamera") as Camera2D
	var touch_controls := session.get_node("%TouchControls") as CanvasLayer
	var control_onboarding := session.get_node("%IngameControlOnboarding") as CanvasLayer
	var purify_spotlight := session.get_node("%PurifyOnboardingSpotlight") as PurifyOnboardingSpotlight
	var parry_hint := session.get_node("%ParryOnboarding") as ParryOnboarding
	var parry_feedback := session.get_node("%ParryFeedbackController") as ParryFeedbackController
	var session_ui := session.get_node("%SessionUIRoot") as CanvasLayer
	control_onboarding.call("start")
	var purify_target := Node2D.new()
	purify_target.global_position = Vector2(520.0, 280.0)
	session.add_child(purify_target)
	session.set("_purify_onboarding_active", true)
	session.set("_paused_before_purify_onboarding", false)
	session.set("_touch_controls_visible_before_purify_onboarding", touch_controls.visible)
	purify_spotlight.show_step(&"cleanup", "기절시킨 뒤 가까이 다가가 정화", purify_target)
	var parry_target := Node2D.new()
	parry_target.global_position = Vector2(620.0, 280.0)
	session.add_child(parry_target)
	parry_hint.show_for_wolf(parry_target, &"desktop")
	parry_feedback.present({
		"player_position": Vector2(470.0, 300.0),
		"enemy_position": Vector2(520.0, 300.0),
		"direction": Vector2.RIGHT,
	})
	session_ui.call("set_onboarding_journey_hint", "첫 전투", "정리 전", true)
	camera.make_current()
	get_tree().paused = true


func _freeze_feedback(session: Node) -> void:
	HitStopManager.set_process(false)
	var controller := session.get_node("%ParryFeedbackController") as ParryFeedbackController
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


func _emit_portal_marker(first_transition: bool, retried: bool, request_count: int, room_id: StringName) -> void:
	var valid: bool = not first_transition and (not retried if _mode == "portal_blocked" else retried and request_count == 1)
	if not valid:
		push_error("Portal retry state mismatch")
	print(
		"UAT_SESSION_CLEANUP_READY mode=%s first_transition=%s retried=%s request_count=%d room_id=%s paused=%s valid=%s"
		% [
			_mode,
			str(first_transition).to_lower(),
			str(retried).to_lower(),
			request_count,
			String(room_id),
			str(get_tree().paused).to_lower(),
			str(valid).to_lower(),
		]
	)


func _emit_death_marker(session: Node) -> void:
	var before := _mode == "death_before"
	var control := session.get_node("%IngameControlOnboarding") as CanvasLayer
	var purify := session.get_node("%PurifyOnboardingSpotlight") as PurifyOnboardingSpotlight
	var parry := session.get_node("%ParryOnboarding") as ParryOnboarding
	var feedback := session.get_node("%ParryFeedbackController") as ParryFeedbackController
	var session_ui := session.get_node("%SessionUIRoot") as CanvasLayer
	var camera := session.get_node("%PlayerCamera") as Camera2D
	var result := GameManager.get_last_result()
	var valid: bool = (
		bool(control.call("is_active")) == before
		and purify.is_active() == before
		and parry.is_active() == before
		and bool(feedback.get_flash_snapshot().get("visible")) == before
		and PoolManager.has_pool(&"floating_combat_text") == before
		and HitStopManager.is_active() == before
		and (before or camera.zoom == Vector2.ONE)
		and (before or camera.offset == Vector2.ZERO)
		and (before or bool(session_ui.call("is_summary_visible")))
		and (before or result.get("onboarding_kind", &"") == SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN)
	)
	if not valid:
		push_error("Onboarding death cleanup state mismatch")
	print(
		"UAT_SESSION_CLEANUP_READY mode=%s control=%s purify=%s parry=%s flash=%s pool=%s time_scale=%.2f zoom=%s camera_offset=%s paused=%s summary=%s onboarding_kind=%s valid=%s"
		% [
			_mode,
			str(control.call("is_active")).to_lower(),
			str(purify.is_active()).to_lower(),
			str(parry.is_active()).to_lower(),
			str(feedback.get_flash_snapshot().get("visible")).to_lower(),
			str(PoolManager.has_pool(&"floating_combat_text")).to_lower(),
			Engine.time_scale,
			str(camera.zoom),
			str(camera.offset),
			str(get_tree().paused).to_lower(),
			str(session_ui.call("is_summary_visible")).to_lower(),
			String(result.get("onboarding_kind", &"")),
			str(valid).to_lower(),
		]
	)


func _read_mode() -> String:
	if OS.has_feature("web") and JavaScriptBridge != null:
		var window := JavaScriptBridge.get_interface("window")
		if window != null:
			var search := String(window.location.search)
			for part: String in search.trim_prefix("?").split("&", false):
				var pair := part.split("=", true, 1)
				if pair.size() == 2 and pair[0] == "uat_session_cleanup_mode":
					return pair[1]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--uat-session-cleanup-mode="):
			return argument.trim_prefix("--uat-session-cleanup-mode=")
	return "portal_blocked"
