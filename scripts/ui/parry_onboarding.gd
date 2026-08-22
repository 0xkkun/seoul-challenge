class_name ParryOnboarding
extends CanvasLayer

const InputPromptPolicy = preload("res://scripts/ui/input_prompt_policy.gd")
const CoachMarkScript = preload("res://scripts/ui/onboarding_coach_mark.gd")

const FLOW_ID := &"first_wolf_parry"
const REVEAL_SECONDS := 0.22
const DISPLAY_SECONDS := 3.2
const TARGET_WORLD_SIZE := Vector2(96.0, 112.0)
const TARGET_WORLD_OFFSET := Vector2(0.0, -34.0)

var _camera: Camera2D = null
var _wolf: Node2D = null
var _input_mode: StringName = InputPromptPolicy.MODE_DESKTOP
var _active := false
var _elapsed := 0.0
var _coach: OnboardingCoachMark = null
var _dismissing := false


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_coach = CoachMarkScript.new() as OnboardingCoachMark
	_coach.name = "CoachMark"
	add_child(_coach)
	_coach.exit_finished.connect(_on_coach_exit_finished)
	visible = false
	set_process(false)


func configure(camera: Camera2D) -> void:
	_camera = camera


func show_for_wolf(wolf: Node2D, input_mode: StringName) -> void:
	if wolf == null or not is_instance_valid(wolf):
		return
	_wolf = wolf
	_input_mode = InputPromptPolicy.MODE_TOUCH if input_mode == InputPromptPolicy.MODE_TOUCH else InputPromptPolicy.MODE_DESKTOP
	_active = true
	_dismissing = false
	_elapsed = 0.0
	visible = true
	set_process(true)
	_coach.configure(_camera, _is_reduced_motion())
	_coach.show_prompt({
		"id": &"parry",
		"tone": &"timing",
		"key_label": "공격 버튼" if _input_mode == InputPromptPolicy.MODE_TOUCH else "LMB",
		"action": "받아치기",
		"detail": "늑대가 달려들 때",
		"target_kind": &"world",
		"target": wolf,
		"target_size": TARGET_WORLD_SIZE,
		"target_offset": TARGET_WORLD_OFFSET,
		"placement": &"auto",
		"persistent": false,
	})


func dismiss() -> bool:
	if not _active:
		return false
	_active = false
	_dismissing = true
	if _coach != null:
		_coach.configure(_camera, _is_reduced_motion())
		_coach.dismiss(_is_reduced_motion())
	_wolf = null
	set_process(false)
	return true


func dismiss_for_wolf(wolf: Node) -> bool:
	if not _active or _wolf != wolf:
		return false
	return dismiss()


func is_active() -> bool:
	return _active


func is_showing_for(wolf: Node) -> bool:
	return _active and _wolf == wolf


func get_visual_contract() -> Dictionary:
	return {
		"flow": FLOW_ID,
		"blocks_gameplay": false,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE,
		"reveal_seconds": REVEAL_SECONDS,
		"display_seconds": DISPLAY_SECONDS,
		"bracket_style": &"corners",
		"uses_dim": false,
		"screen_coverage_hard_cap": 0.25,
	}


func get_snapshot() -> Dictionary:
	var coach_snapshot := _coach.get_snapshot() if _coach != null else {}
	return {
		"active": _active,
		"input_mode": _input_mode,
		"message": _legacy_message(),
		"key_label": coach_snapshot.get("key_label", ""),
		"action": coach_snapshot.get("action", ""),
		"detail": coach_snapshot.get("detail", ""),
		"target_name": coach_snapshot.get("target_name", ""),
		"target_rect": coach_snapshot.get("target_rect", Rect2()),
		"spotlight_rect": coach_snapshot.get("target_rect", Rect2()),
		"panel_rect": coach_snapshot.get("label_rect", Rect2()),
		"bracket_style": coach_snapshot.get("bracket_style", &"corners"),
		"screen_coverage": coach_snapshot.get("screen_coverage", 0.0),
		"dim_alpha": 0.0,
		"reveal_complete": _elapsed >= REVEAL_SECONDS,
		"blocks_gameplay": false,
		"tree_paused": get_tree().paused if get_tree() != null else false,
		"reduced_motion": coach_snapshot.get("reduced_motion", false),
	}


func _process(delta: float) -> void:
	if not _active:
		return
	if _wolf == null or not is_instance_valid(_wolf) or _wolf.is_queued_for_deletion():
		dismiss()
		return
	_elapsed += maxf(0.0, delta)
	if _elapsed >= DISPLAY_SECONDS:
		dismiss()


func _legacy_message() -> String:
	return "늑대가 달려들 때 %s 받아치기" % ("공격 버튼으로" if _input_mode == InputPromptPolicy.MODE_TOUCH else "LMB로")


func _is_reduced_motion() -> bool:
	return has_node("/root/Settings") and Settings.is_reduced_motion_enabled()


func _on_coach_exit_finished(_prompt_id: StringName, kind: StringName) -> void:
	if kind != &"dismiss" or not _dismissing:
		return
	_dismissing = false
	visible = false
