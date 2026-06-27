extends CharacterBody2D
## #17 최종 보스 — 텔레그래프 패턴(돌진 + 탄막 버스트)을 번갈아 사용. 처치=탈출.
##
## 사이클: RECOVER(느린 추적) → TELEGRAPH(정지·경고) → 패턴 실행(CHARGE 대시 / BURST 부채꼴 탄막) → RECOVER.
## 패턴 선택·돌진 방향·탄막 방향은 순수 함수로 단위 테스트한다. 처치 시 defeated 방출(런 탈출 트리거).

## 처치됨 — 탈출/런 클리어 트리거(계약).
signal defeated(boss)
## 패턴 경고 시작 — UI 텔레그래프용.
signal telegraph_started

const HitReactionController = preload("res://scripts/combat/hit_reaction_controller.gd")
const EnemyDeathFade = preload("res://scripts/combat/enemy_death_fade.gd")
const EnemyHealthBar = preload("res://scripts/enemies/enemy_health_bar.gd")
const ENEMY_BULLET := preload("res://scenes/enemies/enemy_bullet.tscn")

enum Phase { RECOVER, TELEGRAPH, CHARGE, BURST }

@export var max_hp: int = 30
@export var move_speed: float = 70.0       ## 평상시(RECOVER) 추적 속도
@export var charge_speed: float = 360.0     ## 돌진 속도
@export var recover_time: float = 1.0
@export var telegraph_time: float = 0.6
@export var charge_time: float = 0.7
@export var burst_count: int = 7
@export var burst_spread: float = 1.2       ## 부채꼴 전체 각(rad)
@export var contact_damage: int = 1
@export var contact_range: float = 34.0
@export var contact_cooldown: float = 0.5
@export var hit_invuln_time: float = 0.12
@export var target_group: StringName = &"player"
@export var health_bar_width: float = 64.0
@export var health_bar_height: float = 5.0

var _hp: int = 0
var _dead := false
var _phase: Phase = Phase.RECOVER
var _phase_timer: float = 0.0
var _pattern_index: int = 1   ## 다음 패턴 (0=돌진, 1=탄막) — 첫 사이클은 돌진부터
var _charge_dir: Vector2 = Vector2.ZERO
var _contact_timer: float = 0.0
var _hit_reaction: Node = null
var _health_bar: RefCounted = null


func _ready() -> void:
	_hp = max_hp
	add_to_group(&"enemy")
	add_to_group(&"boss")
	_phase_timer = recover_time
	_ensure_hit_reaction()
	_reset_health_bar()


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
			velocity = _charge_dir * charge_speed
			move_and_slide()
			_try_contact(target)
			if _phase_timer <= 0.0:
				_begin_recover()
		Phase.BURST:
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


## 조준 방향 기준 부채꼴 발사 방향 배열.
func burst_directions(aim_dir: Vector2, count: int, spread: float) -> Array:
	var result: Array = []
	if count <= 0:
		return result
	var base := aim_dir.angle() if aim_dir.length() > 0.001 else 0.0
	if count == 1:
		result.append(Vector2.from_angle(base))
		return result
	var start := base - spread * 0.5
	var step_angle := spread / float(count - 1)
	for i in count:
		result.append(Vector2.from_angle(start + step_angle * i))
	return result


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
	var visual := get_node_or_null(^"Placeholder") as CanvasItem
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
	fade.global_position = global_position
	fade.capture_visual(_get_visual())


# --- 패턴 진행 (I/O) ---

func _begin_telegraph() -> void:
	_phase = Phase.TELEGRAPH
	_phase_timer = telegraph_time
	_pattern_index = pick_next_pattern(_pattern_index)
	telegraph_started.emit()


func _begin_pattern(target: Node2D) -> void:
	if _pattern_index == 0:
		_charge_dir = _aim_to(target)
		_phase = Phase.CHARGE
		_phase_timer = charge_time
	else:
		_fire_burst(target)
		_phase = Phase.BURST
		_phase_timer = 0.4


func _fire_burst(target: Node2D) -> void:
	var aim := _aim_to(target)
	var parent := get_parent()
	if parent == null:
		return
	for dir: Vector2 in burst_directions(aim, burst_count, burst_spread):
		var bullet := ENEMY_BULLET.instantiate()
		parent.add_child(bullet)
		bullet.call("launch", global_position, dir)


func _begin_recover() -> void:
	_phase = Phase.RECOVER
	_phase_timer = recover_time


func _slow_follow(target: Node2D) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return
	velocity = charge_velocity(global_position, target.global_position, move_speed)
	move_and_slide()
	_try_contact(target)


func _aim_to(target: Node2D) -> Vector2:
	if target == null:
		return Vector2.RIGHT
	var d := target.global_position - global_position
	return d.normalized() if d.length() > 0.001 else Vector2.RIGHT


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


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
