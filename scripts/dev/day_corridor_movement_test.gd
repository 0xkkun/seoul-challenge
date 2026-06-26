extends Node2D

signal dialogue_requested(payload: Dictionary)

const REFERENCE_VIEWPORT_SIZE := Vector2(960.0, 540.0)
const DIALOGUE_LINES: Array[String] = [
	"친구: 낮엔 뛰지 말고, 얘기부터 하자.",
	"친구: 복도 끝 교실에 들르면 준비가 끝나.",
]

@export var corridor_size := Vector2(4352.0, 720.0)
@export var floor_y := 514.0
@export var player_left_bound := 96.0
@export var player_right_bound := 4256.0
@export var talk_radius := 120.0

@onready var _player: CharacterBody2D = %Player
@onready var _touch_controls: Node = %TouchControls
@onready var _camera: Camera2D = %Camera2D
@onready var _talk_target: Node2D = %TalkTarget
@onready var _interaction_prompt: Label = %InteractionPrompt
@onready var _dialogue_state: Label = %DialogueState

var _dialogue_count := 0
var _was_dialogue_pressed := false


func _ready() -> void:
	_disable_combat_output()
	_hide_player_placeholder()
	_dialogue_state.visible = false
	_interaction_prompt.visible = false
	_fit_camera_to_corridor_height()
	_clamp_player_to_corridor()
	_sync_camera()


func _process(_delta: float) -> void:
	_clamp_player_to_corridor()
	_sync_camera()
	_update_interaction_prompt()
	_process_dialogue_input()


func get_reference_viewport_size() -> Vector2:
	return REFERENCE_VIEWPORT_SIZE


func get_corridor_bounds() -> Rect2:
	return Rect2(Vector2.ZERO, corridor_size)


func get_floor_y() -> float:
	return floor_y


func get_reference_visible_world_size() -> Vector2:
	return Vector2(
		REFERENCE_VIEWPORT_SIZE.x / _camera.zoom.x,
		REFERENCE_VIEWPORT_SIZE.y / _camera.zoom.y
	)


func get_dialogue_count() -> int:
	return _dialogue_count


func is_player_in_dialogue_range() -> bool:
	return _player.global_position.distance_to(_talk_target.global_position) <= talk_radius


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


func _sync_camera() -> void:
	var half_view := _get_visible_world_size() * 0.5
	_camera.global_position = Vector2(
		_center_or_clamp(_player.global_position.x, half_view.x, corridor_size.x),
		_center_or_clamp(corridor_size.y * 0.5, half_view.y, corridor_size.y)
	)


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
