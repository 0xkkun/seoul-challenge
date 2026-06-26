extends Node2D

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const POOLED_MARKER_SCENE = preload("res://scenes/interactables/sample_pooled_marker.tscn")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

const RUN_LAYOUT_SEED := 40
const RUN_LAYOUT_ROOM_COUNT := 15
const START_ROOM_SCENE_PATH := "res://scenes/interactables/start_room.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"
const EVENT_ROOM_SCENE_PATH := "res://scenes/interactables/rescue_room.tscn"
const TREASURE_ROOM_SCENE_PATH := "res://scenes/interactables/treasure_room.tscn"
const FINAL_ROOM_SCENE_PATH := "res://scenes/interactables/boss_room.tscn"
const ABANDON_RUN_MESSAGE := "런을 포기할까요? 이번 밤 보상은 사라지고 영구 재화는 유지됩니다"
const QUIT_GAME_MESSAGE := "게임을 종료할까요?"

@onready var world_layer: Node2D = $WorldLayer
@onready var room_layer: Node2D = %RoomLayer
@onready var actor: Node2D = %Player
@onready var actor_layer: Node2D = $ActorLayer
@onready var interactable_layer: Node2D = %InteractableLayer
@onready var sample_interactable: Node = %SampleInteractable
@onready var pooled_object_layer: Node2D = %PooledObjectLayer
@onready var interaction_system: Node = %InteractionSystem
@onready var room_manager: RoomManager = %RoomManager
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


func _ready() -> void:
	SceneTransition.configure_exit_requests()
	_apply_render_layers()
	if not GameManager.is_session_active():
		GameManager.start_session({"source": "session_root"})
	PoolManager.register_scene(&"sample_marker", POOLED_MARKER_SCENE, 1, pooled_object_layer)
	interaction_system.configure(actor, interactable_layer)
	_configure_player_camera()
	room_manager.room_changed.connect(_on_room_changed)
	room_manager.configure(_build_run_layout(), room_layer, actor)
	room_manager.start_layout()
	_minimap.configure_from_manager(room_manager)
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


func _exit_tree() -> void:
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
	var generator := RoomLayoutGenerator.new()
	generator.start_scene_path = START_ROOM_SCENE_PATH
	generator.combat_scene_path = COMBAT_ROOM_SCENE_PATH
	generator.event_scene_path = EVENT_ROOM_SCENE_PATH
	generator.treasure_scene_path = TREASURE_ROOM_SCENE_PATH
	generator.final_scene_path = FINAL_ROOM_SCENE_PATH
	return generator.generate(RUN_LAYOUT_SEED, {"room_count": RUN_LAYOUT_ROOM_COUNT})


func finish_session() -> Dictionary:
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
		"friends_purified": 0,
	}
	GameManager.finish_session(result)
	session_ui_root.show_summary(result)
	return result


func is_exit_confirm_visible() -> bool:
	return _confirm_modal.is_open()


func get_exit_confirm_message() -> String:
	return _confirm_modal.get_message_text()


func _on_interaction_triggered(_source: Node, _target: Node) -> void:
	completed_interactions += 1
	session_ui_root.set_status("Interaction complete")
	session_ui_root.set_interaction_count(completed_interactions)
	EventBus.emit_interaction_completed({"count": completed_interactions})
	spawn_sample_marker()


func _on_pause_requested() -> void:
	get_tree().paused = true
	session_ui_root.set_status("Paused")


func _on_resume_requested() -> void:
	get_tree().paused = false
	session_ui_root.set_status("Ready")


func _on_finish_requested() -> void:
	_request_abandon_run()


func _on_return_requested() -> void:
	get_tree().paused = false
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
	else:
		SceneTransition.go_to_lobby()


func _on_retry_requested() -> void:
	get_tree().paused = false
	_handoff_session_on_exit = true
	var config := {"source": "session_result_retry"}
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
		actor.global_position = current_room.global_position + Vector2(-RoomPalette.ROOM_HALF_SIZE.x + 140.0, 0.0)
	_connect_boss_room(current_room)


func _connect_boss_room(room: Node) -> void:
	if room == null or not room.has_signal("boss_spawn_requested"):
		return
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
		room.call("complete_boss_encounter")


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
	session_ui_root.set_status("포기 확인")
	_confirm_modal.open(
		ABANDON_RUN_MESSAGE,
		Callable(self, "_abandon_run_to_lobby"),
		Callable(self, "_restore_pause_after_exit_modal"),
		true
	)


func _abandon_run_to_lobby() -> void:
	get_tree().paused = false
	if has_node("/root/GameManager"):
		GameManager.reset_session()
	if return_to_school_callable.is_valid():
		return_to_school_callable.call()
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
	get_tree().paused = false
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _restore_pause_after_exit_modal() -> void:
	get_tree().paused = _paused_before_exit_modal
	session_ui_root.set_status("Paused" if get_tree().paused else "Ready")


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
