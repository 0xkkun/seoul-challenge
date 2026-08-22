extends Node2D

signal minimap_expanded_changed(expanded: bool)

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const POOLED_MARKER_SCENE = preload("res://scenes/interactables/sample_pooled_marker.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const HUB_DIALOGUE_SCENE = preload("res://scenes/ui/hub_dialogue_ui.tscn")
const BaseballOnboardingIntro = preload("res://resources/dialogue/baseball_onboarding_intro.gd")
const PalaceBossIntro = preload("res://resources/dialogue/palace_boss_intro.gd")
const BOSS_INTRO_DIALOG_LAYER := 200  # SessionUIRoot(10) 위, ConfirmModal(240) 아래
const RoomPalette = preload("res://scripts/constants/room_palette.gd")
const MapItemCatalog = preload("res://scripts/items/map_item_catalog.gd")
const MobileSafeArea = preload("res://scripts/ui/mobile_safe_area.gd")
const InputPromptPolicy = preload("res://scripts/ui/input_prompt_policy.gd")

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
const COMBAT_FEEDBACK_SHAKE_STEP_TIME := 0.035
const COMBAT_FEEDBACK_MAX_OFFSET := 7.0
const ROOM_ENTRY_SPAWN_INSET := Vector2(140.0, 96.0)
const TOP_LEFT_HUD_GAP := 8.0
const FLOATING_TEXT_POOL_ID := &"floating_combat_text"
const FLOATING_TEXT_CAP := 20
const PLAYER_DAMAGE_TEXT_SCREEN_OFFSET := Vector2(24.0, 0.0)
const BASEBALL_ONBOARDING_LAYOUT_ID := &"onboarding_baseball_captain"
const REWARD_CHOICE_DELAY_SECONDS := 1.0
const PURIFY_ONBOARDING_INTRO_MESSAGE := "공격해 기절시킨 뒤 가까이 다가가 정화"
const PURIFY_ONBOARDING_GROGGY_MESSAGE := "친구 곁에서 정화가 끝날 때까지 지키기"
const PURIFY_ONBOARDING_TARGET_SIZE := Vector2(148.0, 170.0)
const PURIFY_ONBOARDING_TARGET_OFFSET := Vector2(0.0, -54.0)
const UAT_ACTION_MINIMAP_EXPAND := "session.minimap.expand"
const UAT_ACTION_SKIP_GUIDANCE := "onboarding.skip_guidance"
const ONBOARDING_JOURNEY_PHASES: Array[StringName] = [
	&"combat",
	&"reward",
	&"friend_intro",
	&"purify",
	&"talk",
	&"bat_reward",
	&"complete",
]

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
@onready var damage_vignette: DamageVignette = %DamageVignette
@onready var session_ui_root: CanvasLayer = %SessionUIRoot
@onready var ingame_control_onboarding: CanvasLayer = %IngameControlOnboarding
@onready var purify_onboarding_spotlight: PurifyOnboardingSpotlight = %PurifyOnboardingSpotlight
@onready var parry_onboarding: ParryOnboarding = %ParryOnboarding
@onready var parry_feedback_controller: ParryFeedbackController = %ParryFeedbackController
@onready var player_camera: Camera2D = %PlayerCamera
@onready var _fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var _minimap: Control = $MinimapLayer/Minimap
@onready var _confirm_modal: ConfirmModal = %ConfirmModal

var completed_interactions := 0
var return_to_school_callable: Callable
var return_to_lobby_callable: Callable
var retry_session_callable: Callable
var quit_game_callable: Callable
var _handoff_session_on_exit := false
var _active_boss: Node = null
var _minimap_full := false
var _paused_before_exit_modal := false
var _exit_modal_from_pause_menu := false
var _friend_ids: Array[StringName] = []
# Latched once per run: whether this run was built as the baseball onboarding. Computed lazily on
# first query (at session setup, before any purification) so the answer can't flip mid-run when the
# captain gets purified — only a fresh run (new session_root) recomputes it. 0 = unknown, 1, -1.
var _baseball_onboarding_run_latch := 0
var _unlocks: Array[StringName] = []
var _camera_feedback_tween: Tween = null
var _room_fade_tween: Tween = null
var _room_fade_processes_while_paused := false
var _rewarded_room_ids := {}
var _room_clear_modifier_room_ids := {}
var _pending_reward_room_id: StringName = &""
var _paused_before_reward_choice := false
var _pause_modal_open := false
var _reward_choice_delay_timer: Timer = null
var _touch_controls_visible_before_reward_choice := true
var _touch_controls_initially_visible := false
var _boss_intro_active := false
var _paused_before_boss_intro := false
var _boss_intro_ui: HubDialogueUi = null
var _baseball_friend_intro_active := false
var _paused_before_baseball_friend_intro := false
var _baseball_friend_intro_ui: HubDialogueUi = null
var _baseball_friend_intro_shown := false
var _purify_onboarding_active := false
var _purify_onboarding_intro_shown := false
var _purify_onboarding_groggy_shown := false
var _paused_before_purify_onboarding := false
var _touch_controls_visible_before_purify_onboarding := true
var _onboarding_journey_phase: StringName = &"complete"
var _completed_onboarding_phases: Array[StringName] = []
var _parry_combat_room: Node = null
var _parry_wolves: Array[Node] = []
var _prompted_parry_wolf_ids := {}


func _ready() -> void:
	SceneTransition.configure_exit_requests()
	_apply_render_layers()
	_touch_controls_initially_visible = touch_controls != null and touch_controls.visible
	if not GameManager.is_session_active():
		GameManager.start_session({"source": "session_root"})
	_configure_onboarding_journey()
	AudioManager.play_bgm(AudioManager.NIGHT_RUN_SUSPENSE_BGM)
	_apply_session_loadout()
	damage_vignette.bind_player(actor)
	_connect_player_weapon_events()
	_sync_combat_hud_health()
	PoolManager.register_scene(&"sample_marker", POOLED_MARKER_SCENE, 1, pooled_object_layer)
	_configure_parry_feedback_controller()
	_connect_player_combat_text_events()
	interaction_system.configure(actor, self)
	_configure_player_camera()
	_configure_purify_onboarding_spotlight()
	_configure_parry_onboarding()
	_configure_ingame_control_onboarding()
	death_return_controller.death_result_builder_callable = Callable(self, "_build_death_result")
	death_return_controller.game_over_callable = Callable(self, "_show_death_summary")
	_connect_progression_events()
	_connect_combat_feedback_events()
	_connect_run_reward_events()
	_connect_player_parry_events()
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


func _configure_ingame_control_onboarding() -> void:
	if ingame_control_onboarding == null:
		return
	if ingame_control_onboarding.has_method("configure"):
		ingame_control_onboarding.call("configure", touch_controls, player_camera, actor, _minimap)
	if ingame_control_onboarding.has_signal("gate_released"):
		var gate_callback := Callable(self, "_on_ingame_control_gate_released")
		if not ingame_control_onboarding.is_connected("gate_released", gate_callback):
			ingame_control_onboarding.connect("gate_released", gate_callback)
	var minimap_callback := Callable(self, "_on_minimap_expanded_changed")
	if not minimap_expanded_changed.is_connected(minimap_callback):
		minimap_expanded_changed.connect(minimap_callback)
	if _is_baseball_onboarding_run() and ingame_control_onboarding.has_method("start"):
		ingame_control_onboarding.call("start")
	else:
		ingame_control_onboarding.visible = false


func _configure_purify_onboarding_spotlight() -> void:
	if purify_onboarding_spotlight == null:
		return
	purify_onboarding_spotlight.configure(player_camera)


func _configure_parry_onboarding() -> void:
	if parry_onboarding == null:
		return
	parry_onboarding.configure(player_camera)


func _configure_parry_feedback_controller() -> void:
	if parry_feedback_controller == null:
		return
	parry_feedback_controller.configure(actor, pooled_object_layer)


func _reset_parry_feedback_state(teardown := false) -> void:
	if has_node("/root/HitStopManager"):
		HitStopManager.restore()
	if parry_feedback_controller != null:
		if teardown:
			parry_feedback_controller.teardown()
		else:
			parry_feedback_controller.reset()
	if has_node("/root/PoolManager"):
		PoolManager.clear_pool(&"floating_combat_text")
	if _camera_feedback_tween != null and _camera_feedback_tween.is_valid():
		_camera_feedback_tween.kill()
	_camera_feedback_tween = null
	if player_camera != null:
		player_camera.offset = Vector2.ZERO


func _finish_all_onboarding_ui() -> void:
	_finish_boss_intro()
	_finish_baseball_friend_intro()
	_finish_purify_onboarding_spotlight()
	_disconnect_parry_room_events()
	_disconnect_player_parry_events()
	_disconnect_player_combat_text_events()
	if ingame_control_onboarding != null and ingame_control_onboarding.has_method("finish"):
		ingame_control_onboarding.call("finish")
	if parry_onboarding != null:
		parry_onboarding.dismiss()
		parry_onboarding.visible = false
	if session_ui_root != null and session_ui_root.has_method("finish_onboarding_ui"):
		session_ui_root.call("finish_onboarding_ui")
	_clear_pending_reward_choice()
	_reset_parry_feedback_state(true)
	_release_combat_touch_inputs()
	if touch_controls != null:
		touch_controls.visible = _touch_controls_initially_visible
	var tree := get_tree()
	if tree != null:
		tree.paused = false
	if player_camera != null:
		player_camera.zoom = Vector2.ONE
		player_camera.offset = Vector2.ZERO


func _exit_tree() -> void:
	_finish_all_onboarding_ui()
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


func is_encounter_dialogue_visible() -> bool:
	return _active_encounter_dialogue_ui() != null


func get_encounter_dialogue_speaker() -> String:
	var ui := _active_encounter_dialogue_ui()
	if ui == null:
		return ""
	return ui.get_speaker_name()


func get_encounter_dialogue_text() -> String:
	var ui := _active_encounter_dialogue_ui()
	if ui == null:
		return ""
	return ui.get_dialogue_text()


func advance_encounter_dialogue_for_tests() -> bool:
	var ui := _active_encounter_dialogue_ui()
	if ui == null:
		return false
	ui.select_choice(&"continue")
	return true


func is_purify_onboarding_spotlight_visible() -> bool:
	return _is_purify_onboarding_spotlight_active()


func get_purify_onboarding_snapshot() -> Dictionary:
	if purify_onboarding_spotlight == null or not is_instance_valid(purify_onboarding_spotlight):
		return {}
	return purify_onboarding_spotlight.get_snapshot()


func dismiss_purify_onboarding_for_tests() -> bool:
	if purify_onboarding_spotlight == null or not is_instance_valid(purify_onboarding_spotlight):
		return false
	var dismissed := purify_onboarding_spotlight.dismiss()
	if dismissed:
		_finish_purify_onboarding_spotlight()
	return dismissed


func get_onboarding_journey_snapshot() -> Dictionary:
	return {
		"phase": _onboarding_journey_phase,
		"completed_phases": _completed_onboarding_phases.duplicate(),
		"current_instruction": _onboarding_journey_instruction(_onboarding_journey_phase),
		"input_mode": _onboarding_journey_input_mode(),
	}


func _configure_onboarding_journey() -> void:
	_completed_onboarding_phases.clear()
	_onboarding_journey_phase = &"combat" if _is_baseball_onboarding_run() else &"complete"


func _advance_onboarding_journey(expected: StringName, next_phase: StringName) -> bool:
	if _onboarding_journey_phase != expected:
		return false
	if not ONBOARDING_JOURNEY_PHASES.has(next_phase):
		return false
	if expected != &"complete" and not _completed_onboarding_phases.has(expected):
		_completed_onboarding_phases.append(expected)
	_onboarding_journey_phase = next_phase
	return true


func _onboarding_journey_instruction(phase: StringName) -> String:
	match phase:
		&"combat":
			return "적을 쓰러뜨리면 다음 길이 열린다"
		&"reward":
			return "카드 하나를 골라 이번 탐험을 강화"
		&"friend_intro":
			return PURIFY_ONBOARDING_INTRO_MESSAGE
		&"purify":
			return PURIFY_ONBOARDING_GROGGY_MESSAGE
		&"talk":
			return "야구부 주장 말 걸기" if _onboarding_journey_input_mode() == &"touch" else "[E] 야구부 주장에게 말 걸기"
		&"bat_reward":
			return "대화를 끝까지 듣고 배트를 받기"
	return ""


func _onboarding_journey_input_mode() -> StringName:
	var features := {}
	if has_node("/root/PlatformManager"):
		features = PlatformManager.get_feature_flags()
	return InputPromptPolicy.input_mode_from_features(features)


func _sync_onboarding_journey_surface() -> void:
	if session_ui_root == null or not session_ui_root.has_method("set_onboarding_journey_hint"):
		return
	var title := ""
	var enabled := false
	var contextual_surface_clear := not _baseball_friend_intro_active and not _is_purify_onboarding_spotlight_active()
	if _is_baseball_onboarding_run() and contextual_surface_clear:
		if _onboarding_journey_phase == &"combat" and room_manager != null and room_manager.current_room_id == &"combat_1":
			title = "첫 전투"
			enabled = true
		elif _onboarding_journey_phase == &"friend_intro":
			title = "친구 조우"
			enabled = true
	session_ui_root.call(
		"set_onboarding_journey_hint",
		title,
		_onboarding_journey_instruction(_onboarding_journey_phase),
		enabled
	)


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
				"chaser_speed_override": 92.0,
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
	# Latch on first query so the result stays stable for the whole run. The captain's purification
	# (recorded mid-run) must not flip this to false before _on_friend_purified can finish the run.
	if _baseball_onboarding_run_latch != 0:
		return _baseball_onboarding_run_latch == 1
	var result := _evaluate_baseball_onboarding_run()
	_baseball_onboarding_run_latch = 1 if result else -1
	return result


func _evaluate_baseball_onboarding_run() -> bool:
	var config := GameManager.get_active_config()
	var is_onboarding_config := StringName(config.get(SceneTransition.RUN_CONFIG_ONBOARDING_KIND, &"")) == SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN
	if not is_onboarding_config:
		return false
	# Fallback guard: once the baseball onboarding is recorded complete, never treat a run
	# as onboarding again — even if a stale active config still carries the onboarding kind
	# (e.g. retrying from the result screen reuses the previous config). Without this the
	# captain re-spawns and the onboarding can be re-cleared after it was already finished.
	if has_node("/root/SaveManager") and SaveManager.get_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE):
		return false
	# Authoritative guard: the captain's purification record is the single source of truth for
	# "already cleansed". If purification was recorded but the completion flag was never written
	# (e.g. the session went inactive before _finish_baseball_onboarding ran), the flag check above
	# misses it and the captain re-spawns on a fresh map. is_friend_purified covers that divergence.
	# Evaluated only at run start (before this run's own purification), so it gates a *fresh* run.
	if has_node("/root/ProgressionSystem") and ProgressionSystem.is_friend_purified(&"baseball_captain"):
		return false
	return true


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


func _connect_player_combat_text_events() -> void:
	if actor == null or not actor.has_signal(&"combat_text_requested"):
		return
	var callback := Callable(self, "_on_actor_combat_text_requested")
	if not actor.is_connected(&"combat_text_requested", callback):
		actor.connect(&"combat_text_requested", callback)


func _disconnect_player_combat_text_events() -> void:
	if actor == null or not is_instance_valid(actor) or not actor.has_signal(&"combat_text_requested"):
		return
	var callback := Callable(self, "_on_actor_combat_text_requested")
	if actor.is_connected(&"combat_text_requested", callback):
		actor.disconnect(&"combat_text_requested", callback)


func _on_actor_combat_text_requested(position: Vector2, text: String, style: StringName) -> void:
	var target_position := _player_damage_text_world_position() if style == &"player_damage" else position
	spawn_combat_text(target_position, text, style)


func spawn_combat_text(position: Vector2, text: String, style: StringName) -> bool:
	if not Settings.is_damage_numbers_enabled():
		return false
	if not PoolManager.has_pool(FLOATING_TEXT_POOL_ID):
		return false
	if PoolManager.get_active_count(FLOATING_TEXT_POOL_ID) >= FLOATING_TEXT_CAP:
		return false
	var text_node := PoolManager.acquire(FLOATING_TEXT_POOL_ID, pooled_object_layer)
	if text_node == null or not text_node.has_method("initialize"):
		if text_node != null:
			PoolManager.release(text_node)
		return false
	text_node.call("initialize", position, text, style)
	return true


func _player_damage_text_world_position() -> Vector2:
	var health_panel := combat_hud.get_node_or_null("Root/HealthPanel") as Control
	var viewport := get_viewport()
	if health_panel == null or viewport == null:
		return actor.global_position if actor != null else Vector2.ZERO
	var health_rect := health_panel.get_global_rect()
	var screen_position := Vector2(health_rect.end.x, health_rect.get_center().y) + PLAYER_DAMAGE_TEXT_SCREEN_OFFSET
	return viewport.get_canvas_transform().affine_inverse() * screen_position


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
	_finish_all_onboarding_ui()
	var result := _build_session_result(overrides)
	GameManager.finish_session(result)
	_play_run_victory_sfx()
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
		"onboarding_kind": SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN if _is_baseball_onboarding_run() else &"",
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
	_finish_all_onboarding_ui()
	get_tree().paused = true
	session_ui_root.set_status("쓰러짐")
	session_ui_root.show_summary(result)


func _play_run_victory_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.RUN_VICTORY)


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
	var offsets := camera_feedback_shake_offsets(direction, intensity)
	player_camera.offset = offsets[0]
	_start_camera_feedback_recover(offsets)


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
	if _is_baseball_onboarding_run() and room_id == &"combat_1":
		_advance_onboarding_journey(&"combat", &"reward")
	_sync_onboarding_journey_surface()
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
	return _pending_reward_room_id != &"" or _boss_intro_active or _baseball_friend_intro_active or _is_purify_onboarding_spotlight_active()


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
	if session_ui_root.has_method("set_reward_choice_onboarding_hint"):
		session_ui_root.call("set_reward_choice_onboarding_hint", _should_show_reward_choice_onboarding(room_id))
	session_ui_root.call("show_reward_choices", room_id, choices)
	session_ui_root.set_status("전투 보상")


func _on_reward_choice_selected(item_id: StringName) -> void:
	if _pending_reward_room_id == &"":
		return
	var room_id := _pending_reward_room_id
	_pending_reward_room_id = &""
	_rewarded_room_ids[room_id] = true
	if _is_baseball_onboarding_run() and room_id == &"combat_1":
		_advance_onboarding_journey(&"reward", &"friend_intro")
	_sync_onboarding_journey_surface()
	var applied := false
	if actor != null and actor.has_method("apply_run_modifier"):
		applied = bool(actor.call("apply_run_modifier", item_id))
	if session_ui_root.has_method("hide_reward_choices"):
		session_ui_root.call("hide_reward_choices")
	if session_ui_root.has_method("set_reward_choice_onboarding_hint"):
		session_ui_root.call("set_reward_choice_onboarding_hint", false)
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


func _should_show_reward_choice_onboarding(room_id: StringName) -> bool:
	return _is_baseball_onboarding_run() and room_id == &"combat_1"


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


func camera_feedback_shake_offsets(direction: Vector2, intensity: float) -> Array:
	var first := camera_feedback_offset(direction, intensity)
	if first.length() <= 0.001:
		return [Vector2.ZERO]
	var amount := first.length()
	var safe_direction := direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	var tangent := Vector2(-safe_direction.y, safe_direction.x)
	return [
		first,
		safe_direction * amount * 0.55 + tangent * amount * 0.20,
		-safe_direction * amount * 0.30,
		Vector2.ZERO,
	]


func _start_camera_feedback_recover(offsets: Array = []) -> void:
	if not is_inside_tree() or player_camera == null:
		return
	if _camera_feedback_tween != null and _camera_feedback_tween.is_valid():
		_camera_feedback_tween.kill()
	_camera_feedback_tween = create_tween()
	if offsets.size() <= 1:
		_camera_feedback_tween.tween_property(
			player_camera,
			"offset",
			Vector2.ZERO,
			COMBAT_FEEDBACK_RECOVER_TIME
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	for index in range(1, offsets.size()):
		var duration := COMBAT_FEEDBACK_RECOVER_TIME if index == offsets.size() - 1 else COMBAT_FEEDBACK_SHAKE_STEP_TIME
		_camera_feedback_tween.tween_property(
			player_camera,
			"offset",
			offsets[index],
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_friend_purified(payload: Dictionary) -> void:
	if is_queued_for_deletion() or not is_inside_tree():
		return
	var friend_id := StringName(payload.get("friend_id", &""))
	if friend_id == &"" or _friend_ids.has(friend_id):
		return
	if (
		_is_baseball_onboarding_run()
		and friend_id == &"baseball_captain"
		and _onboarding_journey_phase != &"purify"
	):
		return
	_friend_ids.append(friend_id)
	if _is_baseball_onboarding_run() and friend_id == &"baseball_captain":
		if not _advance_onboarding_journey(&"purify", &"talk"):
			return
		_sync_onboarding_journey_surface()
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
	_open_pause_modal()


func _open_pause_modal() -> void:
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
	_exit_modal_from_pause_menu = true
	_request_abandon_run()


func _on_finish_requested() -> void:
	_request_abandon_run()


func _on_return_requested() -> void:
	_finish_all_onboarding_ui()
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
	else:
		SceneTransition.go_to_day_lobby()


func _on_retry_requested() -> void:
	var config := GameManager.get_active_config()
	_finish_all_onboarding_ui()
	_handoff_session_on_exit = true
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


func _on_room_changed(room_id: StringName, room_type: StringName) -> void:
	_play_room_fade()
	var current_room := room_manager.current_room
	_connect_parry_room_events(current_room)
	if (
		room_id == &"start"
		and current_room is StartRoom
		and _is_baseball_onboarding_run()
		and ingame_control_onboarding != null
		and ingame_control_onboarding.has_method("is_active")
		and bool(ingame_control_onboarding.call("is_active"))
	):
		(current_room as StartRoom).set_tutorial_gate_active(true)
	if ingame_control_onboarding != null and ingame_control_onboarding.has_method("record_room_changed"):
		ingame_control_onboarding.call("record_room_changed", room_id, room_type)
	if current_room != null and actor != null:
		_configure_actor_for_room(current_room)
	_connect_boss_room(current_room)
	_connect_friend_room(current_room)
	_sync_onboarding_journey_surface()


func _connect_player_parry_events() -> void:
	if actor == null or not actor.has_signal("parry_succeeded"):
		return
	var callback := Callable(self, "_on_player_parry_succeeded")
	if not actor.is_connected(&"parry_succeeded", callback):
		actor.connect(&"parry_succeeded", callback)


func _disconnect_player_parry_events() -> void:
	if actor == null or not actor.has_signal("parry_succeeded"):
		return
	var callback := Callable(self, "_on_player_parry_succeeded")
	if actor.is_connected(&"parry_succeeded", callback):
		actor.disconnect(&"parry_succeeded", callback)


func _connect_parry_room_events(room: Node) -> void:
	_disconnect_parry_room_events()
	if not _is_parry_tutorial_eligible():
		return
	if room == null or not room.has_signal("enemy_spawned"):
		return
	_parry_combat_room = room
	var callback := Callable(self, "_on_parry_enemy_spawned")
	if not room.is_connected(&"enemy_spawned", callback):
		room.connect(&"enemy_spawned", callback)


func _disconnect_parry_room_events() -> void:
	if _parry_combat_room != null and is_instance_valid(_parry_combat_room) and _parry_combat_room.has_signal("enemy_spawned"):
		var spawn_callback := Callable(self, "_on_parry_enemy_spawned")
		if _parry_combat_room.is_connected(&"enemy_spawned", spawn_callback):
			_parry_combat_room.disconnect(&"enemy_spawned", spawn_callback)
	for wolf: Node in _parry_wolves.duplicate():
		_disconnect_parry_wolf(wolf)
	_parry_wolves.clear()
	_parry_combat_room = null
	if parry_onboarding != null:
		parry_onboarding.dismiss()


func _on_parry_enemy_spawned(enemy: Node, enemy_type: StringName, _wave_index: int) -> void:
	if enemy_type != &"wolf" or not _is_parry_tutorial_eligible():
		return
	if enemy == null or not is_instance_valid(enemy) or _parry_wolves.has(enemy):
		return
	_parry_wolves.append(enemy)
	var dash_callback := Callable(self, "_on_wolf_dash_state_changed").bind(enemy)
	if enemy.has_signal("dash_state_changed") and not enemy.is_connected(&"dash_state_changed", dash_callback):
		enemy.connect(&"dash_state_changed", dash_callback)
	var defeated_callback := Callable(self, "_on_parry_wolf_defeated")
	if enemy.has_signal("defeated") and not enemy.is_connected(&"defeated", defeated_callback):
		enemy.connect(&"defeated", defeated_callback)
	var exiting_callback := Callable(self, "_on_parry_wolf_tree_exiting").bind(enemy)
	if not enemy.tree_exiting.is_connected(exiting_callback):
		enemy.tree_exiting.connect(exiting_callback)


func _disconnect_parry_wolf(wolf: Node) -> void:
	if wolf == null or not is_instance_valid(wolf):
		return
	var dash_callback := Callable(self, "_on_wolf_dash_state_changed").bind(wolf)
	if wolf.has_signal("dash_state_changed") and wolf.is_connected(&"dash_state_changed", dash_callback):
		wolf.disconnect(&"dash_state_changed", dash_callback)
	var defeated_callback := Callable(self, "_on_parry_wolf_defeated")
	if wolf.has_signal("defeated") and wolf.is_connected(&"defeated", defeated_callback):
		wolf.disconnect(&"defeated", defeated_callback)
	var exiting_callback := Callable(self, "_on_parry_wolf_tree_exiting").bind(wolf)
	if wolf.tree_exiting.is_connected(exiting_callback):
		wolf.tree_exiting.disconnect(exiting_callback)


func _on_wolf_dash_state_changed(state: StringName, wolf: Node2D) -> void:
	if state != &"prepare" or not _is_parry_tutorial_eligible():
		return
	if wolf == null or not is_instance_valid(wolf):
		return
	var wolf_id := wolf.get_instance_id()
	if _prompted_parry_wolf_ids.has(wolf_id):
		return
	_prompted_parry_wolf_ids[wolf_id] = true
	parry_onboarding.show_for_wolf(wolf, _onboarding_journey_input_mode())


func _on_player_parry_succeeded(_payload: Dictionary) -> void:
	if not _is_parry_tutorial_eligible():
		return
	SaveManager.set_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE, true)
	_disconnect_parry_room_events()


func _on_parry_wolf_defeated(wolf: Node) -> void:
	if parry_onboarding != null:
		parry_onboarding.dismiss_for_wolf(wolf)
	_parry_wolves.erase(wolf)


func _on_parry_wolf_tree_exiting(wolf: Node) -> void:
	if parry_onboarding != null:
		parry_onboarding.dismiss_for_wolf(wolf)
	_parry_wolves.erase(wolf)


func _is_parry_tutorial_eligible() -> bool:
	if not has_node("/root/SaveManager"):
		return false
	if actor != null and actor.has_method("has_bat") and not bool(actor.call("has_bat")):
		return false
	return (
		SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED)
		and not SaveManager.get_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE)
	)


func get_parry_tutorial_snapshot() -> Dictionary:
	return parry_onboarding.get_snapshot() if parry_onboarding != null else {"active": false}


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


func _connect_friend_room(room: Node) -> void:
	if room == null or not room.has_signal("friend_encounter_started"):
		return
	var callback := Callable(self, "_on_friend_encounter_started")
	if not room.is_connected("friend_encounter_started", callback):
		room.connect("friend_encounter_started", callback)
	if room.has_signal("friend_spawned"):
		var spawned_callback := Callable(self, "_on_friend_spawned")
		if not room.is_connected("friend_spawned", spawned_callback):
			room.connect("friend_spawned", spawned_callback)


func _on_friend_encounter_started(room_id: StringName) -> void:
	if not _should_play_baseball_friend_intro(room_id):
		return
	_play_baseball_friend_intro()


func _on_friend_spawned(room_id: StringName, friend_id: StringName, friend: Node) -> void:
	if not _should_attach_purify_onboarding(room_id, friend_id):
		return
	if friend == null or not friend.has_signal("stunned"):
		return
	var callback := Callable(self, "_on_onboarding_friend_stunned").bind(friend)
	if not friend.is_connected("stunned", callback):
		friend.connect("stunned", callback)


func _should_play_baseball_friend_intro(room_id: StringName) -> bool:
	if _baseball_friend_intro_shown or _baseball_friend_intro_active:
		return false
	if not _is_baseball_onboarding_run():
		return false
	if room_id != &"friend_1":
		return false
	var room := room_manager.current_room
	if room == null:
		return false
	return StringName(room.get("friend_id")) == &"baseball_captain"


func _should_attach_purify_onboarding(room_id: StringName, friend_id: StringName) -> bool:
	if not _is_baseball_onboarding_run():
		return false
	if room_id != &"friend_1":
		return false
	return friend_id == &"baseball_captain"


func _on_onboarding_friend_stunned(friend: Node) -> void:
	if _purify_onboarding_groggy_shown:
		return
	if not _is_baseball_onboarding_run():
		return
	if friend == null or not is_instance_valid(friend):
		return
	_advance_onboarding_journey(&"friend_intro", &"purify")
	_sync_onboarding_journey_surface()
	_play_purify_onboarding_spotlight(&"groggy", friend)


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
	if boss.has_method("set_movement_bounds") and parent is Node2D:
		boss.call("set_movement_bounds", _room_movement_bounds(parent))
	_active_boss = boss
	# Swap the run's suspense BGM for the boss-battle track now that the fight has begun.
	# On defeat the session finishes and the destination scene starts its own BGM, matching
	# how the suspense track is replaced rather than explicitly stopped.
	AudioManager.play_bgm(AudioManager.BOSS_BATTLE_BGM)
	if boss.has_signal("defeated"):
		boss.connect("defeated", Callable(self, "_on_boss_defeated").bind(parent))
	# 보스를 띄운 뒤 인게임 대사를 재생한다(없으면 즉시 반환). 보스는 화면에 등장한 채로
	# get_tree().paused 에 의해 정지하고, 대사가 끝나면 전투가 시작된다(#5: 스폰과 대사 분리).
	# 보스가 먼저 존재하므로 "적 없는 미클리어 방=빈 방" 오분류(d)도 발생하지 않는다.
	await _play_boss_intro(boss_id)


func _active_encounter_dialogue_ui() -> HubDialogueUi:
	if is_instance_valid(_baseball_friend_intro_ui):
		return _baseball_friend_intro_ui
	if is_instance_valid(_boss_intro_ui):
		return _boss_intro_ui
	return null


func _set_encounter_beat(ui: HubDialogueUi, beat: Dictionary) -> void:
	ui.set_dialogue(
		String(beat.get("speaker", "")),
		String(beat.get("text", "")),
		"",
		HubDialogueUi.PORTRAIT_COLOR,
		beat.get("portrait") as Texture2D,
		int(beat.get("frame", 0)),
		false,
	)
	if beat.has("portrait_scale") or beat.has("portrait_y"):
		var portrait_scale: Vector2 = beat.get("portrait_scale", HubDialogueUi.DEFAULT_PORTRAIT_SCALE)
		var portrait_y := float(beat.get("portrait_y", HubDialogueUi.DEFAULT_PORTRAIT_Y))
		ui.set_portrait_layout(portrait_scale, portrait_y)
	var continue_choice: Array[Dictionary] = [{
		"id": &"continue",
		"tap_to_continue": true,
		"text": _continue_hint(),
	}]
	ui.set_choices(continue_choice)


func _continue_hint() -> String:
	var features := {}
	if has_node("/root/PlatformManager"):
		features = PlatformManager.get_feature_flags()
	return InputPromptPolicy.continue_hint(
		InputPromptPolicy.input_mode_from_features(features)
	)


func _play_baseball_friend_intro() -> void:
	var beats := BaseballOnboardingIntro.collect_beats()
	if beats.is_empty():
		return
	_baseball_friend_intro_shown = true
	_baseball_friend_intro_active = true
	_sync_onboarding_journey_surface()
	_paused_before_baseball_friend_intro = get_tree().paused
	_release_combat_touch_inputs()
	_hide_touch_controls_for_reward_choice()
	get_tree().paused = true
	_baseball_friend_intro_ui = HUB_DIALOGUE_SCENE.instantiate()
	_baseball_friend_intro_ui.name = "BaseballFriendIntroDialogueUi"
	_baseball_friend_intro_ui.battle_mode = true
	_baseball_friend_intro_ui.layer = BOSS_INTRO_DIALOG_LAYER
	add_child(_baseball_friend_intro_ui)
	for beat: Dictionary in beats:
		if not is_instance_valid(_baseball_friend_intro_ui):
			break
		_set_encounter_beat(_baseball_friend_intro_ui, beat)
		await _baseball_friend_intro_ui.choice_selected
	_finish_baseball_friend_intro()
	if _should_play_purify_intro_spotlight():
		await _play_purify_onboarding_spotlight(&"intro", _find_active_onboarding_friend())


func _finish_baseball_friend_intro() -> void:
	if not _baseball_friend_intro_active:
		return
	_baseball_friend_intro_active = false
	if is_instance_valid(_baseball_friend_intro_ui):
		_baseball_friend_intro_ui.queue_free()
	_baseball_friend_intro_ui = null
	var tree := get_tree()
	if tree != null:
		tree.paused = _paused_before_baseball_friend_intro
	_restore_touch_controls_after_reward_choice()
	_sync_onboarding_journey_surface()


func _should_play_purify_intro_spotlight() -> bool:
	if _purify_onboarding_intro_shown:
		return false
	if not _is_baseball_onboarding_run():
		return false
	return room_manager != null and room_manager.current_room_id == &"friend_1"


func _find_active_onboarding_friend() -> Node2D:
	if room_manager == null or room_manager.current_room == null:
		return null
	if not room_manager.current_room.has_method("get_active_friends"):
		return null
	var friends: Array = room_manager.current_room.call("get_active_friends")
	for friend: Node in friends:
		if friend is Node2D and is_instance_valid(friend):
			return friend as Node2D
	return null


func _play_purify_onboarding_spotlight(step_id: StringName, target: Node) -> void:
	if _purify_onboarding_active:
		return
	var target_2d := target as Node2D
	if target_2d == null or not is_instance_valid(target_2d):
		return
	if purify_onboarding_spotlight == null or not is_instance_valid(purify_onboarding_spotlight):
		return
	_purify_onboarding_active = true
	_sync_onboarding_journey_surface()
	if step_id == &"intro":
		_purify_onboarding_intro_shown = true
	elif step_id == &"groggy":
		_purify_onboarding_groggy_shown = true
	_paused_before_purify_onboarding = get_tree().paused
	_touch_controls_visible_before_purify_onboarding = touch_controls.visible if touch_controls != null else true
	_release_combat_touch_inputs()
	if touch_controls != null:
		touch_controls.visible = false
	get_tree().paused = true
	var message := PURIFY_ONBOARDING_GROGGY_MESSAGE if step_id == &"groggy" else PURIFY_ONBOARDING_INTRO_MESSAGE
	purify_onboarding_spotlight.show_step(
		step_id,
		message,
		target_2d,
		PURIFY_ONBOARDING_TARGET_SIZE,
		PURIFY_ONBOARDING_TARGET_OFFSET
	)
	await purify_onboarding_spotlight.dismissed
	_finish_purify_onboarding_spotlight()


func _finish_purify_onboarding_spotlight() -> void:
	if not _purify_onboarding_active:
		return
	_purify_onboarding_active = false
	if purify_onboarding_spotlight != null and is_instance_valid(purify_onboarding_spotlight):
		purify_onboarding_spotlight.dismiss()
	var tree := get_tree()
	if tree != null:
		tree.paused = _paused_before_purify_onboarding
	if touch_controls != null:
		touch_controls.visible = _touch_controls_visible_before_purify_onboarding
	_sync_onboarding_journey_surface()


func _is_purify_onboarding_spotlight_active() -> bool:
	return (
		_purify_onboarding_active
		or (
			purify_onboarding_spotlight != null
			and is_instance_valid(purify_onboarding_spotlight)
			and purify_onboarding_spotlight.is_active()
		)
	)


## 보스 등장 직전 인게임 대사 시퀀스를 재생한다(코루틴). 비트가 없으면 즉시 반환.
## pause/터치 컨트롤은 보상 선택과 동일 패턴으로 잠그고(_release/_hide), 종료 시 복원한다.
func _play_boss_intro(_boss_id: StringName) -> void:
	var first_shown := SaveManager.get_flag(PalaceBossIntro.FIRST_INTRO_FLAG)
	var beats := PalaceBossIntro.collect_beats(first_shown)
	if beats.is_empty():
		return
	var includes_first := PalaceBossIntro.includes_first_intro(first_shown)
	_boss_intro_active = true
	_paused_before_boss_intro = get_tree().paused
	_release_combat_touch_inputs()
	_hide_touch_controls_for_reward_choice()
	get_tree().paused = true
	_boss_intro_ui = HUB_DIALOGUE_SCENE.instantiate()
	_boss_intro_ui.name = "BossIntroDialogueUi"
	_boss_intro_ui.battle_mode = true  # add_child 전에 설정 — 학교 부수효과 격리
	_boss_intro_ui.layer = BOSS_INTRO_DIALOG_LAYER
	add_child(_boss_intro_ui)
	for beat: Dictionary in beats:
		if not is_instance_valid(_boss_intro_ui):
			break
		_set_encounter_beat(_boss_intro_ui, beat)
		await _boss_intro_ui.choice_selected
	# (f) 첫 조우 플래그는 전체 시퀀스 완료 후에만 set — 중도 이탈 시 다음 입장에 다시 재생.
	if includes_first:
		SaveManager.set_flag(PalaceBossIntro.FIRST_INTRO_FLAG, true)
	_finish_boss_intro()


## 보스 인트로 정리 — pause/터치 컨트롤 복원 + UI free. _exit_tree 안전 경로에서도 호출.
func _finish_boss_intro() -> void:
	if not _boss_intro_active:
		return
	_boss_intro_active = false
	if is_instance_valid(_boss_intro_ui):
		_boss_intro_ui.queue_free()
	_boss_intro_ui = null
	var tree := get_tree()
	if tree != null:
		tree.paused = _paused_before_boss_intro
	_restore_touch_controls_after_reward_choice()


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
	var tap_pos := Vector2.ZERO
	var mobile_runtime := _is_mobile_runtime()
	if mobile_runtime and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap_pos = (event as InputEventScreenTouch).position
	elif (
		not mobile_runtime
		and
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		tap_pos = (event as InputEventMouseButton).position
	else:
		return
	if _minimap_full:
		_set_minimap_full(false)
	elif _minimap.get_global_rect().has_point(tap_pos):
		_set_minimap_full(true)


func _set_minimap_full(expanded: bool) -> bool:
	if _minimap_full == expanded:
		return false
	_minimap_full = expanded
	_play_minimap_toggle_sfx()
	_apply_minimap_layout()
	minimap_expanded_changed.emit(_minimap_full)
	return true


func is_minimap_expanded() -> bool:
	return _minimap_full


func perform_uat_action(action_name: String) -> bool:
	match action_name:
		UAT_ACTION_MINIMAP_EXPAND:
			return _set_minimap_full(true)
		UAT_ACTION_SKIP_GUIDANCE:
			if ingame_control_onboarding == null or not ingame_control_onboarding.has_method("skip_guidance"):
				return false
			var was_active := bool(ingame_control_onboarding.call("is_active"))
			ingame_control_onboarding.call("skip_guidance")
			return was_active and not bool(ingame_control_onboarding.call("is_active"))
	return false


func _on_minimap_expanded_changed(expanded: bool) -> void:
	if ingame_control_onboarding != null and ingame_control_onboarding.has_method("record_action"):
		ingame_control_onboarding.call("record_action", &"minimap_expanded", {"expanded": expanded})


func _on_ingame_control_gate_released() -> void:
	var current_room := room_manager.current_room as StartRoom
	if current_room != null:
		current_room.set_tutorial_gate_active(false)


func _is_mobile_runtime() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func _play_minimap_toggle_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.UI_BUTTON_PRESS)


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
	if _room_fade_tween != null and _room_fade_tween.is_valid():
		_room_fade_tween.kill()
	_room_fade_tween = create_tween()
	_room_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_room_fade_processes_while_paused = true
	_room_fade_tween.tween_property(_fade_rect, "color:a", 0.0, 0.35)


func get_room_fade_snapshot() -> Dictionary:
	return {
		"alpha": _fade_rect.color.a if _fade_rect != null else 0.0,
		"processes_while_paused": _room_fade_processes_while_paused,
	}


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
	_exit_modal_from_pause_menu = false
	var force_lobby := _should_force_lobby_for_incomplete_onboarding_exit()
	_finish_all_onboarding_ui()
	if has_node("/root/GameManager"):
		GameManager.reset_session()
	if force_lobby:
		_return_to_lobby()
		return
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
	else:
		SceneTransition.go_to_day_lobby()


func _should_force_lobby_for_incomplete_onboarding_exit() -> bool:
	if not _is_baseball_onboarding_run():
		return false
	if has_node("/root/SaveManager") and SaveManager.get_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE):
		return false
	return true


func _return_to_lobby() -> void:
	if return_to_lobby_callable.is_valid():
		return_to_lobby_callable.call()
	else:
		SceneTransition.go_to_lobby()


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
	_finish_all_onboarding_ui()
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _restore_pause_after_exit_modal() -> void:
	if _exit_modal_from_pause_menu:
		_exit_modal_from_pause_menu = false
		_open_pause_modal()
		return
	get_tree().paused = _paused_before_exit_modal
	session_ui_root.set_status("일시정지" if get_tree().paused else "준비 완료")


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
