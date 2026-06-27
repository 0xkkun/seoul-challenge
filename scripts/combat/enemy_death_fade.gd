extends Node2D

const DEATH_FRAMES := preload("res://assets/effects/enemy_death_frames.tres")
const GROUP := &"enemy_death_fx"
const FRAME_SIZE := 64
const FRAME_COUNT := 12
const ANIMATION_SPEED := 18.0
const LIFETIME := 0.67
const Z_INDEX := 44
const VISUAL_MIN_Y_SCALE := 0.14

var _age := 0.0
var _animation: AnimatedSprite2D = null
var _squash_visual: Node2D = null


func _ready() -> void:
	name = "EnemyDeathFade"
	z_index = maxi(z_index, Z_INDEX)
	add_to_group(GROUP)
	if _animation == null:
		_build_death_animation()
	set_process(true)


func capture_visual(source: CanvasItem = null) -> void:
	_clear_captured_visual()
	var source_node := source as Node2D
	if source_node == null:
		return
	var clone := _clone_visual(source)
	if clone == null:
		return
	_squash_visual = Node2D.new()
	_squash_visual.name = "SquashVisual"
	_squash_visual.z_index = 0
	_squash_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_squash_visual)
	_squash_visual.add_child(clone)
	clone.global_transform = source_node.global_transform
	_update_captured_visual()


func get_visual_contract() -> Dictionary:
	return {
		"group": GROUP,
		"draw_style": &"sprite_sheet_animation",
		"lifetime": LIFETIME,
		"z_index": Z_INDEX,
		"frame_size": FRAME_SIZE,
		"frame_count": FRAME_COUNT,
		"animation_speed": ANIMATION_SPEED,
		"shard_count": 0,
		"uses_line_art": false,
		"animates_scale": false,
		"captures_visual": true,
		"squashes_captured_visual": true,
		"visual_min_y_scale": VISUAL_MIN_Y_SCALE,
		"uses_detached_node": true,
		"anchors_to_feet": true,
	}


static func foot_position_for(owner: Node2D, visual: CanvasItem) -> Vector2:
	if owner == null:
		return Vector2.ZERO
	var animated := visual as AnimatedSprite2D
	if animated != null:
		return _animated_sprite_foot_position(animated, owner.global_position)
	var sprite := visual as Sprite2D
	if sprite != null:
		return _sprite_foot_position(sprite, owner.global_position)
	var polygon := visual as Polygon2D
	if polygon != null:
		return _polygon_foot_position(polygon, owner.global_position)
	return owner.global_position


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	_update_captured_visual()
	if _age >= LIFETIME:
		queue_free()


func _clear_captured_visual() -> void:
	if _squash_visual != null and is_instance_valid(_squash_visual):
		if _squash_visual.get_parent() == self:
			remove_child(_squash_visual)
		_squash_visual.free()
	_squash_visual = null


func _update_captured_visual() -> void:
	if _squash_visual == null or not is_instance_valid(_squash_visual):
		return
	var progress := clampf(_age / LIFETIME, 0.0, 1.0)
	var eased := progress * progress * (3.0 - (2.0 * progress))
	_squash_visual.scale = Vector2(1.0, lerpf(1.0, VISUAL_MIN_Y_SCALE, eased))
	_squash_visual.modulate.a = 1.0 - eased


func _build_death_animation() -> void:
	_animation = AnimatedSprite2D.new()
	_animation.name = "DeathAnimation"
	_animation.sprite_frames = DEATH_FRAMES
	_animation.animation = &"death"
	_animation.centered = true
	_animation.position = Vector2(0.0, -FRAME_SIZE * 0.5)
	_animation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animation.z_index = 1
	add_child(_animation)
	_animation.play(&"death")
	if not _animation.animation_finished.is_connected(_on_animation_finished):
		_animation.animation_finished.connect(_on_animation_finished)


func _clone_visual(source: CanvasItem) -> Node2D:
	var animated := source as AnimatedSprite2D
	if animated != null:
		return _clone_animated_sprite(animated)
	var sprite := source as Sprite2D
	if sprite != null:
		return _clone_sprite(sprite)
	var polygon := source as Polygon2D
	if polygon != null:
		return _clone_polygon(polygon)
	var source_node := source as Node2D
	if source_node == null:
		return null
	var clone := source_node.duplicate(0) as Node2D
	if clone != null:
		_prepare_clone_canvas_item(source, clone)
	return clone


func _clone_animated_sprite(source: AnimatedSprite2D) -> AnimatedSprite2D:
	var clone := AnimatedSprite2D.new()
	clone.sprite_frames = source.sprite_frames
	clone.animation = source.animation
	clone.frame = source.frame
	clone.frame_progress = source.frame_progress
	clone.centered = source.centered
	clone.offset = source.offset
	clone.flip_h = source.flip_h
	clone.flip_v = source.flip_v
	clone.stop()
	_prepare_clone_canvas_item(source, clone)
	return clone


func _clone_sprite(source: Sprite2D) -> Sprite2D:
	var clone := Sprite2D.new()
	clone.texture = source.texture
	clone.centered = source.centered
	clone.offset = source.offset
	clone.flip_h = source.flip_h
	clone.flip_v = source.flip_v
	clone.hframes = source.hframes
	clone.vframes = source.vframes
	clone.frame = source.frame
	clone.region_enabled = source.region_enabled
	clone.region_rect = source.region_rect
	clone.region_filter_clip_enabled = source.region_filter_clip_enabled
	_prepare_clone_canvas_item(source, clone)
	return clone


func _clone_polygon(source: Polygon2D) -> Polygon2D:
	var clone := Polygon2D.new()
	clone.polygon = source.polygon
	clone.color = source.color
	clone.texture = source.texture
	clone.texture_offset = source.texture_offset
	clone.texture_rotation = source.texture_rotation
	clone.texture_scale = source.texture_scale
	clone.uv = source.uv
	clone.polygons = source.polygons
	_prepare_clone_canvas_item(source, clone)
	return clone


func _prepare_clone_canvas_item(source: CanvasItem, clone: CanvasItem) -> void:
	clone.name = "CapturedMonster"
	clone.visible = source.visible
	clone.modulate = source.modulate
	clone.self_modulate = source.self_modulate
	clone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clone.z_index = 0
	clone.z_as_relative = true


func _on_animation_finished() -> void:
	queue_free()


static func _animated_sprite_foot_position(sprite: AnimatedSprite2D, fallback: Vector2) -> Vector2:
	if sprite.sprite_frames == null:
		return fallback
	if not sprite.sprite_frames.has_animation(sprite.animation):
		return fallback
	var frame_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if frame_texture == null:
		return fallback
	var bottom_y: float = frame_texture.get_height() * 0.5 if sprite.centered else frame_texture.get_height()
	return sprite.to_global(Vector2(0.0, bottom_y))


static func _sprite_foot_position(sprite: Sprite2D, fallback: Vector2) -> Vector2:
	if sprite.texture == null:
		return fallback
	var frame_height := float(sprite.texture.get_height()) / float(maxi(1, sprite.vframes))
	var bottom_y: float = frame_height * 0.5 if sprite.centered else frame_height
	return sprite.to_global(Vector2(0.0, bottom_y))


static func _polygon_foot_position(polygon: Polygon2D, fallback: Vector2) -> Vector2:
	if polygon.polygon.is_empty():
		return fallback
	var max_y := polygon.polygon[0].y
	for point: Vector2 in polygon.polygon:
		max_y = maxf(max_y, point.y)
	return polygon.to_global(Vector2(0.0, max_y))
