extends Node2D

signal dialogue_requested(payload: Dictionary)

const REFERENCE_VIEWPORT_SIZE := Vector2(960.0, 540.0)
const DIALOGUE_LINES: Array[String] = [
	"친구: 낮엔 뛰지 말고, 얘기부터 하자.",
	"친구: 복도 끝 교실에 들르면 준비가 끝나.",
]
const ROOM_LEFT := &"left"
const ROOM_RIGHT := &"right"

@export var corridor_size := Vector2(2172.0, 720.0)
@export var floor_y := 616.0
@export var player_left_bound := 96.0
@export var player_right_bound := 2076.0
@export var talk_radius := 120.0
@export var background_asset_scale := 1.0
@export var character_asset_scale := 2.0
@export var character_walk_fps := 8.0
@export var room_transition_fade_time := 0.18
@export var room_transition_spawn_inset := 320.0

@onready var _background: Node2D = %Background
@onready var _school_bg_left: Sprite2D = %SchoolBgLeft
@onready var _school_bg_right: Sprite2D = %SchoolBgRight
@onready var _player: CharacterBody2D = %Player
@onready var _touch_controls: Node = %TouchControls
@onready var _camera: Camera2D = %Camera2D
@onready var _talk_target: Node2D = %TalkTarget
@onready var _character_sprite: Sprite2D = %CharacterSprite
@onready var _interaction_prompt: Label = %InteractionPrompt
@onready var _dialogue_state: Label = %DialogueState
@onready var _fade_overlay: ColorRect = %FadeOverlay

var _dialogue_count := 0
var _was_dialogue_pressed := false
var _walk_elapsed := 0.0
var _faces_left := false
var _current_room_id := ROOM_LEFT
var _is_room_transitioning := false


func _ready() -> void:
	_disable_combat_output()
	_hide_player_placeholder()
	_apply_nearest_texture_filter()
	_fit_character_to_asset_scale()
	_apply_room_state()
	_dialogue_state.visible = false
	_interaction_prompt.visible = false
	_fit_camera_to_corridor_height()
	_clamp_player_to_corridor()
	_sync_camera()


func _process(delta: float) -> void:
	if _is_room_transitioning:
		_player.velocity = Vector2.ZERO
		_sync_camera()
		return
	update_room_transition_request()
	_clamp_player_to_corridor()
	_update_character_sprite(delta)
	_sync_camera()
	_update_interaction_prompt()
	_process_dialogue_input()


func get_reference_viewport_size() -> Vector2:
	return REFERENCE_VIEWPORT_SIZE


func get_corridor_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, corridor_size)


func get_floor_y() -> float:
	return floor_y


func get_player_left_bound() -> float:
	return player_left_bound


func get_player_right_bound() -> float:
	return player_right_bound


func get_reference_visible_world_size() -> Vector2:
	return Vector2(
		REFERENCE_VIEWPORT_SIZE.x / _camera.zoom.x,
		REFERENCE_VIEWPORT_SIZE.y / _camera.zoom.y
	)


func get_background_to_character_scale_ratio() -> float:
	if character_asset_scale <= 0.0:
		return 0.0
	return background_asset_scale / character_asset_scale


func get_background_asset_scale() -> float:
	return background_asset_scale


func get_character_asset_scale() -> float:
	return character_asset_scale


func get_character_frame_count() -> int:
	return _get_character_frame_count()


func get_current_room_id() -> StringName:
	return _current_room_id


func is_room_transitioning() -> bool:
	return _is_room_transitioning


func are_runtime_sprites_nearest_filtered() -> bool:
	if _character_sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		return false
	for child: Node in _background.get_children():
		var item := child as CanvasItem
		if item != null and item.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			return false
	return true


func get_dialogue_count() -> int:
	return _dialogue_count


func is_player_in_dialogue_range() -> bool:
	if not _talk_target.visible:
		return false
	return _player.global_position.distance_to(_talk_target.global_position) <= talk_radius


func update_room_transition_request() -> bool:
	if _is_room_transitioning:
		return false
	if _current_room_id == ROOM_LEFT and _player.global_position.x >= player_right_bound and _player.velocity.x > 0.0:
		_start_room_transition(ROOM_RIGHT)
		return true
	if _current_room_id == ROOM_RIGHT and _player.global_position.x <= player_left_bound and _player.velocity.x < 0.0:
		_start_room_transition(ROOM_LEFT)
		return true
	return false


func is_dialogue_input_pressed() -> bool:
	if _touch_controls != null and _touch_controls.has_method("is_attack_pressed"):
		if bool(_touch_controls.is_attack_pressed()):
			return true
	return Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)


func is_combat_output_disabled() -> bool:
	return _player.get_node_or_null("ProjectileLauncher") == null and is_equal_approx(float(_player.get("recoil_strength")), 0.0)


func trigger_dialogue() -> void:
	_dialogue_count += 1
	var line_index := (_dialogue_count - 1) % DIALOGUE_LINES.size()
	_dialogue_state.text = DIALOGUE_LINES[line_index]
	_dialogue_state.visible = true
	dialogue_requested.emit({
		"count": _dialogue_count,
		"line": _dialogue_state.text,
		"source": &"day_corridor",
	})


func _disable_combat_output() -> void:
	_player.set("recoil_strength", 0.0)
	var launcher := _player.get_node_or_null("ProjectileLauncher")
	if launcher != null:
		_player.remove_child(launcher)
		launcher.queue_free()


func _hide_player_placeholder() -> void:
	var placeholder := _player.get_node_or_null("Placeholder")
	if placeholder != null:
		placeholder.visible = false


func _apply_nearest_texture_filter() -> void:
	_character_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child: Node in _background.get_children():
		var item := child as CanvasItem
		if item != null:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _fit_character_to_asset_scale() -> void:
	if character_asset_scale <= 0.0:
		return
	_character_sprite.scale = Vector2(character_asset_scale, character_asset_scale)
	_character_sprite.position.y = -_get_character_frame_size().y * character_asset_scale * 0.5


func _apply_room_state() -> void:
	_school_bg_left.visible = _current_room_id == ROOM_LEFT
	_school_bg_right.visible = _current_room_id == ROOM_RIGHT
	_talk_target.visible = _current_room_id == ROOM_LEFT
	_camera.limit_right = int(corridor_size.x)


func _start_room_transition(target_room_id: StringName) -> void:
	if target_room_id != ROOM_LEFT and target_room_id != ROOM_RIGHT:
		return
	_player.velocity = Vector2.ZERO
	if room_transition_fade_time <= 0.0:
		_finish_room_transition(target_room_id)
		return
	_is_room_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_overlay, ^"color:a", 1.0, room_transition_fade_time)
	tween.tween_callback(_finish_room_transition.bind(target_room_id))
	tween.tween_property(_fade_overlay, ^"color:a", 0.0, room_transition_fade_time)
	tween.tween_callback(func() -> void:
		_is_room_transitioning = false
	)


func _finish_room_transition(target_room_id: StringName) -> void:
	_current_room_id = target_room_id
	_apply_room_state()
	var spawn_x := player_left_bound + room_transition_spawn_inset
	if target_room_id == ROOM_LEFT:
		spawn_x = player_right_bound - room_transition_spawn_inset
		_faces_left = false
	else:
		_faces_left = true
	_player.global_position = Vector2(spawn_x, floor_y)
	_player.velocity = Vector2.ZERO
	_character_sprite.flip_h = _faces_left
	_character_sprite.frame = 0
	_sync_camera()


func _fit_camera_to_corridor_height() -> void:
	if corridor_size.y <= 0.0:
		return
	var zoom := REFERENCE_VIEWPORT_SIZE.y / corridor_size.y
	_camera.zoom = Vector2(zoom, zoom)


func _clamp_player_to_corridor() -> void:
	var previous_x := _player.global_position.x
	_player.global_position = Vector2(
		clampf(_player.global_position.x, player_left_bound, player_right_bound),
		floor_y
	)
	if not is_equal_approx(previous_x, _player.global_position.x):
		_player.velocity.x = 0.0
	_player.velocity.y = 0.0


func _update_character_sprite(delta: float) -> void:
	var velocity_x := _player.velocity.x
	if velocity_x < -1.0:
		_faces_left = true
	elif velocity_x > 1.0:
		_faces_left = false
	_character_sprite.flip_h = _faces_left

	if absf(velocity_x) <= 1.0:
		_walk_elapsed = 0.0
		_character_sprite.frame = 0
		return

	_walk_elapsed += delta
	_character_sprite.frame = int(_walk_elapsed * character_walk_fps) % _get_character_frame_count()


func _sync_camera() -> void:
	var half_view := _get_visible_world_size() * 0.5
	_camera.global_position = Vector2(
		_center_or_clamp(_player.global_position.x, half_view.x, corridor_size.x),
		_center_or_clamp(corridor_size.y * 0.5, half_view.y, corridor_size.y)
	)


func _get_character_frame_size() -> Vector2:
	var texture := _character_sprite.texture
	if texture == null:
		return Vector2.ZERO
	return Vector2(
		texture.get_width() / float(_character_sprite.hframes),
		texture.get_height() / float(_character_sprite.vframes)
	)


func _get_character_frame_count() -> int:
	return maxi(1, _character_sprite.hframes * _character_sprite.vframes)


func _get_visible_world_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = REFERENCE_VIEWPORT_SIZE
	return Vector2(
		viewport_size.x / _camera.zoom.x,
		viewport_size.y / _camera.zoom.y
	)


func _center_or_clamp(value: float, half_view: float, world_size: float) -> float:
	if world_size <= half_view * 2.0:
		return world_size * 0.5
	return clampf(value, half_view, world_size - half_view)


func _update_interaction_prompt() -> void:
	_interaction_prompt.visible = is_player_in_dialogue_range()


func _process_dialogue_input() -> void:
	var pressed := is_dialogue_input_pressed()
	if pressed and not _was_dialogue_pressed and is_player_in_dialogue_range():
		trigger_dialogue()
	_was_dialogue_pressed = pressed
