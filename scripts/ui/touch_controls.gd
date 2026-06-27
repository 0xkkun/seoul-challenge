extends CanvasLayer
## 모바일 터치 컨트롤(#52) — 좌하단 가상 조이스틱 + 장면 조작 범주별 우측 액션 버튼.
## 플레이어가 get_move() / is_attack_pressed() 로 읽는다.

const CONTROL_CATEGORY_COMBAT := "combat"
const CONTROL_CATEGORY_DAY_DIALOGUE := "day_dialogue"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _control_category := CONTROL_CATEGORY_COMBAT

@export_enum("combat", "day_dialogue") var control_category := CONTROL_CATEGORY_COMBAT:
	set(value):
		set_control_category(value)
	get:
		return _control_category

@onready var _joystick: Control = $Joystick
@onready var _attack: Control = $AttackButton
@onready var _skill: Control = $SkillButton


func _ready() -> void:
	_apply_landscape_safe_area()
	_apply_control_category()
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)
	if has_node("/root/EventBus") and not EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.connect(set_skill_state)


func _exit_tree() -> void:
	if has_node("/root/EventBus") and EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.disconnect(set_skill_state)


func get_move() -> Vector2:
	if not visible or _joystick == null or not _joystick.visible:
		return Vector2.ZERO
	return _joystick.get_value()


func is_attack_pressed() -> bool:
	if not visible or _attack == null or not _attack.visible:
		return false
	return _attack.is_held()


## 공격 조준 방향 — 공격버튼 드래그 방향(없으면 ZERO).
func get_aim() -> Vector2:
	if not visible or _attack == null or not _attack.visible:
		return Vector2.ZERO
	if _attack.has_method("get_aim"):
		return _attack.get_aim()
	return Vector2.ZERO


func is_skill_pressed() -> bool:
	if not visible or _control_category != CONTROL_CATEGORY_COMBAT or _skill == null or not _skill.visible:
		return false
	return _skill.is_held()


func release_combat_inputs() -> void:
	if _joystick != null and _joystick.has_method("release"):
		_joystick.call("release")
	if _attack != null and _attack.has_method("release"):
		_attack.call("release")
	if _skill != null and _skill.has_method("release"):
		_skill.call("release")


func set_skill_state(payload: Dictionary) -> void:
	if _skill.has_method("set_skill_state"):
		_skill.call("set_skill_state", payload)


func set_control_category(value: String) -> void:
	_control_category = _normalize_control_category(value)
	if _are_controls_ready():
		_apply_control_category()


func get_control_category() -> String:
	return _control_category


func _normalize_control_category(value: String) -> String:
	match value:
		CONTROL_CATEGORY_COMBAT, CONTROL_CATEGORY_DAY_DIALOGUE:
			return value
		_:
			return CONTROL_CATEGORY_COMBAT


func _apply_control_category() -> void:
	var is_combat := _control_category == CONTROL_CATEGORY_COMBAT
	_joystick.visible = true
	_attack.visible = true
	_skill.visible = is_combat
	_sync_input_processing()
	if not is_combat and _skill.has_method("release"):
		_skill.call("release")


func _are_controls_ready() -> bool:
	return _joystick != null and _attack != null and _skill != null


func _apply_landscape_safe_area() -> void:
	if not _are_controls_ready():
		return
	var touch_insets := MobileSafeArea.touch_insets()
	MobileSafeArea.apply_edge_offsets(_joystick, float(touch_insets["left"]), -1.0, -1.0, float(touch_insets["bottom"]))
	MobileSafeArea.apply_edge_offsets(_attack, -1.0, -1.0, float(touch_insets["right"]), float(touch_insets["bottom"]))
	MobileSafeArea.apply_edge_offsets(_skill, -1.0, -1.0, -1.0, float(touch_insets["bottom"]))


func _on_visibility_changed() -> void:
	if not visible:
		release_combat_inputs()
	_sync_input_processing()


func _sync_input_processing() -> void:
	if not _are_controls_ready():
		return
	_joystick.set_process_input(visible)
	_attack.set_process_input(visible)
	_skill.set_process_input(visible and _control_category == CONTROL_CATEGORY_COMBAT)
