extends CanvasLayer
## 모바일 터치 컨트롤(#52) — 좌하단 가상 조이스틱 + 장면 조작 범주별 우측 액션 버튼.
## 플레이어가 get_move() / is_attack_pressed() 로 읽는다.

const CONTROL_CATEGORY_COMBAT := "combat"
const CONTROL_CATEGORY_DAY_DIALOGUE := "day_dialogue"

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
	_apply_control_category()
	if has_node("/root/EventBus") and not EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.connect(set_skill_state)


func _exit_tree() -> void:
	if has_node("/root/EventBus") and EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.disconnect(set_skill_state)


func get_move() -> Vector2:
	return _joystick.get_value()


func is_attack_pressed() -> bool:
	if not _attack.visible:
		return false
	return _attack.is_held()


## 공격 조준 방향 — 공격버튼 드래그 방향(없으면 ZERO).
func get_aim() -> Vector2:
	if _attack.has_method("get_aim"):
		return _attack.get_aim()
	return Vector2.ZERO


func is_skill_pressed() -> bool:
	if _control_category != CONTROL_CATEGORY_COMBAT or not _skill.visible:
		return false
	return _skill.is_held()


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
	_joystick.set_process_input(true)
	_attack.visible = true
	_attack.set_process_input(true)
	_skill.visible = is_combat
	_skill.set_process_input(is_combat)
	if not is_combat and _skill.has_method("release"):
		_skill.call("release")


func _are_controls_ready() -> bool:
	return _joystick != null and _attack != null and _skill != null
