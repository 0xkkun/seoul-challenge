extends Node2D

const GROUP := &"enemy_death_fx"
const LIFETIME := 0.22
const FLASH_TIME := 0.04
const FLASH_MULTIPLIER := 1.24
const Z_INDEX := 44

var _age := 0.0
var _visual: CanvasItem = null
var _base_visual_modulate := Color.WHITE


func _ready() -> void:
	name = "EnemyDeathFade"
	z_index = maxi(z_index, Z_INDEX)
	add_to_group(GROUP)
	if _visual == null:
		_build_fallback_visual()
	_apply_visual_state()
	set_process(true)


func capture_visual(source: CanvasItem) -> void:
	_clear_visual()
	if source == null:
		_build_fallback_visual()
		return
	var snapshot := source.duplicate()
	if not snapshot is CanvasItem:
		snapshot.queue_free()
		_build_fallback_visual()
		return
	var visual_snapshot := snapshot as CanvasItem
	visual_snapshot.name = "VisualSnapshot"
	visual_snapshot.visible = true
	visual_snapshot.modulate.a = source.modulate.a
	if visual_snapshot is AnimatedSprite2D:
		(visual_snapshot as AnimatedSprite2D).stop()
	add_child(visual_snapshot)
	_visual = visual_snapshot
	_base_visual_modulate = visual_snapshot.modulate
	_apply_visual_state()


func get_visual_contract() -> Dictionary:
	return {
		"group": GROUP,
		"draw_style": &"sprite_opacity_fade",
		"lifetime": LIFETIME,
		"z_index": Z_INDEX,
		"shard_count": 0,
		"uses_line_art": false,
		"animates_scale": false,
		"captures_visual": true,
		"uses_detached_node": true,
	}


func _process(delta: float) -> void:
	_age += maxf(0.0, delta)
	_apply_visual_state()
	if _age >= LIFETIME:
		queue_free()


func _apply_visual_state() -> void:
	var ratio := clampf(_age / LIFETIME, 0.0, 1.0)
	modulate.a = 1.0 - ratio
	if _visual == null:
		return
	var flash_ratio := clampf(_age / FLASH_TIME, 0.0, 1.0) if FLASH_TIME > 0.0 else 1.0
	var brighten := lerpf(FLASH_MULTIPLIER, 1.0, flash_ratio)
	_visual.modulate = Color(
		_base_visual_modulate.r * brighten,
		_base_visual_modulate.g * brighten,
		_base_visual_modulate.b * brighten,
		_base_visual_modulate.a
	)


func _clear_visual() -> void:
	if _visual != null and is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null


func _build_fallback_visual() -> void:
	var fallback := Polygon2D.new()
	fallback.name = "VisualSnapshot"
	fallback.color = Color(1.0, 1.0, 1.0, 0.85)
	fallback.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-10.0, 0.0),
	])
	add_child(fallback)
	_visual = fallback
	_base_visual_modulate = fallback.modulate
