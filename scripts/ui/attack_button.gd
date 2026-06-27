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
const DIALOGUE_TAIL_BLOCKS := 1
const DIALOGUE_TAIL_STYLE := "emoji_corner"
const DIALOGUE_TAIL_DRAW_ORDER := "after_bubble"
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
var _dialogue_bubble_style := StyleBoxFlat.new()


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
		"dialogue_tail_style": DIALOGUE_TAIL_STYLE,
		"dialogue_tail_blocks": DIALOGUE_TAIL_BLOCKS,
		"dialogue_tail_draw_order": DIALOGUE_TAIL_DRAW_ORDER,
		"label_text": "",
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
	var geometry := build_dialogue_icon_geometry(center, radius)
	var bubble := geometry["bubble"] as Rect2
	var tail_points := geometry["tail_points"] as Array
	var line_rects := geometry["line_rects"] as Array
	var pixel := float(geometry["pixel"])
	var color := Color(1, 1, 1, ICON_ALPHA)
	var fill := Color(1, 1, 1, ICON_ALPHA * 0.18)
	var tail_polygon := PackedVector2Array([
		tail_points[0] as Vector2,
		tail_points[1] as Vector2,
		tail_points[2] as Vector2,
	])
	draw_style_box(_make_dialogue_bubble_style(fill, color, pixel), bubble)
	draw_polygon(tail_polygon, PackedColorArray([fill]))
	draw_polyline(tail_polygon, color, pixel, true)
	for line_rect: Rect2 in line_rects:
		draw_rect(line_rect, color, true)


func build_dialogue_icon_geometry(center: Vector2, radius: float) -> Dictionary:
	var icon_size := Vector2.ONE * (radius * 2.0 * DIALOGUE_ICON_SCALE)
	var icon_rect := Rect2(center - icon_size * 0.5, icon_size)
	var pixel := maxf(2.0, floorf(icon_size.x / 12.0))
	var bubble := Rect2(
		Vector2(snappedf(icon_rect.position.x + pixel, pixel), snappedf(icon_rect.position.y + pixel * 1.35, pixel)),
		Vector2(snappedf(icon_size.x - pixel * 2.0, pixel), snappedf(icon_size.y - pixel * 3.6, pixel))
	)
	var tail_start := Vector2(bubble.position.x + pixel * 3.0, bubble.end.y - pixel * 0.25)
	var tail_tip := Vector2(tail_start.x + pixel * 2.0, bubble.end.y + pixel * 2.0)
	var tail_end := Vector2(tail_start.x + pixel * 5.0, bubble.end.y - pixel * 0.25)
	var line_y := bubble.position.y + bubble.size.y * 0.42
	return {
		"bubble": bubble,
		"tail_points": [tail_start, tail_tip, tail_end],
		"line_rects": [
			Rect2(Vector2(bubble.position.x + pixel * 2.6, line_y), Vector2(bubble.size.x - pixel * 5.2, pixel)),
			Rect2(Vector2(bubble.position.x + pixel * 2.6, line_y + pixel * 2.2), Vector2(bubble.size.x - pixel * 7.2, pixel)),
		],
		"pixel": pixel,
	}


func _make_dialogue_bubble_style(fill: Color, border: Color, pixel: float) -> StyleBoxFlat:
	_dialogue_bubble_style.bg_color = fill
	_dialogue_bubble_style.border_color = border
	_dialogue_bubble_style.set_border_width_all(int(maxf(1.0, roundf(pixel))))
	_dialogue_bubble_style.set_corner_radius_all(int(maxf(2.0, roundf(pixel * 2.2))))
	return _dialogue_bubble_style


func _current_icon_scale() -> float:
	return DIALOGUE_ICON_SCALE if _icon_mode == ICON_MODE_DIALOGUE else ATTACK_ICON_SCALE


func _normalize_icon_mode(value: String) -> String:
	match value:
		ICON_MODE_ATTACK, ICON_MODE_DIALOGUE:
			return value
		_:
			return ICON_MODE_ATTACK
