extends CharacterBody2D
## #11 잡몹(체이서) — 플레이어 추적, 정화탄 피격(take_damage), 처치 시 defeated 방출, 접촉 데미지.
## 추적 수학은 순수 함수로 분리해 단위 테스트한다.

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")
const StatusEffectController = preload("res://scripts/combat/status_effect_controller.gd")
const SpawnFadeController = preload("res://scripts/combat/spawn_fade_controller.gd")
const EnemyDeathFade = preload("res://scripts/combat/enemy_death_fade.gd")
const EnemyHealthBar = preload("res://scripts/enemies/enemy_health_bar.gd")
const FACING_DEADZONE := 0.01

## 처치됨 — RoomManager/전투방이 듣고 방 클리어 카운트에 사용한다(계약 #19).
signal defeated(enemy)

@export var max_hp: int = 3
@export var move_speed: float = 90.0       ## 추적 속도 (px/s)
@export var contact_damage: int = 1        ## 접촉 시 플레이어 피해
@export var contact_range: float = 28.0    ## 접촉 판정 거리 (px)
@export var contact_cooldown: float = 0.6  ## 접촉 데미지 간격 (s)
@export var hit_invuln_time: float = 0.12  ## 피격 직후 중복 피해 방지/플래시 시간
@export var target_group: StringName = &"player"
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"
@export var health_bar_width: float = 36.0
@export var health_bar_height: float = 4.0
@export var spawn_fade_time: float = 0.35

var _hp: int = 0
var _contact_timer: float = 0.0
var _dead: bool = false
var _hit_reaction: Node = null
var _status_effects: Node = null
var _spawn_fade: Node = null
var _health_bar: RefCounted = null
var _movement_bounds := Rect2()
var _movement_bounds_enabled := false
@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	_hp = max_hp
	add_to_group(&"enemy")
	_ensure_hit_reaction()
	_ensure_status_effects()
	_ensure_spawn_fade()
	_reset_health_bar()


func _physics_process(delta: float) -> void:
	tick_hit_reaction(delta)
	tick_status_effects(delta)
	tick_spawn_fade(delta)
	_contact_timer = maxf(0.0, _contact_timer - delta)
	if is_spawn_protected():
		velocity = Vector2.ZERO
		move_and_slide()
		clamp_to_movement_bounds()
		_update_animation()
		return
	var target := _find_target()
	if target == null:
		_update_animation()
		return
	if is_status_action_blocked():
		velocity = Vector2.ZERO
		move_and_slide()
		clamp_to_movement_bounds()
		_update_animation()
		return
	if is_status_movement_blocked():
		velocity = Vector2.ZERO
		move_and_slide()
		clamp_to_movement_bounds()
		_update_animation()
		_try_contact(target)
		return
	velocity = chase_velocity(
		global_position,
		target.global_position,
		move_speed * get_status_speed_multiplier(),
		contact_range
	)
	move_and_slide()
	clamp_to_movement_bounds()
	_update_animation()
	_try_contact(target)


# --- 순수 함수(테스트 대상) ---

## from→to 향하는 추적 속도. 같은 위치거나 정지 거리 안이면 ZERO.
func chase_velocity(from: Vector2, to: Vector2, speed: float, stop_distance: float = 0.0) -> Vector2:
	var dir := to - from
	if dir.length() <= maxf(0.0, stop_distance):
		return Vector2.ZERO
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


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


# --- 피격 반응 (계약 #136) ---

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


# --- 상태이상 (계약 #51) ---

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


# --- 등장 페이드 / 스폰 보호 ---

func start_spawn_fade(duration: float = -1.0) -> void:
	var fade_duration := spawn_fade_time if duration < 0.0 else duration
	_ensure_spawn_fade().call("start", fade_duration, _get_visual())


func tick_spawn_fade(delta: float) -> void:
	_ensure_spawn_fade().call("tick", delta)


func is_spawn_protected() -> bool:
	return bool(_ensure_spawn_fade().call("is_active"))


func _ensure_spawn_fade() -> Node:
	if _spawn_fade != null and is_instance_valid(_spawn_fade):
		return _spawn_fade
	_spawn_fade = SpawnFadeController.new()
	_spawn_fade.name = "SpawnFade"
	add_child(_spawn_fade)
	_spawn_fade.call("bind_visual", _get_visual())
	return _spawn_fade


# --- 피격 / 처치 / 접촉 (I/O) ---

## 정화탄 등이 호출한다(계약). HP 감소 → 0 이하면 처치.
func take_damage(amount: int) -> void:
	if _dead or is_hit_invulnerable():
		return
	HapticManager.on_enemy_hit()
	_hp = maxi(0, _hp - amount)
	_update_health_bar()
	if is_dead(_hp):
		_die()
	else:
		_trigger_hit_reaction()


func _die() -> void:
	if _dead:
		return
	_dead = true
	_spawn_death_fade()
	defeated.emit(self)
	queue_free()


func _spawn_death_fade() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fade := EnemyDeathFade.new()
	parent.add_child(fade)
	fade.global_position = EnemyDeathFade.foot_position_for(self, _get_visual())
	fade.capture_visual(_get_visual())


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _try_contact(target: Node2D) -> void:
	if is_spawn_protected():
		return
	if _contact_timer > 0.0:
		return
	if global_position.distance_to(target.global_position) > contact_range:
		return
	_play_attack_animation(target.global_position - global_position)
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
	_contact_timer = contact_cooldown


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


func _get_health_bar() -> RefCounted:
	if _health_bar == null:
		_health_bar = EnemyHealthBar.new()
		var bg := get_node_or_null(^"HealthBarBg") as ColorRect
		var fill := get_node_or_null(^"HealthBarFill") as ColorRect
		_health_bar.call("bind", bg, fill)
	return _health_bar


func _layout_health_bar() -> void:
	var bar := _get_health_bar()
	bar.call("configure", health_bar_width, health_bar_height)
	bar.call("reposition_above_visual", _get_visual())


func _reset_health_bar() -> void:
	_layout_health_bar()
	_get_health_bar().call("hide_bar")


func _update_health_bar() -> void:
	_layout_health_bar()
	_get_health_bar().call("update", float(_hp), float(max_hp))


func get_health_bar_snapshot() -> Dictionary:
	_layout_health_bar()
	return _get_health_bar().call("get_snapshot") as Dictionary
