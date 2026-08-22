class_name FloatingCombatText
extends Node2D

const UiFontRoles = preload("res://scripts/ui/ui_font_roles.gd")
const Tokens = preload("res://scripts/ui/onboarding_visual_tokens.gd")

var _lifetime_tween: Tween = null
var _activation_generation := 0
var _style_id: StringName = &""

@onready var _label: Label = $Label


func _ready() -> void:
	_reset_visual_state()
	visible = false


func style_for(style: StringName) -> Dictionary:
	if style == &"parry":
		return {
			"font_size": 32,
			"duration": 1.0,
			"rise": 20.0,
			"punch_scale": 1.28,
			"color": Color(0.78, 1.0, 0.97, 1.0),
			"outline_color": Tokens.CYAN_TIMING,
			"outline_size": 5,
		}
	return {
		"font_size": 24,
		"duration": 0.8,
		"rise": 16.0,
		"punch_scale": 1.16,
		"color": Tokens.PAPER_TEXT,
		"outline_color": Tokens.SOFT_SHADOW,
		"outline_size": 3,
	}


func activate_from_pool() -> void:
	_activation_generation += 1
	_kill_lifetime_tween()
	_reset_visual_state()
	visible = true


func reset_for_pool() -> void:
	_activation_generation += 1
	_kill_lifetime_tween()
	_reset_visual_state()
	visible = false


func initialize(world_position: Vector2, text: String, style: StringName) -> void:
	_kill_lifetime_tween()
	_reset_visual_state()
	_style_id = style
	global_position = world_position
	visible = true
	var style_model := style_for(style)
	_label.text = text
	_label.add_theme_font_size_override("font_size", int(style_model.get("font_size", 24)))
	_label.add_theme_color_override("font_color", style_model.get("color", Tokens.PAPER_TEXT) as Color)
	_label.add_theme_color_override("font_outline_color", style_model.get("outline_color", Tokens.SOFT_SHADOW) as Color)
	_label.add_theme_constant_override("outline_size", int(style_model.get("outline_size", 3)))
	UiFontRoles.apply_title(_label)
	var token := _activation_generation
	var start_position := position
	var duration := float(style_model.get("duration", 0.8))
	_lifetime_tween = create_tween().set_ignore_time_scale(true)
	_lifetime_tween.tween_method(
		_apply_lifetime_progress.bind(start_position, style_model.duplicate(true), token),
		0.0,
		1.0,
		duration
	)
	_lifetime_tween.tween_callback(_on_lifetime_finished.bind(token))


func get_snapshot() -> Dictionary:
	return {
		"text": _label.text if _label != null else "",
		"style": _style_id,
		"modulate": modulate,
		"scale": scale,
		"position": position,
		"tween_active": _lifetime_tween != null and _lifetime_tween.is_valid(),
		"generation": _activation_generation,
	}


func _apply_lifetime_progress(
		progress: float,
		start_position: Vector2,
		style_model: Dictionary,
		token: int
) -> void:
	if token != _activation_generation:
		return
	var t := clampf(progress, 0.0, 1.0)
	position = start_position + Vector2.UP * float(style_model.get("rise", 16.0)) * t
	var fade_start := 0.65
	modulate.a = 1.0 if t <= fade_start else 1.0 - ((t - fade_start) / (1.0 - fade_start))
	var punch := float(style_model.get("punch_scale", 1.16))
	var scale_value := 1.0
	if t < 0.14:
		scale_value = lerpf(1.0, punch, t / 0.14)
	elif t < 0.32:
		scale_value = lerpf(punch, 1.0, (t - 0.14) / 0.18)
	scale = Vector2.ONE * scale_value


func _on_lifetime_finished(token: int) -> void:
	if token != _activation_generation:
		return
	_lifetime_tween = null
	if has_node("/root/PoolManager"):
		PoolManager.release(self)


func _kill_lifetime_tween() -> void:
	if _lifetime_tween != null and _lifetime_tween.is_valid():
		_lifetime_tween.kill()
	_lifetime_tween = null


func _reset_visual_state() -> void:
	_style_id = &""
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	if _label != null:
		_label.text = ""
		_label.add_theme_font_size_override("font_size", 24)
		_label.add_theme_color_override("font_color", Tokens.PAPER_TEXT)
		_label.add_theme_color_override("font_outline_color", Tokens.SOFT_SHADOW)
		_label.add_theme_constant_override("outline_size", 3)


func _exit_tree() -> void:
	_kill_lifetime_tween()
