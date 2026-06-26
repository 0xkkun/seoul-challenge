extends CanvasLayer
## 모바일 터치 컨트롤(#52) — 좌하단 가상 조이스틱(이동) + 우하단 공격 버튼.
## 플레이어가 get_move() / is_attack_pressed() 로 읽는다.

@onready var _joystick: Control = $Joystick
@onready var _attack: Control = $AttackButton


func get_move() -> Vector2:
	return _joystick.get_value()


func is_attack_pressed() -> bool:
	return _attack.is_held()
