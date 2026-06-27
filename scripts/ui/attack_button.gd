extends Control
## 공격 버튼(#52) — 영역 터치 동안 held. 자기 영역에서 시작한 터치 인덱스만 추적해
## 조이스틱과 동시 멀티터치가 가능하다. 드래그하면 그 방향으로 조준(우측 조준 스틱).

const AIM_DEADZONE := 14.0

var _active_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.ZERO


func is_held() -> bool:
	return _active_index != -1


func release() -> void:
	if _active_index == -1:
		return
	_active_index = -1
	_aim = Vector2.ZERO
	queue_redraw()


## 드래그 방향(정규화, 없으면 ZERO). 플레이어가 공격 조준 방향으로 쓴다.
func get_aim() -> Vector2:
	return _aim


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _active_index:
		_on_drag(event.position)


func _on_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _active_index == -1 and get_global_rect().has_point(pos):
			_active_index = index
			_start_pos = pos
			_aim = Vector2.ZERO
			queue_redraw()
	elif index == _active_index:
		release()


func _on_drag(pos: Vector2) -> void:
	var delta := pos - _start_pos
	_aim = delta.normalized() if delta.length() >= AIM_DEADZONE else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var col := Color(1.0, 0.45, 0.4, 0.6) if _active_index != -1 else Color(1.0, 0.45, 0.4, 0.32)
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
	if _aim != Vector2.ZERO:
		draw_line(c, c + _aim * r, Color(1, 1, 1, 0.75), 3.0)
