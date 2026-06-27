extends Control

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


func set_skill_state(payload: Dictionary) -> void:
	_uses_remaining = int(payload.get("uses_remaining", _uses_remaining))
	_max_uses = int(payload.get("max_uses", _max_uses))
	_cooldown_remaining = float(payload.get("cooldown_remaining", _cooldown_remaining))
	_cooldown = float(payload.get("cooldown", _cooldown))
	queue_redraw()


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
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var base_color := Color(0.25, 0.55, 1.0, 0.68) if is_held() else Color(0.25, 0.55, 1.0, 0.36)
	if _uses_remaining <= 0:
		base_color = Color(0.16, 0.16, 0.18, 0.36)
	draw_circle(center, radius, base_color)
	draw_arc(center, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	if _cooldown > 0.0 and _cooldown_remaining > 0.0:
		var ratio := get_cooldown_ratio()
		draw_arc(center, radius * 0.74, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36, Color(1, 1, 1, 0.72), 5.0)
	var font := get_theme_default_font()
	var font_size := 28
	var label := get_uses_label()
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var text_pos := center - Vector2(text_size.x * 0.5, -text_size.y * 0.35)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1, 1, 1, 0.88))
