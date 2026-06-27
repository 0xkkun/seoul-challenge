extends Control
## 공격 버튼(#52) — 영역 터치 동안 held. 자기 영역에서 시작한 터치 인덱스만 추적해
## 조이스틱과 동시 멀티터치가 가능하다. 드래그하면 그 방향으로 조준(우측 조준 스틱).

const AIM_DEADZONE := 14.0
const ATTACK_ICON_PATH := "res://assets/ui/icons/combat/damage_1.png"
const ICON_ALPHA := 0.56
const ICON_SCALE := 0.44
const OUTER_RING_ALPHA := 0.28
const OUTER_RING_PRESSED_ALPHA := 0.42
const INNER_RING_ALPHA := 0.10
const INNER_RING_PRESSED_ALPHA := 0.16
const AIM_LINE_ALPHA := 0.52

var _active_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.ZERO
var _attack_icon: Texture2D


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


func get_visual_contract() -> Dictionary:
	return {
		"background_fill_alpha": 0.0,
		"pressed_fill_alpha": 0.0,
		"shadow_alpha": 0.0,
		"icon_path": ATTACK_ICON_PATH,
		"icon_alpha": ICON_ALPHA,
		"outer_ring_alpha": OUTER_RING_ALPHA,
		"inner_ring_alpha": INNER_RING_ALPHA,
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_icon = load(ATTACK_ICON_PATH) as Texture2D


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
	var outer_alpha := OUTER_RING_PRESSED_ALPHA if is_held() else OUTER_RING_ALPHA
	var inner_alpha := INNER_RING_PRESSED_ALPHA if is_held() else INNER_RING_ALPHA
	draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(1, 1, 1, outer_alpha), 2.0, true)
	draw_arc(c, r * 0.76, 0.0, TAU, 48, Color(1, 1, 1, inner_alpha), 2.0, true)
	_draw_attack_icon(c, r)
	if _aim != Vector2.ZERO:
		draw_line(c, c + _aim * (r * 0.84), Color(1, 1, 1, AIM_LINE_ALPHA), 3.0)


func _draw_attack_icon(center: Vector2, radius: float) -> void:
	if _attack_icon == null:
		_attack_icon = load(ATTACK_ICON_PATH) as Texture2D
	if _attack_icon == null:
		return
	var icon_size := Vector2.ONE * (radius * 2.0 * ICON_SCALE)
	var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
	draw_texture_rect(_attack_icon, icon_rect, false, Color(1, 1, 1, ICON_ALPHA))
