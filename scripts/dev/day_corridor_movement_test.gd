extends Node2D

signal dialogue_requested(payload: Dictionary)
signal maintenance_requested(payload: Dictionary)

const REFERENCE_VIEWPORT_SIZE := Vector2(960.0, 540.0)
const DIALOGUE_SPEAKER := "반 친구"
const DIALOGUE_LINES: Array[String] = [
	"낮엔 뛰지 말고, 얘기부터 하자.",
	"복도 끝 교실에 들르면 준비가 끝나.",
	"밤에 나가기 전에 여기서 필요한 얘기를 끝내자.",
]
const DIALOGUE_MEMORY_LINES: Array[String] = [
	"기억: 창밖으로 밀려드는 낮빛",
	"기억: 복도 끝 교실 문손잡이",
	"기억: 야자 시작 전의 짧은 정적",
]
const ROOM_LEFT := &"left"
const ROOM_RIGHT := &"right"
const EDGE_OUTER_LEFT := &"outer_left"
const EDGE_OUTER_RIGHT := &"outer_right"
const CHOICE_NEXT := &"next"
const CHOICE_CLOSE := &"close"
const TEST_ID_OPEN_DIALOGUE := "day_corridor.dialogue.open_button"
const TEST_ID_DIALOGUE_NEXT := "day_corridor.dialogue.next_button"
const TEST_ID_DIALOGUE_CLOSE := "day_corridor.dialogue.close_button"
const TEST_ID_EXIT_BUTTON := "day_corridor.exit_button"
const ACTION_OPEN_DIALOGUE := "day_corridor.dialogue.open"
const ACTION_DIALOGUE_NEXT := "day_corridor.dialogue.next"
const ACTION_DIALOGUE_CLOSE := "day_corridor.dialogue.close"
const ACTION_EXIT_TO_LOBBY := "day_corridor.exit_to_lobby"
const OBJECTIVE_TALK := "목표: 야구부 주장과 대화하고 밤의 궁으로 나갈 준비를 하자"
const OBJECTIVE_LOCKER := "목표: 복도 끝 사물함에서 기억 무기를 정비하자"
const RETURN_TO_LOBBY_MESSAGE := "로비로 돌아갈까요? 진행은 자동 저장됩니다"
const QUIT_GAME_MESSAGE := "게임을 종료할까요?"

@export var corridor_size := Vector2(2172.0, 720.0)
@export var floor_y := 616.0
@export var player_left_bound := 96.0
@export var player_right_bound := 2076.0
@export var talk_radius := 120.0
@export var background_asset_scale := 1.0
@export var character_asset_scale := 2.0
@export var character_walk_fps := 8.0
@export var character_idle_fps := 1.6
## 멈춤 상태 전용 idle 시트(없으면 걷기 시트 프레임으로 폴백).
@export var character_idle_texture: Texture2D
@export var character_idle_frames: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
@export var character_idle_bob_px := 2.0
@export var talk_target_texture: Texture2D
@export var talk_target_asset_scale := 2.0
@export var talk_target_idle_fps := 1.6
@export var dialogue_portrait_texture: Texture2D
@export var room_transition_fade_time := 0.18
@export var room_transition_spawn_inset := 320.0
@export var outer_edge_scene_transition_enabled := true

@onready var _background: Node2D = %Background
@onready var _school_bg_left: Sprite2D = %SchoolBgLeft
@onready var _school_bg_right: Sprite2D = %SchoolBgRight
@onready var _background_wash: Polygon2D = %BackgroundWash
@onready var _player: CharacterBody2D = %Player
@onready var _touch_controls: Node = %TouchControls
@onready var _camera: Camera2D = %Camera2D
@onready var _talk_target: Node2D = %TalkTarget
@onready var _talk_target_sprite: Sprite2D = %TalkTargetSprite
@onready var _day_character_root: Node2D = %DayCharacterRoot
@onready var _character_sprite: Sprite2D = %CharacterSprite
@onready var _interaction_prompt: Label = %InteractionPrompt
@onready var _talk_button_label: Label = %TalkButtonLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _hub_dialogue_ui: HubDialogueUi = %HubDialogueUi
@onready var _fade_overlay: ColorRect = %FadeOverlay
@onready var _exit_button: Button = %ExitButton
@onready var _confirm_modal: ConfirmModal = %ConfirmModal

var _dialogue_count := 0
var _dialogue_line_index := -1
var _was_dialogue_pressed := false
var _walk_elapsed := 0.0
var _idle_elapsed := 0.0
var _talk_target_elapsed := 0.0
var _character_base_position := Vector2.ZERO
var _walk_texture: Texture2D = null
var _walk_hframes := 0
var _faces_left := false
var _current_room_id := ROOM_LEFT
var _is_room_transitioning := false
var _last_maintenance_edge := &""
var _is_maintenance_requested := false
var return_to_lobby_callable: Callable
var quit_game_callable: Callable


func _ready() -> void:
	SceneTransition.configure_exit_requests()
	_disable_combat_output()
	_hide_player_default_visuals()
	_apply_nearest_texture_filter()
	_fit_character_to_asset_scale()
	_fit_talk_target_to_asset_scale()
	_restore_corridor_context()
	_apply_room_state()
	_hub_dialogue_ui.visible = false
	_hub_dialogue_ui.set_stage_row_visible(false)
	_hub_dialogue_ui.choice_selected.connect(_on_hub_dialogue_choice_selected)
	_update_objective_label()
	_interaction_prompt.visible = false
	_apply_ui_automation_metadata()
	PixelButtonStyle.apply(_exit_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(144.0, 50.0))
	_exit_button.pressed.connect(_request_return_to_lobby)
	_fit_camera_to_corridor_height()
	_clamp_player_to_corridor()
	_sync_camera()


func _process(delta: float) -> void:
	_update_talk_target_sprite(delta)
	if _confirm_modal.is_open():
		_player.velocity = Vector2.ZERO
		_update_character_sprite(delta)
		_sync_camera()
		return
	if _is_room_transitioning:
		_player.velocity = Vector2.ZERO
		_sync_camera()
		return
	if is_dialogue_ui_visible():
		_player.velocity = Vector2.ZERO
		_update_character_sprite(delta)
		_sync_camera()
		_update_interaction_prompt()
		_process_dialogue_input()
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


func get_background_game_tint() -> Color:
	return _school_bg_left.self_modulate


func get_background_wash_alpha() -> float:
	return _background_wash.color.a


func get_character_frame_count() -> int:
	return _get_character_frame_count()


func get_character_idle_frame_count() -> int:
	return character_idle_frames.size()


func get_current_room_id() -> StringName:
	return _current_room_id


func get_last_maintenance_edge() -> StringName:
	return _last_maintenance_edge


func is_room_transitioning() -> bool:
	return _is_room_transitioning


func are_runtime_sprites_nearest_filtered() -> bool:
	if _character_sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		return false
	if _talk_target_sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		return false
	for child: Node in _background.get_children():
		var sprite := child as Sprite2D
		if sprite != null and sprite.texture != null and sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			return false
	return true


func get_dialogue_count() -> int:
	return _dialogue_count


func get_talk_target_texture_path() -> String:
	if _talk_target_sprite.texture == null:
		return ""
	return _talk_target_sprite.texture.resource_path


func is_talk_target_visible() -> bool:
	return _talk_target.visible


func get_active_dialogue_line_index() -> int:
	return _dialogue_line_index


func get_active_dialogue_text() -> String:
	return _hub_dialogue_ui.get_dialogue_text()


func get_active_dialogue_memory_text() -> String:
	return _hub_dialogue_ui.get_memory_text()


func get_dialogue_choice_ids() -> Array[StringName]:
	return _hub_dialogue_ui.get_choice_ids()


func is_dialogue_ui_visible() -> bool:
	return _hub_dialogue_ui.visible


func is_touch_controls_visible() -> bool:
	return _touch_controls.visible


func get_objective_text() -> String:
	return _objective_label.text


func is_return_confirm_visible() -> bool:
	return _confirm_modal.is_open()


func get_return_confirm_message() -> String:
	return _confirm_modal.get_message_text()


func is_player_in_dialogue_range() -> bool:
	if not _talk_target.visible:
		return false
	return _player.global_position.distance_to(_talk_target.global_position) <= talk_radius


func update_room_transition_request() -> bool:
	if _is_room_transitioning or _is_maintenance_requested:
		return false
	if _current_room_id == ROOM_LEFT and _player.global_position.x <= player_left_bound and _player.velocity.x < 0.0:
		_request_locker_maintenance(EDGE_OUTER_LEFT)
		return true
	if _current_room_id == ROOM_LEFT and _player.global_position.x >= player_right_bound and _player.velocity.x > 0.0:
		_start_room_transition(ROOM_RIGHT)
		return true
	if _current_room_id == ROOM_RIGHT and _player.global_position.x <= player_left_bound and _player.velocity.x < 0.0:
		_start_room_transition(ROOM_LEFT)
		return true
	if _current_room_id == ROOM_RIGHT and _player.global_position.x >= player_right_bound and _player.velocity.x > 0.0:
		_request_locker_maintenance(EDGE_OUTER_RIGHT)
		return true
	return false


func is_dialogue_input_pressed() -> bool:
	if _touch_controls != null and _touch_controls.has_method("is_attack_pressed"):
		if bool(_touch_controls.is_attack_pressed()):
			return true
	return Input.is_physical_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)


func is_combat_output_disabled() -> bool:
	return _player.get_node_or_null("ProjectileLauncher") == null and is_equal_approx(float(_player.get("recoil_strength")), 0.0)


func perform_uat_action(action_name: String) -> bool:
	match action_name:
		ACTION_OPEN_DIALOGUE:
			if is_dialogue_ui_visible() or not is_player_in_dialogue_range():
				return false
			trigger_dialogue()
			return true
		ACTION_DIALOGUE_NEXT:
			if not is_dialogue_ui_visible() or not get_dialogue_choice_ids().has(CHOICE_NEXT):
				return false
			_hub_dialogue_ui.select_choice(CHOICE_NEXT)
			return true
		ACTION_DIALOGUE_CLOSE:
			if not is_dialogue_ui_visible() or not get_dialogue_choice_ids().has(CHOICE_CLOSE):
				return false
			_hub_dialogue_ui.select_choice(CHOICE_CLOSE)
			return true
		ACTION_EXIT_TO_LOBBY:
			_request_return_to_lobby()
			return true
		_:
			return false


func trigger_dialogue() -> void:
	if is_dialogue_ui_visible():
		_show_dialogue_line((_dialogue_line_index + 1) % DIALOGUE_LINES.size())
		return
	_open_dialogue_ui()
	_show_dialogue_line(0)


func close_dialogue() -> void:
	_hub_dialogue_ui.visible = false
	_touch_controls.visible = true
	_talk_button_label.visible = true
	_player.set_physics_process(true)
	_dialogue_line_index = -1
	_sync_talk_target_visibility()
	_update_objective_label()
	# The closing tap can reveal touch controls under the same held press.
	_was_dialogue_pressed = true
	_update_interaction_prompt()


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


func _disable_combat_output() -> void:
	_player.set("recoil_strength", 0.0)
	var launcher := _player.get_node_or_null("ProjectileLauncher")
	if launcher != null:
		_player.remove_child(launcher)
		launcher.queue_free()


func _hide_player_default_visuals() -> void:
	for child: Node in _player.get_children():
		if child == _day_character_root or child is CollisionShape2D:
			continue
		var item := child as CanvasItem
		if item != null:
			item.visible = false


func _apply_nearest_texture_filter() -> void:
	_character_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_talk_target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child: Node in _background.get_children():
		var item := child as CanvasItem
		if item != null:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _fit_character_to_asset_scale() -> void:
	if _walk_texture == null:
		_walk_texture = _character_sprite.texture
		_walk_hframes = _character_sprite.hframes
	if character_asset_scale > 0.0:
		_character_sprite.scale = Vector2(character_asset_scale, character_asset_scale)
		_character_sprite.position.y = -_get_character_frame_size().y * character_asset_scale * 0.5
	_character_base_position = _character_sprite.position


func _fit_talk_target_to_asset_scale() -> void:
	if talk_target_texture != null:
		_talk_target_sprite.texture = talk_target_texture
	var texture := _talk_target_sprite.texture
	if texture == null:
		return
	_talk_target_sprite.hframes = _get_square_sheet_hframes(texture)
	_talk_target_sprite.vframes = 1
	if talk_target_asset_scale > 0.0:
		_talk_target_sprite.scale = Vector2(talk_target_asset_scale, talk_target_asset_scale)
		_talk_target_sprite.position.y = -_get_talk_target_frame_size().y * talk_target_asset_scale * 0.5
	_talk_target_sprite.frame = 0


## 멈춤 시 idle 시트로 텍스처 스왑(정사각 프레임 가정 → hframes = 너비/높이).
func _use_idle_sheet() -> void:
	if character_idle_texture == null or _character_sprite.texture == character_idle_texture:
		return
	_character_sprite.texture = character_idle_texture
	_character_sprite.hframes = _get_square_sheet_hframes(character_idle_texture)
	_character_sprite.vframes = 1


## 이동 시 걷기 시트로 복귀.
func _use_walk_sheet() -> void:
	if _walk_texture == null or _character_sprite.texture == _walk_texture:
		return
	_character_sprite.texture = _walk_texture
	_character_sprite.hframes = maxi(1, _walk_hframes)
	_character_sprite.vframes = 1


func _apply_room_state() -> void:
	_school_bg_left.visible = _current_room_id == ROOM_LEFT
	_school_bg_right.visible = _current_room_id == ROOM_RIGHT
	_camera.limit_right = int(corridor_size.x)
	if _current_room_id != ROOM_LEFT:
		close_dialogue()
	_sync_talk_target_visibility()


func _sync_talk_target_visibility() -> void:
	_talk_target.visible = _current_room_id == ROOM_LEFT and not is_dialogue_ui_visible()


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
	_camera.reset_smoothing()


func _request_locker_maintenance(edge_id: StringName) -> void:
	if _is_maintenance_requested:
		return
	_is_maintenance_requested = true
	_last_maintenance_edge = edge_id
	_player.velocity = Vector2.ZERO
	SceneTransition.set_pending_day_corridor_context({
		SceneTransition.DAY_CORRIDOR_CONTEXT_ROOM_ID: _current_room_id,
		SceneTransition.DAY_CORRIDOR_CONTEXT_EDGE_ID: edge_id,
	})
	maintenance_requested.emit({
		"source": &"day_corridor",
		"edge": edge_id,
		"room_id": _current_room_id,
	})
	if outer_edge_scene_transition_enabled:
		var result := SceneTransition.go_to_locker_maintenance()
		if result != OK:
			_is_maintenance_requested = false


func _restore_corridor_context() -> void:
	var context := SceneTransition.get_pending_day_corridor_context()
	if context.is_empty():
		return
	var room_id := StringName(context.get(SceneTransition.DAY_CORRIDOR_CONTEXT_ROOM_ID, ROOM_LEFT))
	if room_id == ROOM_RIGHT:
		_current_room_id = ROOM_RIGHT
	else:
		_current_room_id = ROOM_LEFT

	var edge_id := StringName(context.get(SceneTransition.DAY_CORRIDOR_CONTEXT_EDGE_ID, &""))
	var spawn_x := player_left_bound + room_transition_spawn_inset
	if edge_id == EDGE_OUTER_RIGHT:
		spawn_x = player_right_bound - room_transition_spawn_inset
		_faces_left = true
	elif edge_id == EDGE_OUTER_LEFT:
		spawn_x = player_left_bound + room_transition_spawn_inset
		_faces_left = false
	_player.global_position = Vector2(spawn_x, floor_y)
	_player.velocity = Vector2.ZERO
	SceneTransition.clear_pending_day_corridor_context()


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
		_idle_elapsed += delta
		_use_idle_sheet()
		_character_sprite.frame = _get_character_idle_frame()
		_character_sprite.position.y = _character_base_position.y + _get_character_idle_bob_offset()
		return

	_idle_elapsed = 0.0
	_use_walk_sheet()
	_character_sprite.position = _character_base_position
	_walk_elapsed += delta
	_character_sprite.frame = int(_walk_elapsed * character_walk_fps) % _get_character_frame_count()


func _update_talk_target_sprite(delta: float) -> void:
	if not _talk_target.visible:
		return
	_talk_target_elapsed += delta
	_talk_target_sprite.frame = int(_talk_target_elapsed * talk_target_idle_fps) % _get_talk_target_frame_count()


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


func _get_talk_target_frame_size() -> Vector2:
	var texture := _talk_target_sprite.texture
	if texture == null:
		return Vector2.ZERO
	return Vector2(
		texture.get_width() / float(_talk_target_sprite.hframes),
		texture.get_height() / float(_talk_target_sprite.vframes)
	)


func _get_talk_target_frame_count() -> int:
	return maxi(1, _talk_target_sprite.hframes * _talk_target_sprite.vframes)


func _get_square_sheet_hframes(texture: Texture2D) -> int:
	var height := texture.get_height()
	if height <= 0:
		return 1
	return maxi(1, int(round(texture.get_width() / float(height))))


func _get_character_idle_frame() -> int:
	if character_idle_frames.is_empty():
		return 0
	var index := int(_idle_elapsed * character_idle_fps) % character_idle_frames.size()
	return clampi(character_idle_frames[index], 0, _get_character_frame_count() - 1)


func _get_character_idle_bob_offset() -> float:
	if character_idle_bob_px <= 0.0 or character_idle_frames.size() < 2:
		return 0.0
	return -sin(_idle_elapsed * TAU * character_idle_fps * 0.5) * character_idle_bob_px


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
	_interaction_prompt.visible = not is_dialogue_ui_visible() and is_player_in_dialogue_range()


func _process_dialogue_input() -> void:
	var pressed := is_dialogue_input_pressed()
	if is_dialogue_ui_visible():
		if _is_dialogue_close_input_pressed():
			close_dialogue()
		_was_dialogue_pressed = pressed
		return
	if pressed and not _was_dialogue_pressed and is_player_in_dialogue_range():
		trigger_dialogue()
	_was_dialogue_pressed = pressed


func _open_dialogue_ui() -> void:
	_hub_dialogue_ui.visible = true
	_touch_controls.visible = false
	_talk_button_label.visible = false
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_update_character_sprite(0.0)
	_sync_talk_target_visibility()


func _show_dialogue_line(line_index: int) -> void:
	_dialogue_count += 1
	_dialogue_line_index = posmod(line_index, DIALOGUE_LINES.size())
	_update_objective_label()
	_hub_dialogue_ui.set_dialogue(
		DIALOGUE_SPEAKER,
		DIALOGUE_LINES[_dialogue_line_index],
		DIALOGUE_MEMORY_LINES[_dialogue_line_index],
		HubDialogueUi.PORTRAIT_COLOR,
		dialogue_portrait_texture
	)
	var is_last_line := _dialogue_line_index >= DIALOGUE_LINES.size() - 1
	_hub_dialogue_ui.set_choices([
		{
			"id": CHOICE_CLOSE if is_last_line else CHOICE_NEXT,
			"text": HubDialogueUi.CONTINUE_HINT_TOUCH,
			"tap_to_continue": true,
			"test_id": TEST_ID_DIALOGUE_CLOSE if is_last_line else TEST_ID_DIALOGUE_NEXT,
			"uat_action": ACTION_DIALOGUE_CLOSE if is_last_line else ACTION_DIALOGUE_NEXT,
		},
	])
	dialogue_requested.emit({
		"count": _dialogue_count,
		"line": DIALOGUE_LINES[_dialogue_line_index],
		"line_index": _dialogue_line_index,
		"memory": DIALOGUE_MEMORY_LINES[_dialogue_line_index],
		"source": &"day_corridor",
	})


func _on_hub_dialogue_choice_selected(choice_id: StringName) -> void:
	match choice_id:
		CHOICE_NEXT:
			trigger_dialogue()
		CHOICE_CLOSE:
			close_dialogue()


func _update_objective_label() -> void:
	if _objective_label == null:
		return
	_objective_label.text = OBJECTIVE_LOCKER if _dialogue_count > 0 else OBJECTIVE_TALK


func _is_dialogue_close_input_pressed() -> bool:
	return Input.is_action_pressed(&"ui_cancel") or Input.is_key_pressed(KEY_ESCAPE)


func _apply_ui_automation_metadata() -> void:
	var attack_button := _touch_controls.get_node_or_null("AttackButton")
	if attack_button != null:
		attack_button.set_meta("test_id", TEST_ID_OPEN_DIALOGUE)
		attack_button.set_meta("uat_action", ACTION_OPEN_DIALOGUE)
	_exit_button.set_meta("test_id", TEST_ID_EXIT_BUTTON)
	_exit_button.set_meta("uat_action", ACTION_EXIT_TO_LOBBY)


func _handle_back_request() -> void:
	if _confirm_modal.is_open():
		return
	if is_dialogue_ui_visible():
		close_dialogue()
		return
	_request_return_to_lobby()


func _request_return_to_lobby() -> void:
	if _confirm_modal.is_open():
		return
	_player.velocity = Vector2.ZERO
	_confirm_modal.open(
		RETURN_TO_LOBBY_MESSAGE,
		Callable(self, "_return_to_lobby"),
		Callable()
	)


func _return_to_lobby() -> void:
	if return_to_lobby_callable.is_valid():
		return_to_lobby_callable.call()
	else:
		SceneTransition.go_to_lobby()


func _request_quit_game() -> void:
	if _confirm_modal.is_open():
		return
	_player.velocity = Vector2.ZERO
	_confirm_modal.open(
		QUIT_GAME_MESSAGE,
		Callable(self, "_quit_game"),
		Callable()
	)


func _quit_game() -> void:
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
