extends CharacterBody2D
## 늑대 돌진형 적. 추적하다 사거리 안에서 예고 후 직선 돌진한다.

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")
const StatusEffectController = preload("res://scripts/combat/status_effect_controller.gd")
const FACING_DEADZONE := 0.01

signal defeated(enemy)

@export var max_hp: int = 4
@export var move_speed: float = 108.0
@export var contact_damage: int = 1
@export var contact_range: float = 34.0
@export var dash_trigger_range: float = 118.0
@export var dash_speed: float = 292.0
@export var dash_windup_time: float = 0.24
@export var dash_duration: float = 0.28
@export var dash_recover_time: float = 0.52
@export var hit_invuln_time: float = 0.12
@export var target_group: StringName = &"player"
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"

var _hp: int = 0
var _dead := false
var _dash_state: StringName = &"chase"
var _dash_timer := 0.0
var _dash_direction := Vector2.RIGHT
var _dash_hit_targets := {}
var _hit_reaction: Node = null
var _status_effects: Node = null
var _movement_bounds := Rect2()
var _movement_bounds_enabled := false
@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	_hp = max_hp
	add_to_group(&"enemy")
	_ensure_hit_reaction()
	_ensure_status_effects()


func _physics_process(delta: float) -> void:
	tick_hit_reaction(delta)
	tick_status_effects(delta)
	var target := _find_target()
	if target == null:
		velocity = Vector2.ZERO
		_update_animation()
		return
	if is_status_action_blocked() or is_status_movement_blocked():
		velocity = Vector2.ZERO
	else:
		velocity = tick_dash_ai(delta, global_position, target.global_position)
		if _dash_state == &"chase":
			velocity *= get_status_speed_multiplier()
	move_and_slide()
	clamp_to_movement_bounds()
	if _dash_state == &"dash":
		_try_dash_hit(target)
	_update_animation()


func get_dash_state() -> StringName:
	return _dash_state


func tick_dash_ai(delta: float, origin: Vector2, target_position: Vector2) -> Vector2:
	match _dash_state:
		&"prepare":
			_dash_timer = maxf(0.0, _dash_timer - delta)
			if _dash_timer > 0.0:
				return Vector2.ZERO
			_start_dash(origin, target_position)
			return _dash_direction * dash_speed
		&"dash":
			_dash_timer = maxf(0.0, _dash_timer - delta)
			if _dash_timer <= 0.0:
				_start_recover()
				return Vector2.ZERO
			return _dash_direction * dash_speed
		&"recover":
			_dash_timer = maxf(0.0, _dash_timer - delta)
			if _dash_timer <= 0.0:
				_dash_state = &"chase"
			return Vector2.ZERO

	var offset := target_position - origin
	if offset.length() <= dash_trigger_range:
		_dash_state = &"prepare"
		_dash_timer = dash_windup_time
		_dash_direction = aim_direction(origin, target_position)
		_play_attack_animation(_dash_direction)
		return Vector2.ZERO
	return chase_velocity(origin, target_position, move_speed)


func chase_velocity(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


func aim_direction(from: Vector2, to: Vector2) -> Vector2:
	var offset := to - from
	return offset.normalized() if offset.length() > 0.001 else _dash_direction


func is_dead(hp: int) -> bool:
	return hp <= 0


func set_movement_bounds(bounds: Rect2) -> void:
	_movement_bounds = bounds
	_movement_bounds_enabled = bounds.size.x > 0.0 and bounds.size.y > 0.0
	clamp_to_movement_bounds()


func clear_movement_bounds() -> void:
	_movement_bounds = Rect2()
	_movement_bounds_enabled = false


func has_movement_bounds() -> bool:
	return _movement_bounds_enabled


func get_movement_bounds() -> Rect2:
	return _movement_bounds


func clamp_to_movement_bounds() -> bool:
	if not _movement_bounds_enabled:
		return false
	var before := global_position
	var clamped := clamp_position_to_bounds(before, _movement_bounds)
	global_position = clamped
	if not is_equal_approx(before.x, clamped.x):
		velocity.x = 0.0
	if not is_equal_approx(before.y, clamped.y):
		velocity.y = 0.0
	return not before.is_equal_approx(clamped)


func clamp_position_to_bounds(position: Vector2, bounds: Rect2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	return Vector2(
		clampf(position.x, bounds.position.x, bounds.end.x),
		clampf(position.y, bounds.position.y, bounds.end.y)
	)


func is_hit_invulnerable() -> bool:
	return bool(_ensure_hit_reaction().call("is_active"))


func tick_hit_reaction(delta: float) -> void:
	_ensure_hit_reaction().call("tick", delta)


func _trigger_hit_reaction() -> void:
	_ensure_hit_reaction().call("trigger", hit_invuln_time)


func _ensure_hit_reaction() -> Node:
	if _hit_reaction != null and is_instance_valid(_hit_reaction):
		return _hit_reaction
	_hit_reaction = HitReactionController.new()
	_hit_reaction.name = "HitReaction"
	add_child(_hit_reaction)
	var visual := _get_visual()
	if visual != null:
		_hit_reaction.call("bind_visual", visual)
	return _hit_reaction


func apply_status_effect(effect_id: StringName, duration: float, params: Dictionary = {}) -> void:
	_ensure_status_effects().call("apply_effect", effect_id, duration, params)


func tick_status_effects(delta: float) -> void:
	_ensure_status_effects().call("tick", delta, self)


func has_status_effect(effect_id: StringName) -> bool:
	return bool(_ensure_status_effects().call("has_effect", effect_id))


func clear_status_effect(effect_id: StringName) -> void:
	_ensure_status_effects().call("clear_effect", effect_id)


func clear_negative_status_effects() -> void:
	_ensure_status_effects().call("clear_negative_effects")


func get_status_speed_multiplier() -> float:
	return float(_ensure_status_effects().call("get_speed_multiplier"))


func is_status_movement_blocked() -> bool:
	return bool(_ensure_status_effects().call("blocks_movement"))


func is_status_action_blocked() -> bool:
	return bool(_ensure_status_effects().call("blocks_actions"))


func _ensure_status_effects() -> Node:
	if _status_effects != null and is_instance_valid(_status_effects):
		return _status_effects
	_status_effects = StatusEffectController.new()
	_status_effects.name = "StatusEffects"
	add_child(_status_effects)
	return _status_effects


func take_damage(amount: int) -> void:
	if _dead or is_hit_invulnerable():
		return
	HapticManager.on_enemy_hit()
	_hp -= amount
	if is_dead(_hp):
		_die()
	else:
		_trigger_hit_reaction()


func _die() -> void:
	if _dead:
		return
	_dead = true
	defeated.emit(self)
	queue_free()


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _try_dash_hit(target: Node2D) -> void:
	if _dash_state != &"dash" or target == null:
		return
	if global_position.distance_to(target.global_position) > contact_range:
		return
	var target_id := target.get_instance_id()
	if _dash_hit_targets.has(target_id):
		return
	_dash_hit_targets[target_id] = true
	_play_attack_animation(target.global_position - global_position)
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)


func _start_dash(origin: Vector2, target_position: Vector2) -> void:
	_dash_state = &"dash"
	_dash_timer = dash_duration
	_dash_direction = aim_direction(origin, target_position)
	_dash_hit_targets.clear()
	_play_attack_animation(_dash_direction)


func _start_recover() -> void:
	_dash_state = &"recover"
	_dash_timer = dash_recover_time
	_dash_hit_targets.clear()


func _update_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.animation == attack_animation and _sprite.is_playing():
		return
	_update_sprite_facing()
	if _sprite.sprite_frames.has_animation(move_animation) and _sprite.animation != move_animation:
		_sprite.play(move_animation)


func _play_attack_animation(facing_direction: Vector2 = Vector2.ZERO) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	_set_sprite_facing_from_direction(facing_direction)
	if _sprite.sprite_frames.has_animation(attack_animation):
		_sprite.play(attack_animation)


func _update_sprite_facing() -> void:
	_set_sprite_facing_from_direction(velocity)


func _set_sprite_facing_from_direction(direction: Vector2) -> void:
	if direction.x < -FACING_DEADZONE:
		_sprite.flip_h = true
	elif direction.x > FACING_DEADZONE:
		_sprite.flip_h = false


func _get_visual() -> CanvasItem:
	var sprite := get_node_or_null(^"Sprite") as CanvasItem
	if sprite != null:
		return sprite
	return get_node_or_null(^"Placeholder") as CanvasItem
