extends Node2D

const POOLED_MARKER_SCENE = preload("res://scenes/interactables/sample_pooled_marker.tscn")
const GYEONGBOKGUNG_LAYOUT = preload("res://resources/layouts/gyeongbokgung.tres")
const BOSS_SCENE = preload("res://scenes/enemies/boss.tscn")
const RoomPalette = preload("res://scripts/constants/room_palette.gd")

@onready var actor: Node2D = %Player
@onready var room_layer: Node = %RoomLayer
@onready var interactable_layer: Node = %InteractableLayer
@onready var sample_interactable: Node = %SampleInteractable
@onready var pooled_object_layer: Node = %PooledObjectLayer
@onready var interaction_system: Node = %InteractionSystem
@onready var room_manager: RoomManager = %RoomManager
@onready var session_ui_root: CanvasLayer = %SessionUIRoot
@onready var player_camera: Camera2D = %PlayerCamera
@onready var _fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var _minimap: Control = $MinimapLayer/Minimap

var completed_interactions := 0
var return_to_school_callable: Callable
var retry_session_callable: Callable
var _handoff_session_on_exit := false
var _active_boss: Node = null
var _minimap_full := false


func _ready() -> void:
	if not GameManager.is_session_active():
		GameManager.start_session({"source": "session_root"})
	PoolManager.register_scene(&"sample_marker", POOLED_MARKER_SCENE, 1, pooled_object_layer)
	interaction_system.configure(actor, interactable_layer)
	_configure_player_camera()
	room_manager.room_changed.connect(_on_room_changed)
	room_manager.configure(GYEONGBOKGUNG_LAYOUT, room_layer, actor)
	room_manager.start_layout()
	_minimap.configure_from_manager(room_manager)
	sample_interactable.interaction_triggered.connect(_on_interaction_triggered)
	session_ui_root.pause_requested.connect(_on_pause_requested)
	session_ui_root.resume_requested.connect(_on_resume_requested)
	session_ui_root.finish_requested.connect(_on_finish_requested)
	session_ui_root.return_requested.connect(_on_return_requested)
	session_ui_root.retry_requested.connect(_on_retry_requested)


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
	finish_session()


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
	var half := RoomPalette.ROOM_HALF_SIZE
	var wall: float = RoomPalette.WALL_THICKNESS
	player_camera.limit_left = int(floor(-half.x - wall))
	player_camera.limit_top = int(floor(-half.y - wall))
	player_camera.limit_right = int(ceil(half.x + wall))
	player_camera.limit_bottom = int(ceil(half.y + wall))
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
	if not room_manager.is_current_room_cleared():
		return false
	return room_manager.layout.get_next_room_id(room_manager.current_room_id, room_manager.cleared_room_ids) == &""


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
