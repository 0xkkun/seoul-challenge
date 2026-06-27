extends CharacterBody2D
## #16 잡몹 2종째(원거리) — 플레이어와 일정 거리를 유지하며 주기적으로 발사한다.
## #11 적 프리미티브 계약 재사용: defeated 시그널 + take_damage + "enemy" 그룹.
## 정화탄(take_damage)으로 처치된다. 카이팅/조준/발사 수학은 순수 함수로 분리해 테스트한다.

## 처치됨 — RoomManager/전투방이 듣는다(계약 #19).
signal defeated(enemy)
## 발사 — origin 에서 direction 으로 발사. 자기 자신이 받아 enemy_bullet 을 스폰한다.
signal fired(origin: Vector2, direction: Vector2)

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")
const StatusEffectController = preload("res://scripts/combat/status_effect_controller.gd")
const EnemyDeathFade = preload("res://scripts/combat/enemy_death_fade.gd")
const ENEMY_BULLET := preload("res://scenes/enemies/enemy_bullet.tscn")
const FACING_DEADZONE := 0.01

@export var max_hp: int = 2
@export var move_speed: float = 70.0          ## 카이팅 이동 속도 (px/s)
@export var preferred_range: float = 220.0    ## 유지하려는 사거리 (px)
@export var range_deadzone: float = 30.0      ## 사거리 데드존 (±, px) — 안이면 정지
@export var fire_interval: float = 1.4        ## 발사 간격 (s)
@export var hit_invuln_time: float = 0.12     ## 피격 직후 중복 피해 방지/플래시 시간
@export var target_group: StringName = &"player"
@export var projectile_scene: PackedScene = ENEMY_BULLET
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"

var _hp: int = 0
var _fire_timer: float = 0.0
var _dead := false
var _hit_reaction: Node = null
var _status_effects: Node = null
var _movement_bounds := Rect2()
var _movement_bounds_enabled := false
@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	_hp = max_hp
	_fire_timer = fire_interval
	add_to_group(&"enemy")
	_ensure_hit_reaction()
	_ensure_status_effects()
	fired.connect(_spawn_bullet)


func _physics_process(delta: float) -> void:
	tick_hit_reaction(delta)
	tick_status_effects(delta)
	var target := _find_target()
	if target == null:
		return
	if is_status_action_blocked():
		velocity = Vector2.ZERO
		move_and_slide()
		clamp_to_movement_bounds()
		return
	if is_status_movement_blocked():
		velocity = Vector2.ZERO
	else:
		velocity = kite_velocity(
			global_position,
			target.global_position,
			preferred_range,
			range_deadzone,
			move_speed * get_status_speed_multiplier()
		)
		velocity = clamp_velocity_to_movement_bounds(global_position, velocity, delta)
	move_and_slide()
	clamp_to_movement_bounds()
	_update_animation()
	tick_fire(delta, global_position, target.global_position)


# --- 순수 함수 / 테스트 가능한 로직 ---

## 선호 사거리를 유지하는 카이팅 속도.
## 너무 멀면 접근, 너무 가까우면 후퇴, 데드존 안이면 정지.
func kite_velocity(from: Vector2, to: Vector2, preferred: float, deadzone: float, speed: float) -> Vector2:
	var offset := to - from
	var dist := offset.length()
	if dist <= 0.001:
		return Vector2.ZERO
	var dir := offset / dist
	if dist > preferred + deadzone:
		return dir * speed
	if dist < preferred - deadzone:
		return -dir * speed
	return Vector2.ZERO


## from→to 조준 방향(정규화). 같은 위치면 RIGHT.
func aim_direction(from: Vector2, to: Vector2) -> Vector2:
	var offset := to - from
	return offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT


func step_fire_cooldown(timer: float, delta: float) -> float:
	return maxf(0.0, timer - delta)


func is_ready_to_fire(timer: float) -> bool:
	return timer <= 0.0


func is_dead(hp: int) -> bool:
	return hp <= 0


func get_projectile_scene_path() -> String:
	if projectile_scene == null:
		return ""
	return projectile_scene.resource_path


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


func clamp_velocity_to_movement_bounds(position: Vector2, next_velocity: Vector2, delta: float) -> Vector2:
	if not _movement_bounds_enabled or delta <= 0.0:
		return next_velocity
	var projected := position + next_velocity * delta
	var clamped_velocity := next_velocity
	if projected.x < _movement_bounds.position.x and next_velocity.x < 0.0:
		clamped_velocity.x = 0.0
	elif projected.x > _movement_bounds.end.x and next_velocity.x > 0.0:
		clamped_velocity.x = 0.0
	if projected.y < _movement_bounds.position.y and next_velocity.y < 0.0:
		clamped_velocity.y = 0.0
	elif projected.y > _movement_bounds.end.y and next_velocity.y > 0.0:
		clamped_velocity.y = 0.0
	return clamped_velocity


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


## 발사 쿨다운을 진행하고, 준비되면 fired 를 방출하고 타이머를 리셋한다. 발사했으면 true.
func tick_fire(delta: float, origin: Vector2, target_position: Vector2) -> bool:
	_fire_timer = step_fire_cooldown(_fire_timer, delta)
	if not is_ready_to_fire(_fire_timer):
		return false
	_fire_timer = fire_interval
	var direction := aim_direction(origin, target_position)
	_play_attack_animation(direction)
	fired.emit(origin, direction)
	return true


# --- 피격 / 처치 (I/O) ---

## 정화탄 등이 호출한다(계약). HP 감소 → 0 이하면 처치.
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
	_spawn_death_fade()
	defeated.emit(self)
	queue_free()


func _spawn_death_fade() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fade := EnemyDeathFade.new()
	parent.add_child(fade)
	fade.global_position = global_position
	fade.capture_visual(_get_visual())


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


## fired 를 받아 적 투사체(enemy_bullet)를 실제로 스폰한다. (#16 완성 — #17의 enemy_bullet 재사용)
func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var scene := projectile_scene if projectile_scene != null else ENEMY_BULLET
	var bullet := scene.instantiate()
	parent.add_child(bullet)
	bullet.call("launch", origin, direction)


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
