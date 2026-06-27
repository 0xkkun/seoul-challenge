extends CharacterBody2D
## #17 최종 보스 — 텔레그래프 패턴(돌진 강공격 + 근접 약공격)을 번갈아 사용. 처치=탈출.
##
## 사이클: RECOVER(느린 추적) → TELEGRAPH(정지·경고) → 패턴 실행(CHARGE 강공격 / SWING 약공격) → RECOVER.
## 패턴 선택·돌진 방향·스윙 판정은 순수 함수로 단위 테스트한다. 처치 시 defeated 방출(런 탈출 트리거).

## 처치됨 — 탈출/런 클리어 트리거(계약).
signal defeated(boss)
## 패턴 경고 시작 — UI 텔레그래프용.
signal telegraph_started

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")
const EnemyDeathFade = preload("res://scripts/combat/enemy_death_fade.gd")
const EnemyHealthBar = preload("res://scripts/enemies/enemy_health_bar.gd")
const FACING_DEADZONE := 0.05
const HIT_TIMING_EPSILON := 0.0001

enum Phase { RECOVER, TELEGRAPH, CHARGE, SWING }

@export var max_hp: int = 30
@export var move_speed: float = 70.0       ## 평상시(RECOVER) 추적 속도
@export var charge_speed: float = 360.0     ## 돌진 속도
@export var recover_time: float = 1.0
@export var telegraph_time: float = 0.6
@export var charge_time: float = 0.7
@export var contact_damage: int = 1
@export var contact_range: float = 34.0
@export var weak_attack_range: float = 104.0
@export var weak_attack_arc: float = 1.6
@export var strong_attack_range: float = 144.0
@export var strong_attack_arc: float = 1.8
@export_range(0, 7, 1) var strong_attack_hit_frame := 3
@export var strong_attack_animation_fps: float = 12.0
@export var contact_cooldown: float = 0.5
@export var hit_invuln_time: float = 0.12
@export var target_group: StringName = &"player"
@export var health_bar_width: float = 64.0
@export var health_bar_height: float = 5.0
@export var move_animation: StringName = &"move"
@export var attack_animation: StringName = &"attack"
@export var strong_attack_animation: StringName = &"strong_attack"

var _hp: int = 0
var _dead := false
var _phase: Phase = Phase.RECOVER
var _phase_timer: float = 0.0
var _pattern_index: int = 1   ## 다음 패턴 (0=돌진, 1=약공격) — 첫 사이클은 돌진부터
var _charge_dir: Vector2 = Vector2.ZERO
var _charge_elapsed: float = 0.0
var _pattern_target: Node2D = null
var _contact_timer: float = 0.0
var _hit_reaction: Node = null
var _health_bar: RefCounted = null

@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	_hp = max_hp
	add_to_group(&"enemy")
	add_to_group(&"boss")
	_phase_timer = recover_time
	_ensure_hit_reaction()
	_reset_health_bar()
	_play_move_animation()


func _physics_process(delta: float) -> void:
	tick_hit_reaction(delta)
	_phase_timer -= delta
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var target := _find_target()
	match _phase:
		Phase.RECOVER:
			_slow_follow(target)
			if _phase_timer <= 0.0:
				_begin_telegraph()
		Phase.TELEGRAPH:
			velocity = Vector2.ZERO
			if _phase_timer <= 0.0:
				_begin_pattern(target)
		Phase.CHARGE:
			var charge_target := _current_pattern_target(target)
			velocity = _charge_dir * charge_speed
			move_and_slide()
			_tick_strong_attack_hit(charge_target, delta)
			if _phase_timer <= 0.0:
				_begin_recover()
		Phase.SWING:
			velocity = Vector2.ZERO
			if _phase_timer <= 0.0:
				_begin_recover()


# --- 순수 함수(테스트 대상) ---

func charge_velocity(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


## 패턴 인덱스 토글(0↔1).
func pick_next_pattern(current: int) -> int:
	return (current + 1) % 2


## 조준 방향 기준 전방 스윙 판정.
func in_swing_arc(facing: Vector2, to_target: Vector2, swing_range: float, arc: float) -> bool:
	if swing_range <= 0.0 or arc <= 0.0:
		return false
	var target_distance := to_target.length()
	if target_distance > swing_range:
		return false
	if target_distance <= 0.001:
		return true
	if facing.length() <= 0.001:
		return true
	return absf(facing.normalized().angle_to(to_target.normalized())) <= arc * 0.5


func strong_attack_hit_ready(elapsed: float, hit_frame: int, animation_speed: float) -> bool:
	if hit_frame <= 0 or animation_speed <= 0.0:
		return true
	return elapsed + HIT_TIMING_EPSILON >= float(hit_frame) / animation_speed


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


# --- 피격/처치 ---

func take_damage(amount: int) -> void:
	if _dead or is_hit_invulnerable():
		return
	HapticManager.on_boss_hit()
	_hp = maxi(0, _hp - amount)
	_update_health_bar()
	if _hp <= 0:
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


# --- 패턴 진행 (I/O) ---

func _begin_telegraph() -> void:
	_phase = Phase.TELEGRAPH
	_phase_timer = telegraph_time
	_pattern_index = pick_next_pattern(_pattern_index)
	telegraph_started.emit()


func _begin_pattern(target: Node2D) -> void:
	_pattern_target = target
	if _pattern_index == 0:
		_charge_dir = _aim_to(target)
		_charge_elapsed = 0.0
		_phase = Phase.CHARGE
		_phase_timer = charge_time
		_play_attack_animation(strong_attack_animation, _charge_dir)
	else:
		var aim := _aim_to(target)
		_play_attack_animation(attack_animation, aim)
		_try_swing_attack(target, aim, weak_attack_range, weak_attack_arc)
		_phase = Phase.SWING
		_phase_timer = 0.45


func _begin_recover() -> void:
	_phase = Phase.RECOVER
	_phase_timer = recover_time
	_charge_elapsed = 0.0
	_pattern_target = null
	_play_move_animation()


func _slow_follow(target: Node2D) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	velocity = charge_velocity(global_position, target.global_position, move_speed)
	_update_move_animation()
	move_and_slide()
	_try_contact(target)


func _aim_to(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.RIGHT
	var d := target.global_position - global_position
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _strong_attack_hit_ready_now() -> bool:
	return strong_attack_hit_ready(_charge_elapsed, strong_attack_hit_frame, strong_attack_animation_fps)


func _tick_strong_attack_hit(target: Node2D, delta: float) -> void:
	_charge_elapsed += delta
	if not _strong_attack_hit_ready_now():
		return
	_try_swing_attack(target, _charge_dir, strong_attack_range, strong_attack_arc)
	_try_contact(target)


func _current_pattern_target(fallback: Node2D) -> Node2D:
	if _pattern_target != null and is_instance_valid(_pattern_target):
		return _pattern_target
	return fallback


func _update_move_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	_update_sprite_facing()
	_play_move_animation()


func _play_move_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(move_animation):
		return
	if _sprite.animation != move_animation:
		_sprite.play(move_animation)
	elif not _sprite.is_playing():
		_sprite.play()


func _play_attack_animation(animation_name: StringName, facing_direction: Vector2 = Vector2.ZERO) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	_set_sprite_facing_from_direction(facing_direction)
	if _sprite.sprite_frames.has_animation(animation_name):
		_sprite.play(animation_name)
		_sprite.frame = 0


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


func _try_contact(target: Node2D) -> void:
	if _contact_timer > 0.0 or target == null:
		return
	if global_position.distance_to(target.global_position) > contact_range:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
	_contact_timer = contact_cooldown


func _try_swing_attack(target: Node2D, facing: Vector2, swing_range: float, arc: float) -> void:
	if _contact_timer > 0.0 or target == null:
		return
	var to_target := target.global_position - global_position
	if not in_swing_arc(facing, to_target, swing_range, arc):
		return
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
	_contact_timer = contact_cooldown
