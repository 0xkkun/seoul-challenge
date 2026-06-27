extends Control

const OUTER_RING_ALPHA := 0.26
const OUTER_RING_PRESSED_ALPHA := 0.40
const OUTER_RING_DISABLED_ALPHA := 0.14
const INNER_RING_ALPHA := 0.10
const INNER_RING_PRESSED_ALPHA := 0.16
const INNER_RING_DISABLED_ALPHA := 0.06
const ICON_ALPHA := 0.56
const ICON_DISABLED_ALPHA := 0.28
const COOLDOWN_RING_ALPHA := 0.54

var _active_index: int = -1
var _uses_remaining := 0
var _max_uses := 0
var _cooldown_remaining := 0.0
var _cooldown := 0.0


func is_held() -> bool:
	return _active_index != -1


func release() -> void:
	if _active_index == -1:
		return
	_active_index = -1
	queue_redraw()


func get_cooldown_ratio() -> float:
	if _cooldown <= 0.0:
		return 0.0
	return clampf(_cooldown_remaining / _cooldown, 0.0, 1.0)


func get_uses_label() -> String:
	if _max_uses <= 0:
		return "-"
	return str(clampi(_uses_remaining, 0, _max_uses))


func get_visual_contract() -> Dictionary:
	return {
		"background_fill_alpha": 0.0,
		"pressed_fill_alpha": 0.0,
		"disabled_fill_alpha": 0.0,
		"shadow_alpha": 0.0,
		"center_icon": "chevron",
		"icon_alpha": ICON_ALPHA,
		"uses_label_visible": false,
		"outer_ring_alpha": OUTER_RING_ALPHA,
		"inner_ring_alpha": INNER_RING_ALPHA,
	}


func set_skill_state(payload: Dictionary) -> void:
	_uses_remaining = int(payload.get("uses_remaining", _uses_remaining))
	_max_uses = int(payload.get("max_uses", _max_uses))
	_cooldown_remaining = float(payload.get("cooldown_remaining", _cooldown_remaining))
	_cooldown = float(payload.get("cooldown", _cooldown))
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		release()
		return
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
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var enabled := _max_uses <= 0 or _uses_remaining > 0
	var outer_alpha := _ring_alpha(enabled, OUTER_RING_ALPHA, OUTER_RING_PRESSED_ALPHA, OUTER_RING_DISABLED_ALPHA)
	var inner_alpha := _ring_alpha(enabled, INNER_RING_ALPHA, INNER_RING_PRESSED_ALPHA, INNER_RING_DISABLED_ALPHA)
	draw_arc(center, radius - 2.0, 0.0, TAU, 48, Color(1, 1, 1, outer_alpha), 2.0, true)
	draw_arc(center, radius * 0.74, 0.0, TAU, 48, Color(1, 1, 1, inner_alpha), 2.0, true)
	if _cooldown > 0.0 and _cooldown_remaining > 0.0:
		var ratio := get_cooldown_ratio()
		draw_arc(center, radius * 0.88, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(1, 1, 1, COOLDOWN_RING_ALPHA), 4.0, true)
	_draw_center_icon(center, radius, ICON_ALPHA if enabled else ICON_DISABLED_ALPHA)


func _ring_alpha(enabled: bool, normal_alpha: float, pressed_alpha: float, disabled_alpha: float) -> float:
	if not enabled:
		return disabled_alpha
	return pressed_alpha if is_held() else normal_alpha


func _draw_center_icon(center: Vector2, radius: float, alpha: float) -> void:
	var color := Color(1, 1, 1, alpha)
	var width := maxf(3.0, radius * 0.085)
	var half_width := radius * 0.18
	var half_height := radius * 0.30
	var tip := center + Vector2(half_width, 0.0)
	draw_line(center + Vector2(-half_width, -half_height), tip, color, width, true)
	draw_line(tip, center + Vector2(-half_width, half_height), color, width, true)
