extends RefCounted

const DEFAULT_WIDTH := 36.0
const DEFAULT_HEIGHT := 4.0
const DEFAULT_PADDING := 8.0
const FALLBACK_HALF_HEIGHT := 16.0
const Z_INDEX_BG := 10
const Z_INDEX_FILL := 11

var _bg: ColorRect = null
var _fill: ColorRect = null
var _width := DEFAULT_WIDTH
var _height := DEFAULT_HEIGHT
var _ratio := 1.0


func bind(bg: ColorRect, fill: ColorRect) -> void:
	_bg = bg
	_fill = fill
	_apply_geometry()
	hide_bar()


func configure(width: float = DEFAULT_WIDTH, height: float = DEFAULT_HEIGHT) -> void:
	_width = maxf(1.0, width)
	_height = maxf(1.0, height)
	_apply_geometry()


func reposition_above_visual(visual: CanvasItem, padding: float = DEFAULT_PADDING) -> void:
	var y := -FALLBACK_HALF_HEIGHT - padding
	var center_x := 0.0
	if visual != null:
		center_x = _visual_center_x(visual)
		y = _visual_top_y(visual) - maxf(0.0, padding)
	var position := Vector2(center_x - _width * 0.5, y)
	if _bg != null:
		_bg.position = position
	if _fill != null:
		_fill.position = position


func update(hp: float, max_hp: float) -> void:
	if _bg == null or _fill == null:
		return
	if max_hp <= 0.0:
		hide_bar()
		return
	_ratio = clampf(hp / max_hp, 0.0, 1.0)
	if _ratio >= 1.0:
		_bg.visible = false
		_fill.visible = false
		_fill.size = Vector2(_width, _height)
		return
	_bg.visible = true
	_fill.visible = true
	_bg.z_index = Z_INDEX_BG
	_fill.z_index = Z_INDEX_FILL
	_bg.size = Vector2(_width, _height)
	_fill.size = Vector2(_width * _ratio, _height)


func hide_bar() -> void:
	_ratio = 1.0
	if _bg != null:
		_bg.visible = false
		_bg.size = Vector2(_width, _height)
	if _fill != null:
		_fill.visible = false
		_fill.size = Vector2(_width, _height)


func get_snapshot() -> Dictionary:
	return {
		"visible": (_bg != null and _fill != null and _bg.visible and _fill.visible),
		"ratio": _ratio,
		"position_y": _bg.position.y if _bg != null else 0.0,
		"fill_width": _fill.size.x if _fill != null else 0.0,
		"max_width": _bg.size.x if _bg != null else _width,
	}


func _apply_geometry() -> void:
	if _bg != null:
		_bg.size = Vector2(_width, _height)
		_bg.z_index = Z_INDEX_BG
	if _fill != null:
		_fill.size = Vector2(_width * _ratio, _height)
		_fill.z_index = Z_INDEX_FILL


func _visual_top_y(visual: CanvasItem) -> float:
	var sprite := visual as AnimatedSprite2D
	if sprite != null:
		var frame_height := _animated_sprite_frame_height(sprite)
		return sprite.position.y - frame_height * absf(sprite.scale.y) * 0.5

	var polygon := visual as Polygon2D
	if polygon != null and not polygon.polygon.is_empty():
		var min_y := polygon.polygon[0].y
		for point: Vector2 in polygon.polygon:
			min_y = minf(min_y, point.y)
		return polygon.position.y + min_y * absf(polygon.scale.y)

	var node2d := visual as Node2D
	if node2d != null:
		return node2d.position.y - FALLBACK_HALF_HEIGHT * absf(node2d.scale.y)

	var control := visual as Control
	if control != null:
		return control.position.y - FALLBACK_HALF_HEIGHT * absf(control.scale.y)

	return -FALLBACK_HALF_HEIGHT


func _visual_center_x(visual: CanvasItem) -> float:
	var node2d := visual as Node2D
	if node2d != null:
		return node2d.position.x

	var control := visual as Control
	if control != null:
		return control.position.x

	return 0.0


func _animated_sprite_frame_height(sprite: AnimatedSprite2D) -> float:
	if sprite.sprite_frames == null:
		return FALLBACK_HALF_HEIGHT * 2.0
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return FALLBACK_HALF_HEIGHT * 2.0
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if texture == null:
		return FALLBACK_HALF_HEIGHT * 2.0
	return float(texture.get_height())
