extends Node

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const DAY_LOBBY_SCENE := "res://scenes/dev/day_corridor_movement_test.tscn"
const LOCKER_MAINTENANCE_SCENE := "res://scenes/ui/locker_maintenance.tscn"
const NIGHT_MAP_SELECT_SCENE := "res://scenes/ui/night_map_select.tscn"
const SESSION_SCENE := "res://scenes/session/session_root.tscn"
const RUN_CONFIG_SELECTED_WEAPON_ID := "selected_weapon_id"
const RUN_CONFIG_LAYOUT_SEED := "layout_seed"
const DAY_CORRIDOR_CONTEXT_ROOM_ID := "room_id"
const DAY_CORRIDOR_CONTEXT_EDGE_ID := "edge"
const FADE_SECONDS := 0.22
const SAVED_INDICATOR_SECONDS := 1.1

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)

var last_requested_scene := ""
var _is_transitioning := false
var _overlay_layer: CanvasLayer
var _fade_rect: ColorRect
var _saved_label: Label
var _saved_generation := 0
var _pending_run_config: Dictionary = {}
var _pending_day_corridor_context: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	configure_exit_requests()
	_ensure_overlay()


func go_to_lobby() -> Error:
	clear_pending_run_config()
	clear_pending_day_corridor_context()
	last_requested_scene = LOBBY_SCENE
	return _change_scene(LOBBY_SCENE)


func go_to_day_lobby() -> Error:
	clear_pending_run_config()
	last_requested_scene = DAY_LOBBY_SCENE
	return _change_scene(DAY_LOBBY_SCENE)


func go_to_day() -> Error:
	return go_to_day_lobby()


func go_to_locker_maintenance() -> Error:
	last_requested_scene = LOCKER_MAINTENANCE_SCENE
	return _change_scene(LOCKER_MAINTENANCE_SCENE)


func go_to_night_map_select() -> Error:
	last_requested_scene = NIGHT_MAP_SELECT_SCENE
	return _change_scene(NIGHT_MAP_SELECT_SCENE)


func start_session(config: Dictionary = {}) -> Error:
	if get_tree() == null:
		return ERR_UNCONFIGURED
	if _is_transitioning:
		return ERR_BUSY
	last_requested_scene = SESSION_SCENE
	_play_session_transition_sfx()
	if has_node("/root/GameManager"):
		GameManager.start_session(config)
	return _change_scene(SESSION_SCENE)


func get_lobby_scene_path() -> String:
	return LOBBY_SCENE


func get_day_lobby_scene_path() -> String:
	return DAY_LOBBY_SCENE


func get_day_scene_path() -> String:
	return get_day_lobby_scene_path()


func get_locker_maintenance_scene_path() -> String:
	return LOCKER_MAINTENANCE_SCENE


func get_night_map_select_scene_path() -> String:
	return NIGHT_MAP_SELECT_SCENE


func get_session_scene_path() -> String:
	return SESSION_SCENE


func set_pending_run_config(config: Dictionary) -> void:
	_pending_run_config = config.duplicate(true)


func merge_pending_run_config(config: Dictionary) -> void:
	for key: Variant in config.keys():
		_pending_run_config[key] = config[key]


func get_pending_run_config() -> Dictionary:
	return _pending_run_config.duplicate(true)


func clear_pending_run_config() -> void:
	_pending_run_config.clear()


func set_pending_day_corridor_context(context: Dictionary) -> void:
	_pending_day_corridor_context = context.duplicate(true)


func get_pending_day_corridor_context() -> Dictionary:
	return _pending_day_corridor_context.duplicate(true)


func clear_pending_day_corridor_context() -> void:
	_pending_day_corridor_context.clear()


func is_transitioning() -> bool:
	return _is_transitioning


func is_saved_indicator_visible() -> bool:
	return _saved_label != null and _saved_label.visible


func configure_exit_requests() -> void:
	if get_tree() == null:
		return
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	DisplayServer.window_set_window_event_callback(_on_window_event)


func save_profile_snapshot() -> void:
	if has_node("/root/SaveManager"):
		SaveManager.save_profile(SaveManager.load_profile())


func quit_game(exit_code: int = 0) -> void:
	save_profile_snapshot()
	if get_tree() != null:
		get_tree().quit(exit_code)


func _change_scene(scene_path: String) -> Error:
	if get_tree() == null:
		return ERR_UNCONFIGURED
	if _is_transitioning:
		return ERR_BUSY
	_is_transitioning = true
	save_profile_snapshot()
	_ensure_overlay()
	transition_started.emit(scene_path)
	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_saved_label.visible = false
	if FADE_SECONDS <= 0.0:
		return _change_scene_after_fade(scene_path)
	var tween := create_tween()
	tween.tween_property(_fade_rect, ^"color:a", 1.0, FADE_SECONDS)
	tween.tween_callback(_change_scene_after_fade.bind(scene_path))
	return OK


func _play_session_transition_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.stop_bgm()
		AudioManager.play_random_session_transition_sfx()


func _change_scene_after_fade(scene_path: String) -> Error:
	var tree := get_tree()
	if tree == null:
		_finish_transition(scene_path)
		return ERR_UNCONFIGURED
	var callback := _on_scene_changed.bind(scene_path)
	tree.scene_changed.connect(callback, CONNECT_ONE_SHOT)
	var error := tree.change_scene_to_file(scene_path)
	if error != OK:
		if tree.scene_changed.is_connected(callback):
			tree.scene_changed.disconnect(callback)
		_finish_failed_transition(scene_path)
	return error


func _on_scene_changed(scene_path: String) -> void:
	_show_saved_indicator()
	if FADE_SECONDS <= 0.0:
		_fade_rect.color.a = 0.0
		_finish_transition(scene_path)
		return
	var tween := create_tween()
	tween.tween_property(_fade_rect, ^"color:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_finish_transition.bind(scene_path))


func _finish_transition(scene_path: String) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit(scene_path)


func _finish_failed_transition(scene_path: String) -> void:
	_fade_rect.color.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	transition_finished.emit(scene_path)


func _ensure_overlay() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "TransitionOverlay"
	_overlay_layer.layer = 230
	add_child(_overlay_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.anchor_right = 1.0
	_fade_rect.anchor_bottom = 1.0
	_fade_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_fade_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay_layer.add_child(_fade_rect)

	_saved_label = Label.new()
	_saved_label.name = "SavedIndicator"
	_saved_label.anchor_left = 1.0
	_saved_label.anchor_right = 1.0
	_saved_label.offset_left = -150.0
	_saved_label.offset_top = 12.0
	_saved_label.offset_right = -16.0
	_saved_label.offset_bottom = 44.0
	_saved_label.text = "저장 완료"
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_saved_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_saved_label.add_theme_font_size_override("font_size", 18)
	_saved_label.add_theme_color_override("font_color", Color("#bff7d0"))
	_saved_label.visible = false
	_overlay_layer.add_child(_saved_label)


func _show_saved_indicator() -> void:
	_saved_generation += 1
	var generation := _saved_generation
	_saved_label.visible = true
	if get_tree() == null:
		return
	var timer := get_tree().create_timer(SAVED_INDICATOR_SECONDS)
	timer.timeout.connect(_hide_saved_indicator.bind(generation), CONNECT_ONE_SHOT)


func _hide_saved_indicator(generation: int) -> void:
	if generation == _saved_generation and _saved_label != null:
		_saved_label.visible = false


func _on_window_event(event: int) -> void:
	if get_tree() == null:
		return
	match event:
		DisplayServer.WINDOW_EVENT_CLOSE_REQUEST:
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
		DisplayServer.WINDOW_EVENT_GO_BACK_REQUEST:
			get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)
