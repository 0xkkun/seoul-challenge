extends Node2D

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const POOLED_MARKER_SCENE = preload("res://scenes/interactables/sample_pooled_marker.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const MapItemCatalog = preload("res://scripts/items/map_item_catalog.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")

const RUN_LAYOUT_SEED_MAX := 2147483647
const RUN_LAYOUT_ROOM_COUNT := 15
const START_ROOM_SCENE_PATH := "res://scenes/interactables/start_room.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"
const EVENT_ROOM_SCENE_PATH := "res://scenes/interactables/rescue_room.tscn"
const TREASURE_ROOM_SCENE_PATH := "res://scenes/interactables/treasure_room.tscn"
const FRIEND_ROOM_SCENE_PATH := "res://scenes/interactables/friend_room.tscn"
const FINAL_ROOM_SCENE_PATH := "res://scenes/interactables/boss_room.tscn"
const DEFAULT_STAGE_NAME := "경복궁"
const PAUSE_MENU_MESSAGE := "일시정지"
const ABANDON_RUN_MESSAGE := "오늘 밤을 포기할까요? 이번 밤에 얻은 보상은 사라지지만 혼 조각은 남습니다"
const QUIT_GAME_MESSAGE := "게임을 종료할까요?"
const LEGACY_REMOVED_WEAPON_ID := &"baseball"
const WEAPON_BAT := &"bat"
const COMBAT_FEEDBACK_RECOVER_TIME := 0.10
const COMBAT_FEEDBACK_MAX_OFFSET := 7.0
const ROOM_ENTRY_SPAWN_INSET := Vector2(140.0, 96.0)
const TOP_LEFT_HUD_GAP := 8.0
const BASEBALL_ONBOARDING_LAYOUT_ID := &"onboarding_baseball_captain"
const REWARD_CHOICE_DELAY_SECONDS := 1.0

@onready var world_layer: Node2D = $WorldLayer
@onready var room_layer: Node2D = %RoomLayer
@onready var actor: Node2D = %Player
@onready var actor_layer: Node2D = $ActorLayer
@onready var interactable_layer: Node2D = %InteractableLayer
@onready var sample_interactable: Node = %SampleInteractable
@onready var pooled_object_layer: Node2D = %PooledObjectLayer
@onready var interaction_system: Node = %InteractionSystem
@onready var room_manager: RoomManager = %RoomManager
@onready var death_return_controller: DeathReturnController = %DeathReturnController
@onready var touch_controls: Node = %TouchControls
@onready var combat_hud: CanvasLayer = %CombatHud
@onready var session_ui_root: CanvasLayer = %SessionUIRoot
@onready var player_camera: Camera2D = %PlayerCamera
@onready var _fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var _minimap: Control = $MinimapLayer/Minimap
@onready var _confirm_modal: ConfirmModal = %ConfirmModal

var completed_interactions := 0
var return_to_school_callable: Callable
var retry_session_callable: Callable
var quit_game_callable: Callable
var _handoff_session_on_exit := false
var _active_boss: Node = null
var _minimap_full := false
var _paused_before_exit_modal := false
var _friend_ids: Array[StringName] = []
var _unlocks: Array[StringName] = []
var _camera_feedback_tween: Tween = null
var _rewarded_room_ids := {}
var _room_clear_modifier_room_ids := {}
var _pending_reward_room_id: StringName = &""
var _paused_before_reward_choice := false
var _pause_modal_open := false
var _reward_choice_delay_timer: Timer = null
var _touch_controls_visible_before_reward_choice := true


func _ready() -> void:
	SceneTransition.configure_exit_requests()
	_apply_render_layers()
	if not GameManager.is_session_active():
		GameManager.start_session({"source": "session_root"})
	AudioManager.play_bgm(AudioManager.NIGHT_RUN_SUSPENSE_BGM)
	_apply_session_loadout()
	_connect_player_weapon_events()
	_sync_combat_hud_health()
	PoolManager.register_scene(&"sample_marker", POOLED_MARKER_SCENE, 1, pooled_object_layer)
	interaction_system.configure(actor, self)
	_configure_player_camera()
	death_return_controller.death_result_builder_callable = Callable(self, "_build_death_result")
	death_return_controller.game_over_callable = Callable(self, "_show_death_summary")
	_connect_progression_events()
	_connect_combat_feedback_events()
	_connect_run_reward_events()
	room_manager.room_changed.connect(_on_room_changed)
	room_manager.configure(_build_run_layout(), room_layer, actor)
	room_manager.transition_blocked_callable = Callable(self, "_is_room_transition_blocked_by_reward")
	room_manager.start_layout()
	_minimap.configure_from_manager(room_manager)
	_apply_landscape_safe_area()
	session_ui_root.set_map_name(_resolve_stage_name())
	sample_interactable.interaction_triggered.connect(_on_interaction_triggered)
	session_ui_root.pause_requested.connect(_on_pause_requested)
	session_ui_root.resume_requested.connect(_on_resume_requested)
	session_ui_root.finish_requested.connect(_on_finish_requested)
	session_ui_root.return_requested.connect(_on_return_requested)
	session_ui_root.retry_requested.connect(_on_retry_requested)


func _apply_render_layers() -> void:
	world_layer.z_index = RenderLayers.WORLD_BACKGROUND_Z
	room_layer.z_index = RenderLayers.WORLD_BACKGROUND_Z
	actor_layer.z_index = RenderLayers.WORLD_ACTOR_Z
	interactable_layer.z_index = RenderLayers.WORLD_INTERACTABLE_Z
	pooled_object_layer.z_index = RenderLayers.WORLD_EFFECT_Z


func _apply_landscape_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	MobileSafeArea.apply_edge_offsets(_minimap, -1.0, float(insets["top"]), float(insets["right"]), -1.0)
	_keep_combat_health_below_map_tab()


func _keep_combat_health_below_map_tab() -> void:
	var health_panel := combat_hud.get_node_or_null("Root/HealthPanel") as Control
	var map_tab := session_ui_root.get_node_or_null("%MapTabButton") as Control
	if health_panel == null or map_tab == null:
		return
	var health_height := health_panel.offset_bottom - health_panel.offset_top
	var target_top := map_tab.get_global_rect().end.y + TOP_LEFT_HUD_GAP
	if health_panel.get_global_rect().position.y >= target_top:
		return
	health_panel.offset_top = target_top
	health_panel.offset_bottom = target_top + health_height


func _exit_tree() -> void:
	_cancel_reward_choice_delay()
	if room_manager != null:
		room_manager.transition_blocked_callable = Callable()
	_disconnect_progression_events()
	_disconnect_combat_feedback_events()
	_disconnect_run_reward_events()
	_disconnect_player_weapon_events()
	if has_node("/root/PoolManager"):
		PoolManager.clear_all()
	if not _handoff_session_on_exit and has_node("/root/GameManager") and GameManager.is_session_active():
		GameManager.reset_session()


func trigger_sample_interaction() -> int:
	return interaction_system.check_now(0.016)


func spawn_sample_marker() -> Node:
	var marker := PoolManager.acquire(&"sample_marker", pooled_object_layer)
	if marker != null and marker.has_method("activate_at"):
		marker.call("activate_at", actor.global_position + Vector2(24, 0))
	return marker


func advance_room(preferred_room_id: StringName = &"") -> bool:
	return room_manager.request_next_room(preferred_room_id)


func _build_run_layout() -> RoomLayout:
	if _is_baseball_onboarding_run():
		return _build_baseball_onboarding_layout()
	var generator := RoomLayoutGenerator.new()
	generator.start_scene_path = START_ROOM_SCENE_PATH
	generator.combat_scene_path = COMBAT_ROOM_SCENE_PATH
	generator.event_scene_path = EVENT_ROOM_SCENE_PATH
	generator.treasure_scene_path = TREASURE_ROOM_SCENE_PATH
	generator.friend_scene_path = FRIEND_ROOM_SCENE_PATH
	generator.final_scene_path = FINAL_ROOM_SCENE_PATH
	return generator.generate(_resolve_run_layout_seed(), {"room_count": RUN_LAYOUT_ROOM_COUNT})


func _build_baseball_onboarding_layout() -> RoomLayout:
	var layout := RoomLayout.new()
	layout.layout_id = BASEBALL_ONBOARDING_LAYOUT_ID
	layout.start_room_id = &"start"
	layout.allow_short_story_layout = true
	layout.required_clears_for_hidden_reveal = 0
	layout.room_defs = [
		_make_room_def(&"start", RoomLayout.TYPE_START, START_ROOM_SCENE_PATH, [&"combat_1"], Vector2i.ZERO),
		_make_room_def(
			&"combat_1",
			RoomLayout.TYPE_COMBAT,
			COMBAT_ROOM_SCENE_PATH,
			[&"start", &"friend_1"],
			Vector2i(1, 0),
			{
				"chaser_count": 1,
				"ranged_count": 0,
				"wolf_count": 0,
				"elite_chaser_count": 0,
				"elite_ranged_count": 0,
				"elite_wolf_count": 0,
				"wave_count": 1,
			}
		),
		_make_room_def(
			&"friend_1",
			RoomLayout.TYPE_FRIEND,
			FRIEND_ROOM_SCENE_PATH,
			[&"combat_1"],
			Vector2i(2, 0),
			{"friend_id": &"baseball_captain"}
		),
	]
	return layout


func _make_room_def(
	room_id: StringName,
	room_type: StringName,
	scene_path: String,
	connections: Array,
	grid_pos: Vector2i,
	room_config: Dictionary = {}
) -> RoomDef:
	var room_def := RoomDef.new()
	var typed_connections: Array[StringName] = []
	for connection: Variant in connections:
		typed_connections.append(StringName(connection))
	room_def.room_id = room_id
	room_def.room_type = room_type
	room_def.scene_path = scene_path
	room_def.connections = typed_connections
	room_def.grid_pos = grid_pos
	room_def.room_config = room_config.duplicate(true)
	return room_def


func _is_baseball_onboarding_run() -> bool:
	var config := GameManager.get_active_config()
	return StringName(config.get(SceneTransition.RUN_CONFIG_ONBOARDING_KIND, &"")) == SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN


func _resolve_run_layout_seed() -> int:
	var config := GameManager.get_active_config()
	if config.has(SceneTransition.RUN_CONFIG_LAYOUT_SEED):
		return int(config.get(SceneTransition.RUN_CONFIG_LAYOUT_SEED, 0))
	return _random_run_layout_seed()


func _random_run_layout_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mixed_seed := int((int(rng.randi()) + Time.get_ticks_usec() + get_instance_id()) % RUN_LAYOUT_SEED_MAX)
	if mixed_seed <= 0:
		mixed_seed += RUN_LAYOUT_SEED_MAX
	return mixed_seed


func _resolve_stage_name() -> String:
	var config := GameManager.get_active_config()
	var stage_name := String(config.get("stage_name", DEFAULT_STAGE_NAME)).strip_edges()
	return stage_name if stage_name != "" else DEFAULT_STAGE_NAME


func _apply_session_loadout() -> void:
	var config := GameManager.get_active_config()
	if not config.has(SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID):
		return
	var weapon_id := StringName(config.get(SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID, &""))
	match weapon_id:
		WEAPON_BAT, LEGACY_REMOVED_WEAPON_ID:
			_equip_story_bat()


func _equip_story_bat() -> void:
	actor.set("ranged_enabled", false)
	if actor.has_method("equip_bat"):
		actor.call("equip_bat")


func _connect_player_weapon_events() -> void:
	if actor == null or not actor.has_signal("weapon_changed"):
		return
	var callback := Callable(self, "_on_actor_weapon_changed")
	if not actor.is_connected("weapon_changed", callback):
		actor.connect("weapon_changed", callback)
	if actor.has_method("has_bat") and bool(actor.call("has_bat")) and combat_hud.has_method("set_weapon_name"):
		combat_hud.call("set_weapon_name", actor.call("current_weapon_name"))


func _disconnect_player_weapon_events() -> void:
	if actor == null or not actor.has_signal("weapon_changed"):
		return
	var callback := Callable(self, "_on_actor_weapon_changed")
	if actor.is_connected("weapon_changed", callback):
		actor.disconnect("weapon_changed", callback)


func _on_actor_weapon_changed(weapon_name: String) -> void:
	if combat_hud.has_method("set_weapon_name"):
		combat_hud.call("set_weapon_name", weapon_name)


func _sync_combat_hud_health() -> void:
	if actor == null or combat_hud == null or not combat_hud.has_method("set_health"):
		return
	if not actor.has_method("get_health"):
		return
	combat_hud.call("set_health", int(actor.call("get_health")), int(actor.get("max_health")))


func finish_session(overrides: Dictionary = {}) -> Dictionary:
	_clear_pending_reward_choice()
	var result := _build_session_result(overrides)
	GameManager.finish_session(result)
	session_ui_root.show_summary(result)
	return result


func _build_session_result(overrides: Dictionary = {}) -> Dictionary:
	var cleared_room_ids := room_manager.cleared_room_ids.keys()
	var rooms_cleared := cleared_room_ids.size()
	var result := {
		"interactions": completed_interactions,
		"active_markers": PoolManager.get_active_count(&"sample_marker"),
		"completed": _is_layout_complete(),
		"current_room_id": room_manager.current_room_id,
		"cleared_room_ids": cleared_room_ids,
		"rooms_cleared": rooms_cleared,
		"memory_reward": rooms_cleared,
		"students_rescued": 0,
		"friends_purified": _friend_ids.size(),
		"friend_ids": _friend_ids.duplicate(),
		"unlocks": _build_result_unlocks(),
	}
	if not overrides.is_empty():
		result.merge(overrides, true)
	return result


func _build_death_result() -> Dictionary:
	return _build_session_result({
		"outcome": "death",
		"died": true,
		"completed": false,
	})


func _show_death_summary(result: Dictionary) -> void:
	_clear_pending_reward_choice()
	get_tree().paused = true
	session_ui_root.set_status("쓰러짐")
	session_ui_root.show_summary(result)


func is_exit_confirm_visible() -> bool:
	return _confirm_modal.is_open()


func get_exit_confirm_message() -> String:
	return _confirm_modal.get_message_text()


func _on_interaction_triggered(_source: Node, _target: Node) -> void:
	completed_interactions += 1
	session_ui_root.set_status("확인 완료")
	session_ui_root.set_interaction_count(completed_interactions)
	EventBus.emit_interaction_completed({"count": completed_interactions})
	spawn_sample_marker()


func _connect_progression_events() -> void:
	if not has_node("/root/EventBus"):
		return
	var friend_callback := Callable(self, "_on_friend_purified")
	if not EventBus.friend_purified.is_connected(friend_callback):
		EventBus.friend_purified.connect(friend_callback)
	var unlock_callback := Callable(self, "_on_unlock_changed")
	if EventBus.has_signal(&"unlock_changed") and not EventBus.unlock_changed.is_connected(unlock_callback):
		EventBus.unlock_changed.connect(unlock_callback)


func _disconnect_progression_events() -> void:
	if not has_node("/root/EventBus"):
		return
	var friend_callback := Callable(self, "_on_friend_purified")
	if EventBus.friend_purified.is_connected(friend_callback):
		EventBus.friend_purified.disconnect(friend_callback)
	var unlock_callback := Callable(self, "_on_unlock_changed")
	if EventBus.has_signal(&"unlock_changed") and EventBus.unlock_changed.is_connected(unlock_callback):
		EventBus.unlock_changed.disconnect(unlock_callback)


func _connect_combat_feedback_events() -> void:
	if not has_node("/root/EventBus") or not EventBus.has_signal(&"combat_feedback"):
		return
	var callback := Callable(self, "_on_combat_feedback")
	if not EventBus.combat_feedback.is_connected(callback):
		EventBus.combat_feedback.connect(callback)


func _disconnect_combat_feedback_events() -> void:
	if not has_node("/root/EventBus") or not EventBus.has_signal(&"combat_feedback"):
		return
	var callback := Callable(self, "_on_combat_feedback")
	if EventBus.combat_feedback.is_connected(callback):
		EventBus.combat_feedback.disconnect(callback)


func _connect_run_reward_events() -> void:
	if session_ui_root != null and session_ui_root.has_signal("reward_choice_selected"):
		var choice_callback := Callable(self, "_on_reward_choice_selected")
		if not session_ui_root.reward_choice_selected.is_connected(choice_callback):
			session_ui_root.reward_choice_selected.connect(choice_callback)
	if not has_node("/root/EventBus") or not EventBus.has_signal(&"room_cleared"):
		return
	var room_callback := Callable(self, "_on_room_cleared_for_reward")
	if not EventBus.room_cleared.is_connected(room_callback):
		EventBus.room_cleared.connect(room_callback)


func _disconnect_run_reward_events() -> void:
	if session_ui_root != null and session_ui_root.has_signal("reward_choice_selected"):
		var choice_callback := Callable(self, "_on_reward_choice_selected")
		if session_ui_root.reward_choice_selected.is_connected(choice_callback):
			session_ui_root.reward_choice_selected.disconnect(choice_callback)
	if not has_node("/root/EventBus") or not EventBus.has_signal(&"room_cleared"):
		return
	var room_callback := Callable(self, "_on_room_cleared_for_reward")
	if EventBus.room_cleared.is_connected(room_callback):
		EventBus.room_cleared.disconnect(room_callback)


func _on_combat_feedback(payload: Dictionary) -> void:
	if player_camera == null:
		return
	var raw_direction: Variant = payload.get("direction", Vector2.RIGHT)
	var direction := Vector2.RIGHT
	if raw_direction is Vector2:
		direction = raw_direction
	var intensity := float(payload.get("intensity", 2.0))
	player_camera.offset = camera_feedback_offset(direction, intensity)
	_start_camera_feedback_recover()


func _on_room_cleared_for_reward(payload: Dictionary) -> void:
	var room_id := StringName(payload.get("room_id", &""))
	var room_type := StringName(payload.get("room_type", &""))
	if room_id == &"" or room_type != &"combat":
		return
	if room_id != room_manager.current_room_id:
		return
	_apply_room_clear_modifier_effects(room_id)
	if _rewarded_room_ids.has(room_id) or _pending_reward_room_id != &"":
		return
	if _build_reward_choice_models(room_id).is_empty():
		return
	_pending_reward_room_id = room_id
	_start_reward_choice_delay()


func _apply_room_clear_modifier_effects(room_id: StringName) -> void:
	if _room_clear_modifier_room_ids.has(room_id):
		return
	_room_clear_modifier_room_ids[room_id] = true
	if actor != null and actor.has_method("apply_room_clear_modifier_effects"):
		actor.call("apply_room_clear_modifier_effects")


func _start_reward_choice_delay() -> void:
	var timer := _ensure_reward_choice_delay_timer()
	timer.stop()
	timer.start(REWARD_CHOICE_DELAY_SECONDS)


func _ensure_reward_choice_delay_timer() -> Timer:
	if _reward_choice_delay_timer != null and is_instance_valid(_reward_choice_delay_timer):
		return _reward_choice_delay_timer
	_reward_choice_delay_timer = Timer.new()
	_reward_choice_delay_timer.name = "RewardChoiceDelayTimer"
	_reward_choice_delay_timer.one_shot = true
	_reward_choice_delay_timer.wait_time = REWARD_CHOICE_DELAY_SECONDS
	_reward_choice_delay_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_reward_choice_delay_timer)
	_reward_choice_delay_timer.timeout.connect(_on_reward_choice_delay_timeout)
	return _reward_choice_delay_timer


func _cancel_reward_choice_delay() -> void:
	if _reward_choice_delay_timer != null and is_instance_valid(_reward_choice_delay_timer):
		_reward_choice_delay_timer.stop()


func _clear_pending_reward_choice() -> void:
	_cancel_reward_choice_delay()
	_pending_reward_room_id = &""
	_restore_touch_controls_after_reward_choice()


func _on_reward_choice_delay_timeout() -> void:
	if _pending_reward_room_id == &"":
		return
	if _rewarded_room_ids.has(_pending_reward_room_id):
		_pending_reward_room_id = &""
		return
	if room_manager == null or _pending_reward_room_id != room_manager.current_room_id:
		_pending_reward_room_id = &""
		return
	if session_ui_root != null and session_ui_root.has_method("is_reward_choice_visible") and bool(session_ui_root.call("is_reward_choice_visible")):
		return
	if _should_defer_reward_choice_open():
		_start_reward_choice_delay()
		return
	_show_room_reward_choices(_pending_reward_room_id)


func _should_defer_reward_choice_open() -> bool:
	if get_tree().paused:
		return true
	if _confirm_modal != null and _confirm_modal.is_open():
		return true
	return false


func flush_pending_reward_choice_for_tests() -> bool:
	if _pending_reward_room_id == &"":
		return false
	_cancel_reward_choice_delay()
	_on_reward_choice_delay_timeout()
	return session_ui_root != null and session_ui_root.has_method("is_reward_choice_visible") and bool(session_ui_root.call("is_reward_choice_visible"))


func _is_room_transition_blocked_by_reward(_current_room_id: StringName, _preferred_room_id: StringName) -> bool:
	return _pending_reward_room_id != &""


func get_reward_choice_delay_snapshot() -> Dictionary:
	var time_left := 0.0
	if _reward_choice_delay_timer != null and is_instance_valid(_reward_choice_delay_timer):
		time_left = _reward_choice_delay_timer.time_left
	return {
		"pending_room_id": _pending_reward_room_id,
		"time_left": time_left,
		"is_transition_blocked": _pending_reward_room_id != &"",
	}


func _show_room_reward_choices(room_id: StringName) -> void:
	var choices := _build_reward_choice_models(room_id)
	if choices.is_empty():
		_pending_reward_room_id = &""
		return
	_pending_reward_room_id = room_id
	_paused_before_reward_choice = get_tree().paused
	_release_combat_touch_inputs()
	_hide_touch_controls_for_reward_choice()
	get_tree().paused = true
	session_ui_root.call("show_reward_choices", room_id, choices)
	session_ui_root.set_status("전투 보상")


func _on_reward_choice_selected(item_id: StringName) -> void:
	if _pending_reward_room_id == &"":
		return
	var room_id := _pending_reward_room_id
	_pending_reward_room_id = &""
	_rewarded_room_ids[room_id] = true
	var applied := false
	if actor != null and actor.has_method("apply_run_modifier"):
		applied = bool(actor.call("apply_run_modifier", item_id))
	if session_ui_root.has_method("hide_reward_choices"):
		session_ui_root.call("hide_reward_choices")
	get_tree().paused = _paused_before_reward_choice
	_restore_touch_controls_after_reward_choice()
	_reset_current_room_door_transition_latches()
	session_ui_root.set_status("보상 획득")
	if has_node("/root/EventBus"):
		EventBus.emit_interaction_completed({
			"kind": "run_reward_selected",
			"room_id": room_id,
			"room_type": &"combat",
			"item_id": item_id,
			"item_display_name": MapItemCatalog.get_display_name(item_id),
			"applied": applied,
		})


func _build_reward_choice_models(room_id: StringName) -> Array[Dictionary]:
	var models: Array[Dictionary] = []
	for item_id: StringName in _reward_choice_ids(room_id, 3):
		models.append({
			"item_id": item_id,
			"display_name": MapItemCatalog.get_display_name(item_id),
			"flavor": MapItemCatalog.get_flavor(item_id),
			"effect": MapItemCatalog.get_effect_text(item_id),
		})
	return models


func _reward_choice_ids(room_id: StringName, count: int) -> Array[StringName]:
	var ids := MapItemCatalog.reward_item_ids()
	var result: Array[StringName] = []
	if ids.is_empty() or count <= 0:
		return result
	var start_index := absi(String(room_id).hash()) % ids.size()
	for offset: int in range(ids.size()):
		var item_id := ids[(start_index + offset) % ids.size()]
		if result.has(item_id):
			continue
		result.append(item_id)
		if result.size() >= count:
			break
	return result


func _release_combat_touch_inputs() -> void:
	if touch_controls != null and touch_controls.has_method("release_combat_inputs"):
		touch_controls.call("release_combat_inputs")


func _hide_touch_controls_for_reward_choice() -> void:
	if touch_controls == null:
		return
	_touch_controls_visible_before_reward_choice = touch_controls.visible
	touch_controls.visible = false


func _restore_touch_controls_after_reward_choice() -> void:
	if touch_controls == null:
		return
	touch_controls.visible = _touch_controls_visible_before_reward_choice


func _reset_current_room_door_transition_latches() -> void:
	if room_manager == null or room_manager.current_room == null:
		return
	if not room_manager.current_room.has_method("get_doors"):
		return
	for door: RoomDoor in room_manager.current_room.call("get_doors"):
		door.configure_actor(actor)


func camera_feedback_offset(direction: Vector2, intensity: float) -> Vector2:
	var safe_direction := direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	var amount := clampf(intensity, 1.0, COMBAT_FEEDBACK_MAX_OFFSET)
	return -safe_direction * amount


func _start_camera_feedback_recover() -> void:
	if not is_inside_tree() or player_camera == null:
		return
	if _camera_feedback_tween != null and _camera_feedback_tween.is_valid():
		_camera_feedback_tween.kill()
	_camera_feedback_tween = create_tween()
	_camera_feedback_tween.tween_property(
		player_camera,
		"offset",
		Vector2.ZERO,
		COMBAT_FEEDBACK_RECOVER_TIME
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_friend_purified(payload: Dictionary) -> void:
	var friend_id := StringName(payload.get("friend_id", &""))
	if friend_id == &"" or _friend_ids.has(friend_id):
		return
	_friend_ids.append(friend_id)
	if _is_baseball_onboarding_run() and friend_id == &"baseball_captain":
		_finish_baseball_onboarding(payload)


func _finish_baseball_onboarding(payload: Dictionary) -> void:
	if not has_node("/root/GameManager") or not GameManager.is_session_active():
		return
	var room_id := StringName(payload.get("room_id", room_manager.current_room_id))
	if room_id != &"":
		room_manager.cleared_room_ids[room_id] = true
	if has_node("/root/SaveManager"):
		SaveManager.set_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE, true)
		SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, false)
	finish_session({
		"reason": "onboarding_friend_purified",
		"outcome": "onboarding_complete",
		"completed": true,
		"onboarding_kind": SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})


func _on_unlock_changed(payload: Dictionary) -> void:
	for unlock: Variant in payload.get("unlocks", []):
		_add_result_unlock(StringName(unlock))


func _build_result_unlocks() -> Array[StringName]:
	var result := _unlocks.duplicate()
	if _friend_ids.has(&"baseball_captain"):
		_add_unlock_to(result, &"baseball_stage_3")
		if has_node("/root/ProgressionSystem") and ProgressionSystem.is_weapon_unlocked(&"awakened_bat"):
			_add_unlock_to(result, &"awakened_bat")
	return result


func _add_result_unlock(unlock_id: StringName) -> void:
	_add_unlock_to(_unlocks, unlock_id)


func _add_unlock_to(target: Array[StringName], unlock_id: StringName) -> void:
	if unlock_id == &"" or target.has(unlock_id):
		return
	target.append(unlock_id)


func _on_pause_requested() -> void:
	if _confirm_modal.is_open():
		return
	get_tree().paused = true
	session_ui_root.set_status("일시정지")
	_pause_modal_open = true
	_confirm_modal.open(
		PAUSE_MENU_MESSAGE,
		Callable(self, "_resume_from_pause_modal"),
		Callable(self, "_request_abandon_from_pause_modal"),
		false,
		"계속하기",
		"나가기",
		PixelButtonStyle.VARIANT_DANGER
	)


func _on_resume_requested() -> void:
	if _pause_modal_open:
		_confirm_modal.confirm_yes()
		return
	if _confirm_modal.is_open():
		return
	_resume_from_pause_modal()


func _resume_from_pause_modal() -> void:
	_pause_modal_open = false
	get_tree().paused = false
	session_ui_root.set_status("다시 시작")


func _request_abandon_from_pause_modal() -> void:
	_pause_modal_open = false
	_request_abandon_run()


func _on_finish_requested() -> void:
	_request_abandon_run()


func _on_return_requested() -> void:
	get_tree().paused = false
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
	else:
		SceneTransition.go_to_day_lobby()


func _on_retry_requested() -> void:
	get_tree().paused = false
	_handoff_session_on_exit = true
	var config := GameManager.get_active_config()
	config["source"] = "session_result_retry"
	var result: Variant = OK
	if retry_session_callable.is_valid():
		result = retry_session_callable.call(config)
	else:
		result = SceneTransition.start_session(config)
	if result is int and result != OK:
		_handoff_session_on_exit = false


func _configure_player_camera() -> void:
	if player_camera == null:
		return
	var limits := RoomPalette.get_camera_limits()
	player_camera.limit_left = int(limits["left"])
	player_camera.limit_top = int(limits["top"])
	player_camera.limit_right = int(limits["right"])
	player_camera.limit_bottom = int(limits["bottom"])
	player_camera.make_current()


func _on_room_changed(_room_id: StringName, _room_type: StringName) -> void:
	_play_room_fade()
	var current_room := room_manager.current_room
	if current_room != null and actor != null:
		_configure_actor_for_room(current_room)
	_connect_boss_room(current_room)


func _configure_actor_for_room(room: Node2D) -> void:
	var room_bounds := RoomPalette.get_room_bounds()
	if actor.has_method("set_movement_bounds"):
		actor.call("set_movement_bounds", _room_movement_bounds(room))
	actor.global_position = room.global_position + _actor_spawn_offset_for_entry(room_bounds, room_manager.last_entry_door_dir)
	if actor.has_method("clamp_to_movement_bounds"):
		actor.call("clamp_to_movement_bounds")
	if actor.has_method("reset_motion"):
		actor.call("reset_motion")
	elif actor is CharacterBody2D:
		(actor as CharacterBody2D).velocity = Vector2.ZERO


func _room_movement_bounds(room: Node2D) -> Rect2:
	var room_bounds := RoomPalette.get_room_bounds()
	return Rect2(room.global_position + room_bounds.position, room_bounds.size)


func _actor_spawn_offset_for_entry(room_bounds: Rect2, entry_door_dir: StringName) -> Vector2:
	match entry_door_dir:
		&"E":
			return Vector2(room_bounds.end.x - ROOM_ENTRY_SPAWN_INSET.x, 0.0)
		&"N":
			return Vector2(0.0, room_bounds.position.y + ROOM_ENTRY_SPAWN_INSET.y)
		&"S":
			return Vector2(0.0, room_bounds.end.y - ROOM_ENTRY_SPAWN_INSET.y)
		&"W":
			return Vector2(room_bounds.position.x + ROOM_ENTRY_SPAWN_INSET.x, 0.0)
	return Vector2(room_bounds.position.x + ROOM_ENTRY_SPAWN_INSET.x, 0.0)


func _connect_boss_room(room: Node) -> void:
	if room == null or not room.has_signal("boss_spawn_requested"):
		return
	if room.has_method("set_finish_session_on_resolve"):
		room.call("set_finish_session_on_resolve", false)
	var callback := Callable(self, "_on_boss_spawn_requested")
	if not room.is_connected("boss_spawn_requested", callback):
		room.connect("boss_spawn_requested", callback)


func _on_boss_spawn_requested(room_id: StringName, boss_id: StringName, spawn_position: Vector2) -> void:
	if room_id != room_manager.current_room_id:
		return
	if _active_boss != null and is_instance_valid(_active_boss):
		_active_boss.queue_free()
	var boss := BOSS_SCENE.instantiate()
	boss.name = String(boss_id)
	var parent := room_manager.current_room
	if parent == null:
		boss.queue_free()
		return
	parent.add_child(boss)
	if boss is Node2D:
		(boss as Node2D).global_position = spawn_position
	_active_boss = boss
	if boss.has_signal("defeated"):
		boss.connect("defeated", Callable(self, "_on_boss_defeated").bind(parent))


func _on_boss_defeated(_boss: Node, room: Node) -> void:
	if _active_boss == _boss:
		_active_boss = null
	if room != null and is_instance_valid(room) and room.has_method("complete_boss_encounter"):
		var completed := bool(room.call("complete_boss_encounter"))
		if completed and has_node("/root/GameManager") and GameManager.is_session_active():
			finish_session({
				"reason": "boss_resolved",
				"room_id": StringName(room.get("room_id")),
				"boss_id": StringName(room.get("boss_id")),
			})


func _is_layout_complete() -> bool:
	if room_manager.layout == null or room_manager.current_room_id == &"":
		return false
	var final_room_id := _final_room_id()
	if final_room_id == &"":
		return false
	return room_manager.has_cleared_room(final_room_id)


func _final_room_id() -> StringName:
	for room_def: RoomDef in room_manager.layout.room_defs:
		if room_def != null and room_def.room_type == RoomLayout.TYPE_FINAL:
			return room_def.room_id
	return &""


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var tap_pos := (event as InputEventScreenTouch).position
	if _minimap_full:
		_minimap_full = false
		_apply_minimap_layout()
	elif _minimap.get_global_rect().has_point(tap_pos):
		_minimap_full = true
		_apply_minimap_layout()


func _apply_minimap_layout() -> void:
	if _minimap_full:
		_minimap.anchor_left = 0.0
		_minimap.anchor_top = 0.0
		_minimap.anchor_right = 1.0
		_minimap.anchor_bottom = 1.0
		_minimap.offset_left = 0.0
		_minimap.offset_top = 0.0
		_minimap.offset_right = 0.0
		_minimap.offset_bottom = 0.0
		_minimap.set("room_size", Vector2(40, 40))
		_minimap.set("cell_spacing", Vector2(56, 56))
	else:
		_minimap.anchor_left = 1.0
		_minimap.anchor_top = 0.0
		_minimap.anchor_right = 1.0
		_minimap.anchor_bottom = 0.0
		_minimap.offset_left = -320.0
		_minimap.offset_top = 14.0
		_minimap.offset_right = -14.0
		_minimap.offset_bottom = 114.0
		_minimap.set("room_size", Vector2(26, 26))
		_minimap.set("cell_spacing", Vector2(36, 36))
	_minimap.queue_redraw()


func _play_room_fade() -> void:
	if _fade_rect == null:
		return
	_fade_rect.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 0.35)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			_request_quit_game()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED:
			SceneTransition.save_profile_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_modal.is_open():
		return
	if event.is_action_pressed(&"ui_cancel") or _is_escape_key(event):
		_handle_back_request()
		get_viewport().set_input_as_handled()


func _handle_back_request() -> void:
	if _confirm_modal.is_open():
		return
	if session_ui_root.is_summary_visible():
		_on_return_requested()
		return
	_request_abandon_run()


func _request_abandon_run() -> void:
	if _confirm_modal.is_open():
		return
	_paused_before_exit_modal = get_tree().paused
	get_tree().paused = true
	session_ui_root.set_status("나가기 확인")
	_confirm_modal.open(
		ABANDON_RUN_MESSAGE,
		Callable(self, "_abandon_run_to_school"),
		Callable(self, "_restore_pause_after_exit_modal"),
		true
	)


func _abandon_run_to_school() -> void:
	get_tree().paused = false
	if has_node("/root/GameManager"):
		GameManager.reset_session()
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
	else:
		SceneTransition.go_to_day_lobby()


func _request_quit_game() -> void:
	if _confirm_modal.is_open():
		return
	_paused_before_exit_modal = get_tree().paused
	get_tree().paused = true
	_confirm_modal.open(
		QUIT_GAME_MESSAGE,
		Callable(self, "_quit_game"),
		Callable(self, "_restore_pause_after_exit_modal")
	)


func _quit_game() -> void:
	get_tree().paused = false
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _restore_pause_after_exit_modal() -> void:
	get_tree().paused = _paused_before_exit_modal
	session_ui_root.set_status("일시정지" if get_tree().paused else "준비 완료")


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
