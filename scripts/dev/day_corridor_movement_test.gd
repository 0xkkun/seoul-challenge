extends Node2D

signal dialogue_requested(payload: Dictionary)
signal maintenance_requested(payload: Dictionary)

const REFERENCE_VIEWPORT_SIZE := Vector2(960.0, 540.0)
# people2 대사/기억은 DaySchoolRumors 데이터 모듈에서 진행도 tier로 선택한다 (Issue #202).
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
const ACTION_DISMISS_UNLOCK := "day_corridor.dialogue.dismiss_unlock"
const ACTION_EXIT_TO_LOBBY := "day_corridor.exit_to_lobby"
const OBJECTIVE_TALK := "목표: 야구부 주장과 이야기하고, 밤의 궁으로 갈 준비를 하자"
const OBJECTIVE_LOCKER := "목표: 복도 끝 사물함에서 장비를 챙기자"
const OBJECTIVE_BASEBALL_REWARD := "목표: 야구부 주장에게 돌아가 배트와 단서를 받자"
const OBJECTIVE_REENTER_GYEONGBOKGUNG := "목표: 복도 끝 사물함에서 배트를 챙기고 경복궁으로 다시 가자"
const OBJECTIVE_BOSS_RESULT_REPORT := "목표: 야구부 주장에게 도깨비왕의 결말을 전하자"
const OBJECTIVE_BOSS_RESULT_ACKNOWLEDGED := "목표: 친구의 행방은 아직 미궁 속이다"
const RUN_NAVIGATION_LEFT_ARROW_TEXT := "<<<"
const RUN_NAVIGATION_RIGHT_ARROW_TEXT := ">>>"
const BOSS_REPORT_ARROW_TEXT := "<<<"
const RETURN_TO_LOBBY_MESSAGE := "로비로 돌아갈까요? 진행 상황은 자동으로 저장됩니다."
const QUIT_GAME_MESSAGE := "게임을 종료할까요?"
const BASEBALL_CAPTAIN_DISPLAY_NAME := "야구부 주장"
const BASEBALL_CAPTAIN_PROMPT_TEXT := "야구부 주장  말 걸기"
const BASEBALL_CAPTAIN_REWARD_CALLOUT_TEXT := "!  야구부 주장"
const BASEBALL_CAPTAIN_BOSS_RESULT_CALLOUT_TEXT := "!  야구부 주장"
const CRACKED_BAT_ID := &"cracked_bat"
const CRACKED_BAT_NAME := "금 간 나무 배트"
const CRACKED_BAT_POPUP_SUBTITLE := "야구부 주장이 건넨 첫 무기"
const BASEBALL_REWARD_LINES := [
	{
		"text": "고마워. 아까는 내가 제정신이 아니었던 것 같아.",
		"memory": "",
	},
	{
		"text": "이 금 간 나무 배트 가져가. 밤에 다시 들어가야 한다면 네 손에 있는 게 나아.\n[b]이 배트는 적의 공격을 튕겨내거나 돌진하는 적을 효과적으로 막을 수 있어![/b]",
		"memory": "",
	},
	{
		"text": "네가 찾는 친구는 [b]도깨비왕[/b]에게 잡혀갔다는 말이 있어. 아니면 그보다 더 큰 무언가일지도 몰라.",
		"memory": "",
	},
]
const BOSS_RESULT_REPORT_LINES := [
	{
		"text": "도깨비왕이 그냥 쓰러졌다고? 그럼 네 친구를 데려간 건 따로 있어.",
		"memory": "",
	},
	{
		"text": "지금은 여기까지야. 다음 단서가 생길 때까지 준비해 두자.",
		"memory": "",
	},
]

@export var corridor_size := Vector2(2172.0, 720.0)
@export var floor_y := 628.0
@export var player_left_bound := 96.0
@export var player_right_bound := 2076.0
@export var talk_radius := 120.0
@export var background_asset_scale := 1.0
@export var character_asset_scale := 2.4
@export var character_walk_fps := 8.0
@export var character_idle_fps := 1.6
## 멈춤 상태 전용 idle 시트(없으면 걷기 시트 프레임으로 폴백).
@export var character_idle_texture: Texture2D
@export var character_idle_frames: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
@export var character_idle_bob_px := 0.0
@export var talk_target_texture: Texture2D
@export var talk_target_asset_scale := 2.4
@export var talk_target_idle_fps := 4.0
@export var dialogue_portrait_texture: Texture2D
@export var dialogue_portrait_frame := 1
@export var ambient_student_idle_fps := 4.0
@export var ambient_label_proximity_radius := 280.0
@export var ambient_crowd_base_cooldown := 4.0
@export var ambient_crowd_min_cooldown := 2.2
@export var ambient_label_min_seconds := 1.8
@export var ambient_label_per_char_seconds := 0.08
@export var ambient_label_fade_seconds := 0.2
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
@onready var _left_school_characters: Node2D = %LeftSchoolCharacters
@onready var _right_school_characters: Node2D = %RightSchoolCharacters
@onready var _talk_target: Node2D = %TalkTarget
@onready var _talk_target_sprite: Sprite2D = %TalkTargetSprite
@onready var _talk_target_callout_label: Label = %TalkTargetCalloutLabel
@onready var _boss_report_arrow_label: Label = %BossReportArrowLabel
@onready var _right_student3_sprite: Sprite2D = %RightStudent3Sprite
@onready var _right_crowd_sprite: Sprite2D = %RightCrowdSprite
@onready var _right_student3: Node2D = %RightStudent3
@onready var _right_crowd: Node2D = %RightCrowd
@onready var _right_student3_label: Label = %RightStudent3Label
@onready var _right_crowd_label: Label = %RightCrowdLabel
@onready var _day_character_root: Node2D = %DayCharacterRoot
@onready var _character_sprite: Sprite2D = %CharacterSprite
@onready var _interaction_prompt: Label = %InteractionPrompt
@onready var _talk_button_label: Label = %TalkButtonLabel
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _gyeongbokgung_run_arrow_label: Label = %GyeongbokgungRunArrowLabel
@onready var _gyeongbokgung_run_left_arrow_label: Label = %GyeongbokgungRunLeftArrowLabel
@onready var _hub_dialogue_ui: HubDialogueUi = %HubDialogueUi
@onready var _fade_overlay: ColorRect = %FadeOverlay
@onready var _exit_button: Button = %ExitButton
@onready var _confirm_modal: ConfirmModal = %ConfirmModal

var _dialogue_count := 0
var _dialogue_line_index := -1
var _dialogue_lines: Array[Dictionary] = []
var _dialogue_claims_baseball_reward := false
var _dialogue_claims_boss_result_report := false
var _baseball_reward_pickup_popup_shown := false
var _was_dialogue_pressed := false
var _walk_elapsed := 0.0
var _footstep_walk_loop_index := -1
var _idle_elapsed := 0.0
var _talk_target_elapsed := 0.0
var _ambient_student_elapsed := 0.0
var _ambient_student_sprites: Array[Sprite2D] = []
var _ambient_rng := RandomNumberGenerator.new()
var _crowd_label_elapsed := 0.0
var _student3_label_shown_for_entry := false
var _ambient_tier := DaySchoolRumors.TIER_FIRST_VISIT
var _run_navigation_arrow_tween: Tween
var _run_navigation_left_arrow_tween: Tween
var _boss_report_arrow_tween: Tween
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
	AudioManager.play_bgm(AudioManager.SCHOOL_HALLWAY_BGM)
	_disable_combat_output()
	_hide_player_default_visuals()
	_ambient_student_sprites = [_right_student3_sprite, _right_crowd_sprite]
	_ambient_rng.randomize()
	_hide_ambient_labels()
	_apply_nearest_texture_filter()
	_apply_school_character_visual_treatment()
	_fit_character_to_asset_scale()
	_fit_talk_target_to_asset_scale()
	_fit_ambient_school_character_sprites()
	_restore_corridor_context()
	_apply_room_state()
	_hub_dialogue_ui.visible = false
	_hub_dialogue_ui.set_stage_row_visible(false)
	_hub_dialogue_ui.choice_selected.connect(_on_hub_dialogue_choice_selected)
	_update_objective_label()
	_update_navigation_arrows()
	_interaction_prompt.visible = false
	_update_talk_target_callout()
	_apply_ui_automation_metadata()
	PixelButtonStyle.apply(_exit_button, PixelButtonStyle.VARIANT_PRIMARY, Vector2(144.0, 50.0))
	_exit_button.pressed.connect(_request_return_to_lobby)
	_fit_camera_to_corridor_height()
	_clamp_player_to_corridor()
	_sync_camera()


func _process(delta: float) -> void:
	_update_talk_target_sprite(delta)
	_update_ambient_school_character_sprites(delta)
	if _confirm_modal.is_open():
		_player.velocity = Vector2.ZERO
		_update_character_sprite(delta)
		_sync_camera()
		return
	if _is_room_transitioning:
		_player.velocity = Vector2.ZERO
		_sync_camera()
		return
	if _hub_dialogue_ui.is_unlock_visible():
		_player.velocity = Vector2.ZERO
		_update_character_sprite(delta)
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
	_update_ambient_rumor_labels(delta)


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


func get_school_character_texture_paths() -> Array[String]:
	var paths: Array[String] = []
	for sprite: Sprite2D in _get_school_character_sprites():
		if sprite.texture != null:
			paths.append(sprite.texture.resource_path)
	return paths


func get_left_school_character_count() -> int:
	return _count_sprite_descendants(_left_school_characters)


func get_right_school_character_count() -> int:
	return _count_sprite_descendants(_right_school_characters)


func is_left_school_character_group_visible() -> bool:
	return _left_school_characters.visible


func is_right_school_character_group_visible() -> bool:
	return _right_school_characters.visible


func is_talk_target_visible() -> bool:
	return _talk_target.visible


func do_school_characters_match_background_tint() -> bool:
	var target_tint := _school_bg_left.self_modulate
	for sprite: Sprite2D in _get_school_character_sprites():
		if sprite.self_modulate != target_tint:
			return false
	return true


func do_school_characters_match_player_scale() -> bool:
	for sprite: Sprite2D in _get_school_character_sprites():
		if not is_equal_approx(sprite.scale.x, character_asset_scale):
			return false
		if not is_equal_approx(sprite.scale.y, character_asset_scale):
			return false
	return true


func get_active_dialogue_line_index() -> int:
	return _dialogue_line_index


func get_active_dialogue_text() -> String:
	return _hub_dialogue_ui.get_dialogue_text()


func get_active_dialogue_memory_text() -> String:
	return _hub_dialogue_ui.get_memory_text()


func get_dialogue_choice_ids() -> Array[StringName]:
	return _hub_dialogue_ui.get_choice_ids()


func is_dialogue_ui_visible() -> bool:
	return _hub_dialogue_ui.visible and _hub_dialogue_ui.is_dialogue_content_visible()


func is_touch_controls_visible() -> bool:
	return _touch_controls.visible


func get_objective_text() -> String:
	return _objective_label.text


func is_run_navigation_arrow_glow_active() -> bool:
	var right_active := (
		_gyeongbokgung_run_arrow_label != null
		and _gyeongbokgung_run_arrow_label.visible
		and _run_navigation_arrow_tween != null
		and _run_navigation_arrow_tween.is_valid()
	)
	var left_active := (
		_gyeongbokgung_run_left_arrow_label != null
		and _gyeongbokgung_run_left_arrow_label.visible
		and _run_navigation_left_arrow_tween != null
		and _run_navigation_left_arrow_tween.is_valid()
	)
	return right_active and left_active


func is_boss_report_arrow_glow_active() -> bool:
	return (
		_boss_report_arrow_label != null
		and _boss_report_arrow_label.visible
		and _boss_report_arrow_tween != null
		and _boss_report_arrow_tween.is_valid()
	)


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
			if is_dialogue_ui_visible() or _hub_dialogue_ui.is_unlock_visible() or not is_player_in_dialogue_range():
				return false
			trigger_dialogue()
			return true
		ACTION_DIALOGUE_NEXT:
			if not is_dialogue_ui_visible() or _hub_dialogue_ui.is_unlock_visible() or not get_dialogue_choice_ids().has(CHOICE_NEXT):
				return false
			_hub_dialogue_ui.select_choice(CHOICE_NEXT)
			return true
		ACTION_DIALOGUE_CLOSE:
			if not is_dialogue_ui_visible() or _hub_dialogue_ui.is_unlock_visible() or not get_dialogue_choice_ids().has(CHOICE_CLOSE):
				return false
			_hub_dialogue_ui.select_choice(CHOICE_CLOSE)
			return true
		ACTION_DISMISS_UNLOCK:
			# #243: 실기기 UAT 가 좌표 탭 없이 강화배트 팝업을 닫는다(안드로이드 좌표 탭 금지 규칙).
			if not _hub_dialogue_ui.is_unlock_visible():
				return false
			_hub_dialogue_ui.hide_unlock()
			return true
		ACTION_EXIT_TO_LOBBY:
			_request_return_to_lobby()
			return true
		_:
			return false


func trigger_dialogue() -> void:
	if _hub_dialogue_ui.is_unlock_visible():
		return
	if is_dialogue_ui_visible():
		if _dialogue_lines.is_empty():
			return
		if _hub_dialogue_ui.is_unlock_visible():
			return
		_show_dialogue_line((_dialogue_line_index + 1) % _dialogue_lines.size())
		return
	_resolve_dialogue_lines()
	if _dialogue_lines.is_empty():
		return
	_play_dialogue_open_sfx()
	_open_dialogue_ui()
	_show_dialogue_line(0)


## people2 대사를 현재 진행도 tier + 컨텍스트로 해석한다. 대화 open 시점에 호출.
func _resolve_dialogue_lines() -> void:
	_dialogue_claims_baseball_reward = _needs_baseball_reward_dialogue()
	_dialogue_claims_boss_result_report = false
	_baseball_reward_pickup_popup_shown = false
	if _dialogue_claims_baseball_reward:
		_dialogue_lines = _baseball_reward_lines()
		return
	_dialogue_claims_boss_result_report = _needs_boss_result_report_dialogue()
	if _dialogue_claims_boss_result_report:
		_dialogue_lines = _boss_result_report_lines()
		return
	_dialogue_lines = DaySchoolRumors.pick_lines(
		DaySchoolRumors.SPEAKER_PEOPLE2, _current_rumor_tier(), _rumor_context()
	)


func _current_rumor_tier() -> StringName:
	return DaySchoolRumors.current_tier(get_node_or_null(^"/root/ProgressionSystem"))


func _rumor_context() -> Dictionary:
	return {"last_run": _last_run_outcome()}


func _last_run_outcome() -> StringName:
	var last := _last_session_result()
	if last.is_empty():
		return &""
	var outcome := String(last.get("outcome", "")).to_lower()
	if outcome in ["death", "dead", "failed"] or bool(last.get("died", false)):
		return &"died"
	if bool(last.get("completed", false)) or String(last.get("reason", "")) == "boss_resolved" or outcome in ["success", "escaped", "complete", "completed"]:
		return &"cleared"
	return &""


func _last_session_result() -> Dictionary:
	if not has_node(^"/root/SaveManager"):
		return {}
	var results: Array = SaveManager.load_profile().get("session_results", [])
	if results.is_empty():
		return {}
	var last: Variant = results[results.size() - 1]
	if last is Dictionary:
		return (last as Dictionary).duplicate(true)
	return {}


func _has_resolved_gyeongbokgung_boss() -> bool:
	if not has_node(^"/root/SaveManager"):
		return false
	var results: Array = SaveManager.load_profile().get("session_results", [])
	for result: Variant in results:
		if result is Dictionary and _is_gyeongbokgung_boss_result(result as Dictionary):
			return true
	return false


func _is_gyeongbokgung_boss_result(result: Dictionary) -> bool:
	if String(result.get("reason", "")) != "boss_resolved":
		return false
	var boss_id := StringName(result.get("boss_id", &""))
	return boss_id == &"" or boss_id == &"gyeongbokgung_boss"


func close_dialogue() -> void:
	# #243: 강화배트 팝업이 떠 있는 채로 back/ESC 등이 close_dialogue 를 직접 부르면, hide_unlock 없이
	# CanvasLayer 가 숨어 unlock_hidden 이 영영 발사되지 않는다(ghost popup/소프트락). 먼저 오버레이를 정리해
	# 탭·back·ESC 모든 close 경로를 안전하게 한다. hide_unlock 은 예약된 one-shot 을 정상 발사시킨다(멱등).
	if _hub_dialogue_ui.is_unlock_visible():
		_hub_dialogue_ui.hide_unlock()
	if _is_baseball_reward_dialogue_complete():
		_claim_baseball_reward_dialogue()
	if _is_boss_result_report_dialogue_complete():
		_claim_boss_result_report_dialogue()
	_hub_dialogue_ui.visible = false
	_touch_controls.visible = true
	_talk_button_label.visible = true
	_player.set_physics_process(true)
	_dialogue_line_index = -1
	_dialogue_claims_baseball_reward = false
	_dialogue_claims_boss_result_report = false
	_baseball_reward_pickup_popup_shown = false
	_sync_talk_target_visibility()
	_update_objective_label()
	# The closing tap can reveal touch controls under the same held press.
	_was_dialogue_pressed = true
	_update_interaction_prompt()


func _request_close_dialogue() -> void:
	if _is_baseball_reward_dialogue_complete():
		_claim_baseball_reward_dialogue()
		if _try_complete_baseball_lobby_quest():
			return
	if _is_boss_result_report_dialogue_complete():
		_claim_boss_result_report_dialogue()
	close_dialogue()


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
	_player.set("movement_footstep_sfx_id", &"")
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
	for sprite: Sprite2D in _get_school_character_sprites():
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for child: Node in _background.get_children():
		var item := child as CanvasItem
		if item != null:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _apply_school_character_visual_treatment() -> void:
	var target_tint := _school_bg_left.self_modulate
	for sprite: Sprite2D in _get_school_character_sprites():
		sprite.self_modulate = target_tint


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
	_talk_target_sprite.frame = clampi(dialogue_portrait_frame, 0, _get_talk_target_frame_count() - 1)


func _fit_ambient_school_character_sprites() -> void:
	for sprite: Sprite2D in _ambient_student_sprites:
		if sprite.texture == null:
			continue
		sprite.hframes = _get_square_sheet_hframes(sprite.texture)
		sprite.vframes = 1
		sprite.scale = Vector2(character_asset_scale, character_asset_scale)
		if sprite.scale.y > 0.0:
			sprite.position.y = -_get_sprite_frame_size(sprite).y * sprite.scale.y * 0.5
		sprite.frame = clampi(sprite.frame, 0, _get_sprite_frame_count(sprite) - 1)


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
	_left_school_characters.visible = _current_room_id == ROOM_LEFT
	_right_school_characters.visible = _current_room_id == ROOM_RIGHT
	_camera.limit_right = int(corridor_size.x)
	if _current_room_id != ROOM_LEFT:
		close_dialogue()
	_sync_talk_target_visibility()
	_reset_ambient_rumor_state()


func _sync_talk_target_visibility() -> void:
	_talk_target.visible = _current_room_id == ROOM_LEFT


func _start_room_transition(target_room_id: StringName) -> void:
	if target_room_id != ROOM_LEFT and target_room_id != ROOM_RIGHT:
		return
	_player.velocity = Vector2.ZERO
	_play_school_room_transition_sfx()
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
	_update_navigation_arrows()
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
		_footstep_walk_loop_index = -1
		_idle_elapsed += delta
		_use_idle_sheet()
		_character_sprite.frame = _get_character_idle_frame()
		_character_sprite.position.y = _character_base_position.y + _get_character_idle_bob_offset()
		return

	_idle_elapsed = 0.0
	_use_walk_sheet()
	_character_sprite.position = _character_base_position
	_walk_elapsed += delta
	var frame_count := _get_character_frame_count()
	_character_sprite.frame = int(_walk_elapsed * character_walk_fps) % frame_count
	_play_corridor_footstep_if_needed(frame_count)


func _play_corridor_footstep_if_needed(frame_count: int) -> void:
	if frame_count <= 0 or character_walk_fps <= 0.0:
		return
	var loop_index := int(floorf((_walk_elapsed * character_walk_fps) / float(frame_count)))
	if loop_index == _footstep_walk_loop_index:
		return
	_footstep_walk_loop_index = loop_index
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.CORRIDOR_FOOTSTEP)


func _update_talk_target_sprite(delta: float) -> void:
	if not _talk_target.visible:
		return
	_talk_target_elapsed += delta
	var frame_count := _get_talk_target_frame_count()
	_talk_target_sprite.frame = int(_talk_target_elapsed * talk_target_idle_fps + dialogue_portrait_frame) % frame_count


func _update_ambient_school_character_sprites(delta: float) -> void:
	if _ambient_student_sprites.is_empty():
		return
	_ambient_student_elapsed += delta
	for index in _ambient_student_sprites.size():
		var sprite := _ambient_student_sprites[index]
		var frame_count := _get_sprite_frame_count(sprite)
		sprite.frame = int(_ambient_student_elapsed * ambient_student_idle_fps + index * 2) % frame_count


## people3 근접 라벨(진입당 1회) + people4 군중 웅성거림(E2 진행도 스케일 쿨다운).
## 자유 이동 경로에서만 호출 — 대화/전환/모달 중엔 호출되지 않으므로 자연히 일시정지.
func _update_ambient_rumor_labels(delta: float) -> void:
	if _current_room_id != ROOM_RIGHT:
		return
	if _right_student3 != null and not _student3_label_shown_for_entry and _is_player_near(_right_student3, ambient_label_proximity_radius):
		var lines := DaySchoolRumors.pick_lines(DaySchoolRumors.SPEAKER_PEOPLE3, _ambient_tier, _rumor_context())
		if not lines.is_empty():
			var entry: Dictionary = lines[_ambient_rng.randi_range(0, lines.size() - 1)]
			_show_ambient_label(_right_student3_label, String(entry.get("text", "")))
			_student3_label_shown_for_entry = true
	_crowd_label_elapsed += delta
	if _crowd_label_elapsed >= _crowd_label_cooldown():
		_crowd_label_elapsed = 0.0
		var fragment := DaySchoolRumors.pick_crowd_fragment(_ambient_tier, _ambient_rng, _rumor_context())
		if not fragment.is_empty():
			_show_ambient_label(_right_crowd_label, String(fragment.get("text", "")))


## E2: 진행도가 오를수록 군중 웅성거림 쿨다운 단축(분위기 고조). 상한 클램프.
func _crowd_label_cooldown() -> float:
	var progression := get_node_or_null(^"/root/ProgressionSystem")
	var progressed := 0.0
	if progression != null:
		if progression.is_friend_purified(DaySchoolRumors.FRIEND_BASEBALL_CAPTAIN):
			progressed += 1.0
		if progression.is_weapon_unlocked(DaySchoolRumors.WEAPON_AWAKENED_BAT):
			progressed += 1.0
	var t := clampf(progressed / 2.0, 0.0, 1.0)
	return lerpf(ambient_crowd_base_cooldown, ambient_crowd_min_cooldown, t)


func _is_player_near(node: Node2D, radius: float) -> bool:
	return absf(_player.global_position.x - node.global_position.x) <= radius


func _show_ambient_label(label: Label, text: String) -> void:
	if label == null or text.strip_edges() == "":
		return
	label.text = text
	# 콘텐츠 폭에 맞춰 머리 위 중앙 정렬 (pill이 텍스트를 감싸도록)
	var width := label.get_minimum_size().x
	label.offset_left = -width * 0.5
	label.offset_right = width * 0.5
	label.visible = true
	label.modulate.a = 0.0
	var hold := ambient_label_min_seconds + float(text.length()) * ambient_label_per_char_seconds
	var tween := create_tween()
	tween.tween_property(label, ^"modulate:a", 1.0, ambient_label_fade_seconds)
	tween.tween_interval(hold)
	tween.tween_property(label, ^"modulate:a", 0.0, ambient_label_fade_seconds)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.visible = false
	)


func _hide_ambient_labels() -> void:
	for label: Label in [_right_student3_label, _right_crowd_label]:
		if label != null:
			label.visible = false
			label.modulate.a = 0.0


func _reset_ambient_rumor_state() -> void:
	if _current_room_id == ROOM_RIGHT:
		_student3_label_shown_for_entry = false
		_crowd_label_elapsed = 0.0
		_ambient_tier = _current_rumor_tier()
	else:
		_hide_ambient_labels()


# ── 테스트 훅 ──
func get_ambient_tier() -> StringName:
	return _ambient_tier


func get_student3_rumor_label_text() -> String:
	return _right_student3_label.text if _right_student3_label != null else ""


func get_crowd_rumor_label_text() -> String:
	return _right_crowd_label.text if _right_crowd_label != null else ""


func debug_show_student3_rumor() -> String:
	var lines := DaySchoolRumors.pick_lines(DaySchoolRumors.SPEAKER_PEOPLE3, _ambient_tier, _rumor_context())
	if lines.is_empty():
		return ""
	_show_ambient_label(_right_student3_label, String(lines[0].get("text", "")))
	return get_student3_rumor_label_text()


func debug_rotate_crowd_rumor() -> String:
	var fragment := DaySchoolRumors.pick_crowd_fragment(_ambient_tier, _ambient_rng, _rumor_context())
	if fragment.is_empty():
		return ""
	_show_ambient_label(_right_crowd_label, String(fragment.get("text", "")))
	return get_crowd_rumor_label_text()


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


func _get_sprite_frame_size(sprite: Sprite2D) -> Vector2:
	if sprite.texture == null:
		return Vector2.ZERO
	return Vector2(
		sprite.texture.get_width() / float(sprite.hframes),
		sprite.texture.get_height() / float(sprite.vframes)
	)


func _get_sprite_frame_count(sprite: Sprite2D) -> int:
	return maxi(1, sprite.hframes * sprite.vframes)


func _get_school_character_sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if _talk_target_sprite != null:
		sprites.append(_talk_target_sprite)
	if _right_student3_sprite != null:
		sprites.append(_right_student3_sprite)
	if _right_crowd_sprite != null:
		sprites.append(_right_crowd_sprite)
	return sprites


func _count_sprite_descendants(root: Node) -> int:
	var count := 0
	for child: Node in root.get_children():
		if child is Sprite2D:
			count += 1
		count += _count_sprite_descendants(child)
	return count


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
	var prompt_visible := not is_dialogue_ui_visible() and not _hub_dialogue_ui.is_unlock_visible() and is_player_in_dialogue_range()
	_interaction_prompt.visible = prompt_visible
	_interaction_prompt.text = BASEBALL_CAPTAIN_PROMPT_TEXT if prompt_visible else ""
	_update_talk_target_callout()


func _update_talk_target_callout() -> void:
	if _talk_target_callout_label == null:
		return
	var should_show := not is_dialogue_ui_visible() and not _hub_dialogue_ui.is_unlock_visible() and _talk_target.visible
	if _needs_baseball_reward_dialogue():
		_talk_target_callout_label.text = BASEBALL_CAPTAIN_REWARD_CALLOUT_TEXT
	elif _needs_boss_result_report_dialogue():
		_talk_target_callout_label.text = BASEBALL_CAPTAIN_BOSS_RESULT_CALLOUT_TEXT
	elif _dialogue_count <= 0 and not _has_claimed_baseball_reward():
		_talk_target_callout_label.text = BASEBALL_CAPTAIN_DISPLAY_NAME
	else:
		should_show = false
	_talk_target_callout_label.visible = should_show


func _process_dialogue_input() -> void:
	var pressed := is_dialogue_input_pressed()
	if is_dialogue_ui_visible():
		if _is_dialogue_close_input_pressed():
			_request_close_dialogue()
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
	_update_talk_target_callout()
	_update_navigation_arrows()


func _show_dialogue_line(line_index: int) -> void:
	if _dialogue_lines.is_empty():
		return
	_dialogue_count += 1
	_dialogue_line_index = posmod(line_index, _dialogue_lines.size())
	var entry: Dictionary = _dialogue_lines[_dialogue_line_index]
	var line_text := String(entry.get("text", ""))
	var memory_text := String(entry.get("memory", ""))
	var meta := DaySchoolRumors.speaker_meta(DaySchoolRumors.SPEAKER_PEOPLE2)
	_update_objective_label()
	_hub_dialogue_ui.set_dialogue(
		String(meta.get("display_name", "")),
		line_text,
		memory_text,
		HubDialogueUi.PORTRAIT_COLOR,
		dialogue_portrait_texture,
		dialogue_portrait_frame,
		false
	)
	var is_last_line := _dialogue_line_index >= _dialogue_lines.size() - 1
	_hub_dialogue_ui.set_choices([
		{
			"id": CHOICE_CLOSE if is_last_line else CHOICE_NEXT,
			"text": HubDialogueUi.CONTINUE_HINT_TOUCH,
			"tap_to_continue": true,
			"test_id": TEST_ID_DIALOGUE_CLOSE if is_last_line else TEST_ID_DIALOGUE_NEXT,
			"uat_action": ACTION_DIALOGUE_CLOSE if is_last_line else ACTION_DIALOGUE_NEXT,
		},
	])
	_maybe_show_baseball_reward_pickup_popup()
	dialogue_requested.emit({
		"count": _dialogue_count,
		"line": line_text,
		"line_index": _dialogue_line_index,
		"memory": memory_text,
		"source": &"day_corridor",
	})


func _on_hub_dialogue_choice_selected(choice_id: StringName) -> void:
	match choice_id:
		CHOICE_NEXT:
			trigger_dialogue()
		CHOICE_CLOSE:
			_request_close_dialogue()


func _maybe_show_baseball_reward_pickup_popup() -> void:
	if not _dialogue_claims_baseball_reward:
		return
	if _dialogue_line_index != 1:
		return
	if _baseball_reward_pickup_popup_shown:
		return
	_baseball_reward_pickup_popup_shown = true
	_hub_dialogue_ui.show_unlock(CRACKED_BAT_NAME, CRACKED_BAT_POPUP_SUBTITLE, [
		{"id": CRACKED_BAT_ID, "name": CRACKED_BAT_NAME, "color": HubDialogueUi.DEFAULT_BAT_COLOR},
	])


## 정화 후(post_purify tier) people2 대화 완주 = 로비 퀘스트 완료. 대화 바를 먼저 닫고
## 같은 CanvasLayer 에 강화배트 팝업만 남겨, 팝업이 "대화가 끝난 뒤" 보이도록 한다.
## 게이트가 발동해 팝업만 남겼으면 true 를 반환한다.
func _try_complete_baseball_lobby_quest() -> bool:
	var progression := get_node_or_null(^"/root/ProgressionSystem")
	if progression == null:
		return false
	if progression.is_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY):
		return false
	if _current_rumor_tier() != DaySchoolRumors.TIER_POST_PURIFY:
		return false

	_prepare_dialogue_closed_for_quest_unlock()
	progression.record_quest_completed(ProgressionSystem.QUEST_BASEBALL_CAPTAIN_LOBBY)
	_play_quest_reward_sfx()
	# 팝업이 뜨지 않았다면(이미 해금된 무기 등) 미룰 이유가 없으니 예약을 해제하고 일반 닫기로 넘긴다.
	if not _hub_dialogue_ui.is_unlock_visible():
		if _hub_dialogue_ui.unlock_hidden.is_connected(_on_quest_unlock_hidden):
			_hub_dialogue_ui.unlock_hidden.disconnect(_on_quest_unlock_hidden)
		return false
	_update_interaction_prompt()
	_update_navigation_arrows()
	return true


func _prepare_dialogue_closed_for_quest_unlock() -> void:
	if not _hub_dialogue_ui.unlock_hidden.is_connected(_on_quest_unlock_hidden):
		_hub_dialogue_ui.unlock_hidden.connect(_on_quest_unlock_hidden, CONNECT_ONE_SHOT)
	_hub_dialogue_ui.visible = true
	_hub_dialogue_ui.set_dialogue_content_visible(false)
	_touch_controls.visible = false
	_talk_button_label.visible = false
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_dialogue_line_index = -1
	_dialogue_claims_baseball_reward = false
	_baseball_reward_pickup_popup_shown = false
	_sync_talk_target_visibility()
	_update_objective_label()
	_was_dialogue_pressed = true
	_update_interaction_prompt()


func _on_quest_unlock_hidden() -> void:
	close_dialogue()


func _update_objective_label() -> void:
	if _objective_label == null:
		return
	var objective_text := OBJECTIVE_LOCKER if _dialogue_count > 0 else OBJECTIVE_TALK
	if _needs_baseball_reward_dialogue():
		objective_text = OBJECTIVE_BASEBALL_REWARD
	elif _needs_boss_result_report_dialogue():
		objective_text = OBJECTIVE_BOSS_RESULT_REPORT
	elif _has_claimed_baseball_reward() and _has_resolved_gyeongbokgung_boss():
		objective_text = OBJECTIVE_BOSS_RESULT_ACKNOWLEDGED
	elif _has_claimed_baseball_reward():
		objective_text = OBJECTIVE_REENTER_GYEONGBOKGUNG
	_objective_label.text = objective_text
	_update_navigation_arrows()


func _update_navigation_arrows() -> void:
	_update_run_navigation_arrow()
	_update_boss_report_arrow()


func _update_run_navigation_arrow() -> void:
	_set_run_navigation_arrow_texts()
	var should_show := _should_show_run_navigation_arrow()
	if _gyeongbokgung_run_arrow_label != null:
		_gyeongbokgung_run_arrow_label.visible = should_show
	if _gyeongbokgung_run_left_arrow_label != null:
		_gyeongbokgung_run_left_arrow_label.visible = should_show
	if should_show:
		_run_navigation_arrow_tween = _start_navigation_arrow_glow(
			_gyeongbokgung_run_arrow_label,
			_run_navigation_arrow_tween
		)
		_run_navigation_left_arrow_tween = _start_navigation_arrow_glow(
			_gyeongbokgung_run_left_arrow_label,
			_run_navigation_left_arrow_tween
		)
	else:
		_stop_run_navigation_arrow_glow()


func _update_boss_report_arrow() -> void:
	if _boss_report_arrow_label == null:
		return
	_boss_report_arrow_label.text = BOSS_REPORT_ARROW_TEXT
	var should_show := _should_show_boss_report_arrow()
	_boss_report_arrow_label.visible = should_show
	if should_show:
		_boss_report_arrow_tween = _start_navigation_arrow_glow(_boss_report_arrow_label, _boss_report_arrow_tween)
	else:
		_stop_boss_report_arrow_glow()


func _start_navigation_arrow_glow(label: Label, current_tween: Tween) -> Tween:
	if label == null:
		return current_tween
	if current_tween != null and current_tween.is_valid():
		return current_tween
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	label.modulate = Color.WHITE
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(
		label,
		"scale",
		Vector2(1.08, 1.08),
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		label,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.82),
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		label,
		"scale",
		Vector2.ONE,
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		label,
		"modulate",
		Color.WHITE,
		0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _stop_run_navigation_arrow_glow() -> void:
	_stop_navigation_arrow_glow(_gyeongbokgung_run_arrow_label, _run_navigation_arrow_tween)
	_stop_navigation_arrow_glow(_gyeongbokgung_run_left_arrow_label, _run_navigation_left_arrow_tween)
	_run_navigation_arrow_tween = null
	_run_navigation_left_arrow_tween = null


func _stop_boss_report_arrow_glow() -> void:
	_stop_navigation_arrow_glow(_boss_report_arrow_label, _boss_report_arrow_tween)
	_boss_report_arrow_tween = null


func _stop_navigation_arrow_glow(label: Label, tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	if label != null:
		label.scale = Vector2.ONE
		label.modulate = Color.WHITE


func _should_show_run_navigation_arrow() -> bool:
	if not _has_claimed_baseball_reward():
		return false
	if _needs_baseball_reward_dialogue():
		return false
	if _has_resolved_gyeongbokgung_boss():
		return false
	if is_dialogue_ui_visible():
		return false
	if _hub_dialogue_ui != null and _hub_dialogue_ui.is_unlock_visible():
		return false
	if _confirm_modal != null and _confirm_modal.is_open():
		return false
	return not _is_maintenance_requested


func _should_show_boss_report_arrow() -> bool:
	if not _needs_boss_result_report_dialogue():
		return false
	if is_dialogue_ui_visible():
		return false
	if _hub_dialogue_ui != null and _hub_dialogue_ui.is_unlock_visible():
		return false
	if _confirm_modal != null and _confirm_modal.is_open():
		return false
	if _is_maintenance_requested:
		return false
	return _talk_target != null and _talk_target.visible


func _needs_baseball_reward_dialogue() -> bool:
	if not has_node(^"/root/SaveManager"):
		return false
	return (
		SaveManager.get_flag(SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE)
		and not SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED)
	)


func _has_claimed_baseball_reward() -> bool:
	return has_node(^"/root/SaveManager") and SaveManager.get_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED)


func _needs_boss_result_report_dialogue() -> bool:
	if not has_node(^"/root/SaveManager"):
		return false
	return (
		_has_claimed_baseball_reward()
		and _has_resolved_gyeongbokgung_boss()
		and not SaveManager.get_flag(SceneTransition.FLAG_GYEONGBOKGUNG_BOSS_RESULT_ACKNOWLEDGED)
	)


func _claim_baseball_reward_dialogue() -> void:
	if not has_node(^"/root/SaveManager"):
		return
	SaveManager.set_flag(SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED, true)


func _play_dialogue_open_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.UI_BUTTON_PRESS)


func _play_school_room_transition_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.SCHOOL_SCENE_PAGE_FLIP)


func _play_quest_reward_sfx() -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(AudioManager.QUEST_REWARD_LEVEL_UP)


func _set_run_navigation_arrow_texts() -> void:
	if _gyeongbokgung_run_arrow_label != null:
		_gyeongbokgung_run_arrow_label.text = RUN_NAVIGATION_RIGHT_ARROW_TEXT
	if _gyeongbokgung_run_left_arrow_label != null:
		_gyeongbokgung_run_left_arrow_label.text = RUN_NAVIGATION_LEFT_ARROW_TEXT


func _claim_boss_result_report_dialogue() -> void:
	if not has_node(^"/root/SaveManager"):
		return
	SaveManager.set_flag(SceneTransition.FLAG_GYEONGBOKGUNG_BOSS_RESULT_ACKNOWLEDGED, true)


func _is_baseball_reward_dialogue_complete() -> bool:
	return _dialogue_claims_baseball_reward and _dialogue_line_index >= _dialogue_lines.size() - 1


func _baseball_reward_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for entry: Dictionary in BASEBALL_REWARD_LINES:
		lines.append(entry.duplicate(true))
	return lines


func _is_boss_result_report_dialogue_complete() -> bool:
	return _dialogue_claims_boss_result_report and _dialogue_line_index >= _dialogue_lines.size() - 1


func _boss_result_report_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for entry: Dictionary in BOSS_RESULT_REPORT_LINES:
		lines.append(entry.duplicate(true))
	return lines


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
	if _hub_dialogue_ui.is_unlock_visible():
		_request_close_dialogue()
		return
	if is_dialogue_ui_visible():
		_request_close_dialogue()
		return
	_request_return_to_lobby()


func _request_return_to_lobby() -> void:
	if _confirm_modal.is_open():
		return
	_player.velocity = Vector2.ZERO
	_confirm_modal.open(
		RETURN_TO_LOBBY_MESSAGE,
		Callable(self, "_return_to_lobby"),
		Callable(self, "_update_navigation_arrows")
	)
	_update_navigation_arrows()


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
		Callable(self, "_update_navigation_arrows")
	)
	_update_navigation_arrows()


func _quit_game() -> void:
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
