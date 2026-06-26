extends CanvasLayer
## 모바일 터치 컨트롤(#52) — 좌하단 가상 조이스틱(이동) + 우하단 공격 버튼.
## 플레이어가 get_move() / is_attack_pressed() 로 읽는다.

@onready var _joystick: Control = $Joystick
@onready var _attack: Control = $AttackButton
@onready var _skill: Control = $SkillButton


func _ready() -> void:
	if has_node("/root/EventBus") and not EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.connect(set_skill_state)


func _exit_tree() -> void:
	if has_node("/root/EventBus") and EventBus.special_skill_state_changed.is_connected(set_skill_state):
		EventBus.special_skill_state_changed.disconnect(set_skill_state)


func get_move() -> Vector2:
	return _joystick.get_value()


func is_attack_pressed() -> bool:
	return _attack.is_held()


## 공격 조준 방향 — 공격버튼 드래그 방향(없으면 ZERO).
func get_aim() -> Vector2:
	if _attack.has_method("get_aim"):
		return _attack.get_aim()
	return Vector2.ZERO


func is_skill_pressed() -> bool:
	return _skill.is_held()


func set_skill_state(payload: Dictionary) -> void:
	if _skill.has_method("set_skill_state"):
		_skill.call("set_skill_state", payload)
