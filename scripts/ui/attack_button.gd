extends Control
## 공격 버튼(#52) — 영역 터치 동안 held. 자기 영역에서 시작한 터치 인덱스만 추적해
## 조이스틱과 동시 멀티터치가 가능하다. 드래그하면 그 방향으로 조준(우측 조준 스틱).

const AIM_DEADZONE := 14.0
const ICON_MODE_ATTACK := "attack"
const ICON_MODE_DIALOGUE := "dialogue"
const ATTACK_ICON_PATH := "res://assets/ui/icons/combat/damage_1.png"
const ICON_ALPHA := 0.56
const ATTACK_ICON_SCALE := 0.44
const DIALOGUE_ICON_SCALE := 0.34
const OUTER_RING_ALPHA := 0.28
const OUTER_RING_PRESSED_ALPHA := 0.42
const INNER_RING_ALPHA := 0.10
const INNER_RING_PRESSED_ALPHA := 0.16
const AIM_LINE_ALPHA := 0.52

var _active_index: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _aim: Vector2 = Vector2.ZERO
var _icon_mode := ICON_MODE_ATTACK
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


func set_icon_mode(next_icon_mode: String) -> void:
	var normalized := _normalize_icon_mode(next_icon_mode)
	if _icon_mode == normalized:
		return
	_icon_mode = normalized
	queue_redraw()


func get_icon_mode() -> String:
	return _icon_mode


func get_visual_contract() -> Dictionary:
	return {
		"background_fill_alpha": 0.0,
		"pressed_fill_alpha": 0.0,
		"shadow_alpha": 0.0,
		"icon_mode": _icon_mode,
		"icon_shape": "speech_bubble" if _icon_mode == ICON_MODE_DIALOGUE else "damage_asset",
		"icon_path": "" if _icon_mode == ICON_MODE_DIALOGUE else ATTACK_ICON_PATH,
		"icon_alpha": ICON_ALPHA,
		"icon_scale": _current_icon_scale(),
		"outer_ring_alpha": OUTER_RING_ALPHA,
		"inner_ring_alpha": INNER_RING_ALPHA,
	}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attack_icon = load(ATTACK_ICON_PATH) as Texture2D


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		release()
		return
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
	_draw_action_icon(c, r)
	if _aim != Vector2.ZERO:
		draw_line(c, c + _aim * (r * 0.84), Color(1, 1, 1, AIM_LINE_ALPHA), 3.0)


func _draw_action_icon(center: Vector2, radius: float) -> void:
	if _icon_mode == ICON_MODE_DIALOGUE:
		_draw_dialogue_icon(center, radius)
		return
	_draw_attack_icon(center, radius)


func _draw_attack_icon(center: Vector2, radius: float) -> void:
	if _attack_icon == null:
		_attack_icon = load(ATTACK_ICON_PATH) as Texture2D
	if _attack_icon == null:
		return
	var icon_size := Vector2.ONE * (radius * 2.0 * ATTACK_ICON_SCALE)
	var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
	draw_texture_rect(_attack_icon, icon_rect, false, Color(1, 1, 1, ICON_ALPHA))


func _draw_dialogue_icon(center: Vector2, radius: float) -> void:
	var icon_size := Vector2.ONE * (radius * 2.0 * DIALOGUE_ICON_SCALE)
	var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
	var pixel := maxf(2.0, floorf(icon_size.x / 11.0))
	var color := Color(1, 1, 1, ICON_ALPHA)
	var fill := Color(1, 1, 1, ICON_ALPHA * 0.18)
	var bubble := Rect2(
		Vector2(snappedf(icon_rect.position.x + pixel, pixel), snappedf(icon_rect.position.y + pixel * 1.4, pixel)),
		Vector2(snappedf(icon_size.x - pixel * 2.0, pixel), snappedf(icon_size.y - pixel * 3.2, pixel))
	)
	draw_rect(bubble, fill, true)
	draw_rect(bubble, color, false, pixel)
	var tail_a := Rect2(Vector2(bubble.position.x + bubble.size.x * 0.22, bubble.end.y - pixel), Vector2(pixel * 2.0, pixel))
	var tail_b := Rect2(Vector2(tail_a.position.x + pixel, tail_a.end.y), Vector2(pixel * 2.0, pixel))
	draw_rect(tail_a, color, true)
	draw_rect(tail_b, color, true)
	var line_y := bubble.position.y + bubble.size.y * 0.42
	draw_rect(Rect2(Vector2(bubble.position.x + pixel * 2.0, line_y), Vector2(bubble.size.x - pixel * 4.0, pixel)), color, true)
	draw_rect(Rect2(Vector2(bubble.position.x + pixel * 2.0, line_y + pixel * 2.0), Vector2(bubble.size.x - pixel * 6.0, pixel)), color, true)


func _current_icon_scale() -> float:
	return DIALOGUE_ICON_SCALE if _icon_mode == ICON_MODE_DIALOGUE else ATTACK_ICON_SCALE


func _normalize_icon_mode(value: String) -> String:
	match value:
		ICON_MODE_ATTACK, ICON_MODE_DIALOGUE:
			return value
		_:
			return ICON_MODE_ATTACK
