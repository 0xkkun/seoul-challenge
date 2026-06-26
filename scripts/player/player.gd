extends CharacterBody2D
## 탑다운 플레이어 — 이동(#8) + 조준·사격(#9) + 야구공 손맛(#15) + 모바일 터치 입력(#52)
##
## 입력: 터치 컨트롤(가상 조이스틱+공격버튼)이 있으면 그걸로, 없으면 키보드(데스크탑 폴백).
## 조준 = 이동(facing) 방향. 발사 = 공격 버튼 / 스페이스 / 우트리거.
## 이동·조준·쿨다운·반동 수학은 순수 함수로 분리해 물리/입력 없이 단위 테스트한다.

## 발사 순간의 발사 지점(global)과 방향. #10 정화탄이 이 시그널을 받아 스폰한다.
signal fired(muzzle_position: Vector2, direction: Vector2)
## 무기 변경 — 맨손 → 야구배트 등. UI 표시용.
signal weapon_changed(weapon_name: String)

@export var move_speed: float = 220.0      ## 최고 속도 (px/s)
@export var acceleration: float = 2200.0   ## 가속 (px/s^2)
@export var friction: float = 2600.0       ## 감속 (px/s^2)
@export var vertical_speed_factor: float = 0.6  ## 깊이(상하) 이동을 좌우보다 느리게 — 벨트 원근감
@export var stick_deadzone: float = 0.2    ## 게임패드 스틱 데드존
@export var fire_cooldown: float = 0.22    ## 연사 간격 (s)
@export var muzzle_offset: float = 18.0    ## 발사 지점 오프셋 (px)
@export var recoil_strength: float = 55.0  ## 발사 반동(조준 반대 방향 킥) (px/s)
@export var ranged_enabled: bool = false   ## 원거리(야구공) 무기 — 기본 OFF(처음엔 근접). 언락 시 ON.
@export var attack_cooldown: float = 0.35  ## 근접 공격 간격 (s)
@export var melee_damage: int = 1          ## 맨손 피해
@export var melee_range: float = 34.0      ## 맨손 사거리 (px) — 짧은 펀치
@export var melee_arc: float = 1.4         ## 맨손 타격 각 (rad)
@export var bat_damage: int = 2            ## 배트 피해(보상 무기)
@export var bat_range: float = 56.0        ## 배트 사거리 (px) — 더 길게 휘두름
@export var bat_arc: float = 1.9           ## 배트 타격 각 (rad)
@export var bat_knockback: float = 64.0    ## 배트 넉백 거리 (px)
@export var swing_visual_time: float = 0.12  ## 휘두르기 시각 표시 시간 (s)
@export var max_health: int = 5            ## 최대 체력(하트)
@export var invuln_time: float = 0.5       ## 피격 후 무적 시간 (s) — 보스 탄막 원샷 방지
@export var touch_controls_path: NodePath  ## 비우면 키보드 폴백

var _fire_timer: float = 0.0
var _attack_timer: float = 0.0
var _swing_timer: float = 0.0
var _has_bat: bool = false   ## 야구배트 장착 여부(맵 클리어 보상). 기본 맨손.
var _facing: Vector2 = Vector2.DOWN
var _health: int = 0
var _invuln_timer: float = 0.0
var _touch: Node = null

@onready var _swing_visual: Node2D = get_node_or_null(^"MeleeSwing")


func _ready() -> void:
	add_to_group(&"player")
	_health = max_health
	if not touch_controls_path.is_empty():
		_touch = get_node_or_null(touch_controls_path)
	# HUD·죽음 컨트롤러가 연결된 뒤 초기 체력을 알리도록 지연 발신.
	_broadcast_health.call_deferred()


func _physics_process(delta: float) -> void:
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	var move := read_input_vector()
	_facing = update_facing(_facing, move)
	# 벨트 원근감: 깊이(상하) 이동을 좌우보다 느리게 한다.
	move.y *= vertical_speed_factor
	velocity = step_velocity(velocity, move, delta)
	move_and_slide()
	_process_attack(delta)


# --- 이동/조준/사격 수학 (순수 함수, 테스트 대상) ---

## 입력 벡터 → 목표 속도. 대각선도 최고 속도를 넘지 않도록 정규화.
func desired_velocity(input_vector: Vector2) -> Vector2:
	var v := input_vector
	if v.length() > 1.0:
		v = v.normalized()
	return v * move_speed


## 현재 속도를 목표 속도로 가속/감속. 입력 있으면 acceleration, 없으면 friction.
func step_velocity(current: Vector2, input_vector: Vector2, delta: float) -> Vector2:
	var target := desired_velocity(input_vector)
	var rate := acceleration if input_vector.length() > 0.01 else friction
	return current.move_toward(target, rate * delta)


## 이동 입력이 있으면 그 방향으로 facing 갱신, 없으면 마지막 facing 유지.
func update_facing(current_facing: Vector2, move: Vector2) -> Vector2:
	return move.normalized() if move.length() > 0.01 else current_facing


## from→to 단위 방향. 같은 위치면 ZERO. (보조용 순수 함수)
func aim_direction_to(from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	return d.normalized() if d.length() > 0.001 else Vector2.ZERO


## 쿨다운 타이머를 delta만큼 감소(0 클램프).
func step_fire_cooldown(timer: float, delta: float) -> float:
	return maxf(0.0, timer - delta)


## 발사 반동 속도(조준 반대 방향).
func recoil_velocity(aim_dir: Vector2, strength: float) -> Vector2:
	if aim_dir.length() < 0.001:
		return Vector2.ZERO
	return -aim_dir.normalized() * strength


## 근접 타격 부채꼴 판정 — facing 기준 ±arc/2 안에 to 방향이 들면 true. 순수 함수(테스트 대상).
func in_melee_arc(facing: Vector2, to: Vector2, arc: float) -> bool:
	if to.length() < 0.001 or facing.length() < 0.001:
		return false
	return absf(facing.angle_to(to)) <= arc * 0.5


## 넉백 벡터 — from→to 방향으로 distance만큼 밀어낸다. 순수 함수(테스트 대상).
func knockback_vector(from: Vector2, to: Vector2, distance: float) -> Vector2:
	var d := to - from
	return d.normalized() * distance if d.length() > 0.001 else Vector2.ZERO


## 피해 적용 후 체력(0 클램프). 순수 함수(테스트 대상).
func damaged_health(current: int, amount: int) -> int:
	return maxi(0, current - amount)


# --- 체력/피격 (계약: EventBus.player_health_changed 발신) ---

func get_health() -> int:
	return _health


## 적/적탄이 호출한다(계약). 무적시간이 아니면 체력 감소 후 EventBus로 발신.
## 체력 0 → 귀환 처리는 death_return_controller 가 player_health_changed 를 듣고 담당.
func take_damage(amount: int) -> void:
	if _health <= 0 or _invuln_timer > 0.0:
		return
	_health = damaged_health(_health, amount)
	_invuln_timer = invuln_time
	_broadcast_health()


func _broadcast_health() -> void:
	if has_node("/root/EventBus"):
		EventBus.emit_player_health_changed({"current": _health, "max": max_health})


# --- 입력 I/O (단위 테스트 제외) ---

## 이동 입력: 터치 조이스틱 우선, 없거나 0이면 키보드.
func read_input_vector() -> Vector2:
	if _touch != null:
		var tv: Vector2 = _touch.get_move()
		if tv.length() > 0.01:
			return tv
	return _keyboard_vector()


func _keyboard_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if stick.length() >= stick_deadzone:
		v += stick
	return v


## 조준 = 바라보는(이동) 방향.
func aim_direction() -> Vector2:
	return _facing


## 발사 입력: 터치 공격 버튼 우선, 없으면 스페이스/우트리거.
func is_firing() -> bool:
	if _touch != null and _touch.is_attack_pressed():
		return true
	return Input.is_key_pressed(KEY_SPACE) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3


## 공격 입력/쿨다운 처리. 기본은 근접(휘두르기), ranged_enabled 면 원거리(야구공) 발사.
func _process_attack(delta: float) -> void:
	_attack_timer = step_fire_cooldown(_attack_timer, delta)
	_swing_timer = maxf(0.0, _swing_timer - delta)
	if _swing_timer <= 0.0 and _swing_visual != null:
		_swing_visual.visible = false
	if _attack_timer > 0.0 or not is_firing():
		return
	var dir := aim_direction()
	if dir == Vector2.ZERO:
		return
	if ranged_enabled:
		_attack_ranged(dir)
		_attack_timer = fire_cooldown
	else:
		_attack_melee(dir)
		_attack_timer = attack_cooldown


## 근접 휘두르기 — 무기(맨손/배트)에 따라 사거리·각·피해가 다르다. 배트면 넉백 + 적탄 일부 지움.
func _attack_melee(dir: Vector2) -> void:
	var dmg := bat_damage if _has_bat else melee_damage
	var rng := bat_range if _has_bat else melee_range
	var arc := bat_arc if _has_bat else melee_arc
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e := enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var to := e.global_position - global_position
		if to.length() <= rng and in_melee_arc(dir, to, arc):
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", dmg)
			if _has_bat:
				e.global_position += knockback_vector(global_position, e.global_position, bat_knockback)
	if _has_bat:
		_erase_bullets_in_arc(dir, rng, arc)
	_show_swing(dir)


## 원거리 발사(야구공) — 보존된 무기. ranged_enabled 일 때만 사용. fired → ProjectileLauncher 가 스폰.
func _attack_ranged(dir: Vector2) -> void:
	fired.emit(global_position + dir * muzzle_offset, dir)
	velocity += recoil_velocity(dir, recoil_strength)


## 휘두르기 시각 표시(플레이스홀더 웨지) — facing 방향으로 잠깐 보임.
func _show_swing(dir: Vector2) -> void:
	if _swing_visual == null:
		return
	_swing_visual.rotation = dir.angle()
	_swing_visual.visible = true
	_swing_timer = swing_visual_time


## 야구배트 장착(맵 클리어 보상). 통합 단계에서 보상 지급 시 호출.
func equip_bat() -> void:
	if _has_bat:
		return
	_has_bat = true
	weapon_changed.emit(current_weapon_name())


## 현재 무기 이름(UI용).
func current_weapon_name() -> String:
	return "야구배트" if _has_bat else "맨손"


## 앞쪽 부채꼴 안의 적 투사체(enemy_projectile)를 지운다. (배트 전용)
func _erase_bullets_in_arc(dir: Vector2, rng: float, arc: float) -> void:
	for b: Node in get_tree().get_nodes_in_group(&"enemy_projectile"):
		var node := b as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var to := node.global_position - global_position
		if to.length() <= rng and in_melee_arc(dir, to, arc):
			node.queue_free()
