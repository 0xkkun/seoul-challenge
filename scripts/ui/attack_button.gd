extends Control
## 공격 버튼(#52) — 영역 터치 동안 held. 자기 영역에서 시작한 터치 인덱스만 추적해
## 조이스틱과 동시 멀티터치가 가능하다.

var _active_index: int = -1


func is_held() -> bool:
	return _active_index != -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event.index, event.position, event.pressed)


func _on_touch(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _active_index == -1 and get_global_rect().has_point(pos):
			_active_index = index
			queue_redraw()
	elif index == _active_index:
		_active_index = -1
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var col := Color(1.0, 0.45, 0.4, 0.6) if _active_index != -1 else Color(1.0, 0.45, 0.4, 0.32)
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.3), 2.0)
