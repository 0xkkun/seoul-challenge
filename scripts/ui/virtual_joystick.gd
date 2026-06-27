extends Control
## 가상 조이스틱(#52) — 영역 내 터치/드래그로 방향 벡터를 출력한다.
## get_value() 로 정규화 방향(0..1)을 읽는다. 자기 영역에서 시작한 터치 인덱스만 추적해
## 공격 버튼과 동시 멀티터치가 가능하다. (project.godot의 emulate_touch_from_mouse 로 마우스도 동작)

@export var max_radius: float = 90.0   ## 노브 이동 최대 반경 (px)
@export var deadzone: float = 0.18

var _active_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO
var _value: Vector2 = Vector2.ZERO


func get_value() -> Vector2:
	return _value


func release() -> void:
	if _active_index == -1 and _knob_offset == Vector2.ZERO and _value == Vector2.ZERO:
		return
	_active_index = -1
	_knob_offset = Vector2.ZERO
	_value = Vector2.ZERO
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		release()
		return
	if event is InputEventScreenTouch:
		_on_press(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag and event.index == _active_index:
		_on_move(event.position)


func _on_press(index: int, pos: Vector2, pressed: bool) -> void:
	if pressed:
		if _active_index == -1 and get_global_rect().has_point(pos):
			_active_index = index
			_origin = get_global_rect().get_center()
			_on_move(pos)
	elif index == _active_index:
		release()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release()


func _on_move(pos: Vector2) -> void:
	var raw := pos - _origin
	_knob_offset = raw.limit_length(max_radius)
	_value = compute_value(raw, max_radius, deadzone)
	queue_redraw()


## 오프셋 → 정규화 방향(반경 클램프 + 데드존). 순수 함수(테스트 대상).
func compute_value(offset: Vector2, radius: float, dz: float) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var v := offset.limit_length(radius) / radius
	return v if v.length() >= dz else Vector2.ZERO


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, max_radius, Color(1, 1, 1, 0.10))
	draw_arc(c, max_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.30), 2.0)
	draw_circle(c + _knob_offset, max_radius * 0.42, Color(1, 1, 1, 0.50))
