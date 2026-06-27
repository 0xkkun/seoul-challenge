extends CharacterBody2D
## #11 잡몹(체이서) — 플레이어 추적, 정화탄 피격(take_damage), 처치 시 defeated 방출, 접촉 데미지.
## 추적 수학은 순수 함수로 분리해 단위 테스트한다.

## 처치됨 — RoomManager/전투방이 듣고 방 클리어 카운트에 사용한다(계약 #19).
signal defeated(enemy)

@export var max_hp: int = 3
@export var move_speed: float = 90.0       ## 추적 속도 (px/s)
@export var contact_damage: int = 1        ## 접촉 시 플레이어 피해
@export var contact_range: float = 28.0    ## 접촉 판정 거리 (px)
@export var contact_cooldown: float = 0.6  ## 접촉 데미지 간격 (s)
@export var target_group: StringName = &"player"

var _hp: int = 0
var _contact_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_hp = max_hp
	add_to_group(&"enemy")


func _physics_process(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var target := _find_target()
	if target == null:
		return
	velocity = chase_velocity(global_position, target.global_position, move_speed)
	move_and_slide()
	_try_contact(target)


# --- 순수 함수(테스트 대상) ---

## from→to 향하는 추적 속도. 같은 위치면 ZERO.
func chase_velocity(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


func is_dead(hp: int) -> bool:
	return hp <= 0


# --- 피격 / 처치 / 접촉 (I/O) ---

## 정화탄 등이 호출한다(계약). HP 감소 → 0 이하면 처치.
func take_damage(amount: int) -> void:
	if _dead:
		return
	HapticManager.on_enemy_hit()
	_hp -= amount
	if is_dead(_hp):
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	defeated.emit(self)
	queue_free()


func _find_target() -> Node2D:
	return get_tree().get_first_node_in_group(target_group) as Node2D


func _try_contact(target: Node2D) -> void:
	if _contact_timer > 0.0:
		return
	if global_position.distance_to(target.global_position) > contact_range:
		return
	if target.has_method("take_damage"):
		target.call("take_damage", contact_damage)
	_contact_timer = contact_cooldown
