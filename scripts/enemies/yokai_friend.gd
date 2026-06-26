extends CharacterBody2D
## #18 요괴화 친구 중간보스 — 처치가 아니라 기절→정화.
##
## 추적(CHASING) → 데미지로 기절 게이지가 차면 STUNNED → 그동안 플레이어가 근접+홀드로
## 정화 진행 → 완료 시 purified 방출(친구 구출). 기절이 풀리면 다시 추적.
## 최종 보스(#17)와는 별개. 적 프리미티브를 재사용하되 죽지 않는다.

## 정화 완료 — 친구 구출. RoomManager/전투방·구출 카운트가 듣는다(계약).
signal purified(friend)
## 기절 진입 — UI(정화 프롬프트) 표시용.
signal stunned

enum State { CHASING, STUNNED, PURIFIED }

@export var max_stun: int = 5            ## 기절까지 필요한 누적 피해
@export var stun_duration: float = 3.0   ## 기절 지속(이 안에 정화 못하면 복귀)
@export var purify_time: float = 1.2      ## 정화 완료까지 홀드 시간 (s)
@export var purify_range: float = 60.0    ## 정화 가능 거리 (px)
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var contact_range: float = 40.0    ## 합산 충돌 반지름(보스 20 + 플레이어 14 = 34) 위 — 몸이 닿으면 접촉 데미지가 들어가도록
@export var contact_cooldown: float = 0.7
@export var target_group: StringName = &"player"

var _state: State = State.CHASING
var _stun_accum: int = 0
var _stun_timer: float = 0.0
var _purify_progress: float = 0.0
var _contact_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"yokai_friend")


func is_stunned() -> bool:
	return _state == State.STUNNED


func is_purified() -> bool:
	return _state == State.PURIFIED


func _physics_process(delta: float) -> void:
	match _state:
		State.CHASING:
			_process_chase(delta)
		State.STUNNED:
			_process_stun(delta)


# --- 순수 함수(테스트 대상) ---

func chase_velocity(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var dir := to - from
	return dir.normalized() * speed if dir.length() > 0.001 else Vector2.ZERO


func accumulate_stun(current: int, amount: int) -> int:
	return current + amount


func reached_stun_threshold(accum: int, threshold: int) -> bool:
	return accum >= threshold


# --- 피격/기절/정화 (I/O) ---

## 정화탄 등이 호출(계약). CHASING 중에만 기절 게이지를 채운다.
func take_damage(amount: int) -> void:
	if _state != State.CHASING:
		return
	_stun_accum = accumulate_stun(_stun_accum, amount)
	if reached_stun_threshold(_stun_accum, max_stun):
		_enter_stunned()


## 정화 진행을 delta만큼 누적하고, 완료되면 true. (테스트에서 직접 호출 가능)
func apply_purify(delta: float) -> bool:
	_purify_progress += delta
	return _purify_progress >= purify_time


func _enter_stunned() -> void:
	_state = State.STUNNED
	_stun_timer = stun_duration
	_purify_progress = 0.0
	velocity = Vector2.ZERO
	stunned.emit()


func _process_chase(delta: float) -> void:
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var target := _find_target()
	if target == null:
		return
	velocity = chase_velocity(global_position, target.global_position, move_speed)
	move_and_slide()
	_try_contact(target)


func _process_stun(delta: float) -> void:
	_stun_timer -= delta
	var target := _find_target()
	if _player_is_purifying(target):
		if apply_purify(delta):
			_complete_purify()
			return
	if _stun_timer <= 0.0:
		_state = State.CHASING
		_stun_accum = 0
		_purify_progress = 0.0


## 플레이어가 정화 중인가 — 근접 + 발사 입력 홀드.
func _player_is_purifying(target: Node2D) -> bool:
	if target == null:
		return false
	if global_position.distance_to(target.global_position) > purify_range:
		return false
	return target.has_method("is_firing") and target.is_firing()


func _complete_purify() -> void:
	_state = State.PURIFIED
	purified.emit(self)
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
