extends CharacterBody2D
## #16 잡몹 2종째(원거리) — 플레이어와 일정 거리를 유지하며 주기적으로 발사한다.
## #11 적 프리미티브 계약 재사용: defeated 시그널 + take_damage + "enemy" 그룹.
## 정화탄(take_damage)으로 처치된다. 카이팅/조준/발사 수학은 순수 함수로 분리해 테스트한다.

## 처치됨 — RoomManager/전투방이 듣는다(계약 #19).
signal defeated(enemy)
## 발사 — origin 에서 direction 으로 발사. 자기 자신이 받아 enemy_bullet 을 스폰한다.
signal fired(origin: Vector2, direction: Vector2)

const ENEMY_BULLET := preload("res://scenes/enemies/enemy_bullet.tscn")

@export var max_hp: int = 2
@export var move_speed: float = 70.0          ## 카이팅 이동 속도 (px/s)
@export var preferred_range: float = 220.0    ## 유지하려는 사거리 (px)
@export var range_deadzone: float = 30.0      ## 사거리 데드존 (±, px) — 안이면 정지
@export var fire_interval: float = 1.4        ## 발사 간격 (s)
@export var target_group: StringName = &"player"

var _hp: int = 0
var _fire_timer: float = 0.0


func _ready() -> void:
	_hp = max_hp
	_fire_timer = fire_interval
	add_to_group(&"enemy")
	fired.connect(_spawn_bullet)


func _physics_process(delta: float) -> void:
	var target := _find_target()
	if target == null:
		return
	velocity = kite_velocity(global_position, target.global_position, preferred_range, range_deadzone, move_speed)
	move_and_slide()
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


## 발사 쿨다운을 진행하고, 준비되면 fired 를 방출하고 타이머를 리셋한다. 발사했으면 true.
func tick_fire(delta: float, origin: Vector2, target_position: Vector2) -> bool:
	_fire_timer = step_fire_cooldown(_fire_timer, delta)
	if not is_ready_to_fire(_fire_timer):
		return false
	_fire_timer = fire_interval
	fired.emit(origin, aim_direction(origin, target_position))
	return true


# --- 피격 / 처치 (I/O) ---

## 정화탄 등이 호출한다(계약). HP 감소 → 0 이하면 처치.
func take_damage(amount: int) -> void:
	_hp -= amount
	if is_dead(_hp):
		_die()


func _die() -> void:
	defeated.emit(self)
	queue_free()


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


## fired 를 받아 적 투사체(enemy_bullet)를 실제로 스폰한다. (#16 완성 — #17의 enemy_bullet 재사용)
func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bullet := ENEMY_BULLET.instantiate()
	parent.add_child(bullet)
	bullet.call("launch", origin, direction)
