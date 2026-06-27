extends Node2D

const DEATH_FRAMES := preload("res://assets/effects/enemy_death_frames.tres")
const GROUP := &"enemy_death_fx"
const FRAME_SIZE := 64
const FRAME_COUNT := 12
const ANIMATION_SPEED := 18.0
const LIFETIME := 0.67
const Z_INDEX := 44

var _age := 0.0
var _animation: AnimatedSprite2D = null


func _ready() -> void:
	name = "EnemyDeathFade"
	z_index = maxi(z_index, Z_INDEX)
	add_to_group(GROUP)
	if _animation == null:
		_build_death_animation()
	set_process(true)


func capture_visual(_source: CanvasItem = null) -> void:
	_clear_visual()
	_build_death_animation()


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
		"captures_visual": false,
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
	if _age >= LIFETIME:
		queue_free()


func _clear_visual() -> void:
	if _animation != null and is_instance_valid(_animation):
		if _animation.get_parent() == self:
			remove_child(_animation)
		_animation.free()
	_animation = null


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
