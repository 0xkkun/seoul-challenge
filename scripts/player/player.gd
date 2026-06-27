extends CharacterBody2D
## 탑다운 플레이어 — 이동(#8) + 조준·사격(#9) + 야구공 손맛(#15) + 모바일 터치 입력(#52)
##
## 입력: 터치 컨트롤(가상 조이스틱+공격버튼)이 있으면 그걸로, 없으면 키보드(데스크탑 폴백).
## 조준 = 이동(facing) 방향. 발사 = 공격 버튼 / 스페이스 / 우트리거.
## 이동·조준·쿨다운·반동 수학은 순수 함수로 분리해 물리/입력 없이 단위 테스트한다.

const MapItemCatalog = preload("res://scripts/items/map_item_catalog.gd")

## 발사 순간의 발사 지점(global)과 방향. #10 정화탄이 이 시그널을 받아 스폰한다.
signal fired(muzzle_position: Vector2, direction: Vector2)
## 무기 변경 — 맨손 → 야구배트 등. UI 표시용.
signal weapon_changed(weapon_name: String)
## 특수 스킬 상태 변경 — HUD 표시용.
signal special_skill_state_changed(payload: Dictionary)
## 런 한정 맵 아이템 변경 — 보물방/상점방 표시용.
signal run_modifiers_changed(payload: Dictionary)

@export var move_speed: float = 260.0      ## 최고 속도 (px/s)
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
@export var bat_range: float = 100.0       ## 배트 사거리 (px) — 방망이 끝까지 길게
@export var bat_arc: float = 2.4            ## 배트 타격 각 (rad) — 넓게 휘두름
@export var bat_knockback: float = 64.0    ## 배트 넉백 거리 (px)
@export var swing_vertical_factor: float = 0.6  ## 스윙 세로(깊이) 압축 — 위/아래 사거리를 좌우보다 짧게(벨트 원근감)
@export var swing_visual_time: float = 0.12  ## 휘두르기 시각 표시 시간 (s)
@export var max_health: int = 5            ## 최대 체력(하트)
@export var invuln_time: float = 0.5       ## 피격 후 무적 시간 (s) — 보스 탄막 원샷 방지
@export var special_skill_id: StringName = &"emergency_dodge"
@export_range(0, 9, 1) var special_skill_max_uses := 3
@export_range(0, 9, 1) var special_skill_uses_remaining := 3
@export var special_skill_cooldown: float = 1.4
@export var dodge_duration: float = 0.14
@export var dodge_speed: float = 520.0
@export var dodge_invuln_time: float = 0.24
@export var touch_controls_path: NodePath  ## 비우면 키보드 폴백

var _attack_timer: float = 0.0
var _swing_timer: float = 0.0
var _is_attacking: bool = false   ## 공격 모션 재생 중(애니 끝날 때까지 walk/idle 억제)
var _special_cooldown_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _was_special_pressed := false
var _has_bat: bool = false   ## 야구배트 장착 여부(맵 클리어 보상). 기본 맨손.
var _facing: Vector2 = Vector2.DOWN
var _health: int = 0
var _invuln_timer: float = 0.0
var _touch: Node = null
var _base_run_stats := {}
var _run_modifier_ids: Array[StringName] = []
var _movement_bounds := Rect2()
var _movement_bounds_enabled := false

@onready var _swing_visual: Node2D = get_node_or_null(^"MeleeSwing")
@onready var _sprite: AnimatedSprite2D = get_node_or_null(^"Sprite")


func _ready() -> void:
	add_to_group(&"player")
	_capture_base_run_stats()
	_health = max_health
	_connect_run_session_events()
	if not touch_controls_path.is_empty():
		_touch = get_node_or_null(touch_controls_path)
	# HUD·죽음 컨트롤러가 연결된 뒤 초기 체력을 알리도록 지연 발신.
	_broadcast_health.call_deferred()
	_broadcast_special_skill_state.call_deferred()
	if _sprite != null and not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)


func _physics_process(delta: float) -> void:
	_invuln_timer = maxf(0.0, _invuln_timer - delta)
	var move := read_input_vector()
	_facing = update_facing(_facing, move)
	_process_special_skill(delta, move)
	if _dodge_timer > 0.0:
		_dodge_timer = maxf(0.0, _dodge_timer - delta)
		velocity = dodge_velocity(_dodge_direction, dodge_speed)
	elif _is_attacking:
		# 공격 중엔 이동 정지 — 입력을 무시하고 감속한다(이동하며 공격 불가).
		velocity = step_velocity(velocity, Vector2.ZERO, delta)
	else:
		# 벨트 원근감: 깊이(상하) 이동을 좌우보다 느리게 한다.
		move.y *= vertical_speed_factor
		velocity = step_velocity(velocity, move, delta)
	move_and_slide()
	clamp_to_movement_bounds()
	_process_attack(delta)
	_update_animation(move)


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


func clamp_position_to_bounds(position: Vector2, bounds: Rect2) -> Vector2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return position
	return Vector2(
		clampf(position.x, bounds.position.x, bounds.end.x),
		clampf(position.y, bounds.position.y, bounds.end.y)
	)


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


func reset_motion() -> void:
	velocity = Vector2.ZERO
	_dodge_timer = 0.0
	_dodge_direction = Vector2.ZERO


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


func step_special_cooldown(timer: float, delta: float) -> float:
	return maxf(0.0, timer - delta)


func can_use_special_skill(uses_remaining: int, cooldown_remaining: float, is_active: bool) -> bool:
	return uses_remaining > 0 and cooldown_remaining <= 0.0 and not is_active


func consume_special_use(uses_remaining: int) -> int:
	return maxi(0, uses_remaining - 1)


func choose_dodge_direction(move_input: Vector2, facing: Vector2) -> Vector2:
	if move_input.length() > 0.01:
		return move_input.normalized()
	if facing.length() > 0.01:
		return facing.normalized()
	return Vector2.DOWN


func dodge_velocity(direction: Vector2, speed: float) -> Vector2:
	if direction.length() < 0.001:
		return Vector2.ZERO
	return direction.normalized() * speed


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


func apply_run_modifier(item_id: StringName) -> bool:
	if not MapItemCatalog.has_item(item_id):
		return false
	_capture_base_run_stats()
	_run_modifier_ids.append(item_id)
	_apply_run_modifier_stats()
	_broadcast_run_modifiers_changed()
	return true


func reset_run_modifiers(restore_health := false) -> void:
	_capture_base_run_stats()
	_run_modifier_ids.clear()
	var previous_health := _health
	var previous_max_health := max_health
	_apply_stats(_base_run_stats)
	if restore_health:
		_health = max_health
	else:
		_health = mini(_health, max_health)
	if previous_health != _health or previous_max_health != max_health:
		_broadcast_health()
	_broadcast_run_modifiers_changed()


func get_run_modifier_ids() -> Array[StringName]:
	return _run_modifier_ids.duplicate()


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


func get_invuln_remaining() -> float:
	return _invuln_timer


func get_special_cooldown_remaining() -> float:
	return _special_cooldown_timer


func is_dodging() -> bool:
	return _dodge_timer > 0.0


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


## 조준 = 우측 공격버튼 드래그 방향이 있으면 그쪽, 없으면 바라보는(이동) 방향.
func aim_direction() -> Vector2:
	if _touch != null and _touch.has_method("get_aim"):
		var a: Vector2 = _touch.get_aim()
		if a.length() > 0.01:
			return a
	return _facing


## 발사 입력: 터치 공격 버튼 우선, 없으면 스페이스/우트리거.
func is_firing() -> bool:
	if _touch != null and _touch.is_attack_pressed():
		return true
	return Input.is_key_pressed(KEY_SPACE) or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3


func is_special_pressed() -> bool:
	if _touch != null and _touch.has_method("is_skill_pressed") and _touch.call("is_skill_pressed"):
		return true
	return (
		Input.is_physical_key_pressed(KEY_SHIFT)
		or Input.is_physical_key_pressed(KEY_E)
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.3
	)


func try_start_special_skill(input_vector: Vector2 = Vector2.ZERO) -> bool:
	if special_skill_id != &"emergency_dodge":
		return false
	if not can_use_special_skill(special_skill_uses_remaining, _special_cooldown_timer, is_dodging()):
		return false
	_dodge_direction = choose_dodge_direction(input_vector, _facing)
	_dodge_timer = dodge_duration
	_invuln_timer = maxf(_invuln_timer, dodge_invuln_time)
	special_skill_uses_remaining = consume_special_use(special_skill_uses_remaining)
	_special_cooldown_timer = special_skill_cooldown
	_broadcast_special_skill_state()
	return true


func equip_special_skill(skill_id: StringName, max_uses: int = 3, cooldown: float = 1.4) -> void:
	special_skill_id = skill_id
	special_skill_max_uses = maxi(0, max_uses)
	special_skill_uses_remaining = special_skill_max_uses
	special_skill_cooldown = maxf(0.0, cooldown)
	_special_cooldown_timer = 0.0
	_dodge_timer = 0.0
	_broadcast_special_skill_state()


func _process_special_skill(delta: float, move_input: Vector2) -> void:
	var previous_cooldown := _special_cooldown_timer
	_special_cooldown_timer = step_special_cooldown(_special_cooldown_timer, delta)
	var pressed := is_special_pressed()
	if pressed and not _was_special_pressed:
		try_start_special_skill(move_input)
	_was_special_pressed = pressed
	if not is_equal_approx(previous_cooldown, _special_cooldown_timer):
		_broadcast_special_skill_state()


func _broadcast_special_skill_state() -> void:
	var payload := {
		"skill_id": special_skill_id,
		"uses_remaining": special_skill_uses_remaining,
		"max_uses": special_skill_max_uses,
		"cooldown_remaining": _special_cooldown_timer,
		"cooldown": special_skill_cooldown,
		"active": is_dodging(),
	}
	special_skill_state_changed.emit(payload.duplicate(true))
	if has_node("/root/EventBus"):
		EventBus.emit_special_skill_state_changed(payload)


func _connect_run_session_events() -> void:
	if not has_node("/root/EventBus"):
		return
	var started_callback := Callable(self, "_on_session_started")
	if not EventBus.session_started.is_connected(started_callback):
		EventBus.session_started.connect(started_callback)
	var finished_callback := Callable(self, "_on_session_finished")
	if not EventBus.session_finished.is_connected(finished_callback):
		EventBus.session_finished.connect(finished_callback)


func _on_session_started(_config: Dictionary) -> void:
	reset_run_modifiers(true)


func _on_session_finished(_result: Dictionary) -> void:
	reset_run_modifiers(false)


func _capture_base_run_stats() -> void:
	if not _base_run_stats.is_empty():
		return
	_base_run_stats = {
		"move_speed": move_speed,
		"attack_cooldown": attack_cooldown,
		"fire_cooldown": fire_cooldown,
		"melee_damage": melee_damage,
		"bat_damage": bat_damage,
		"max_health": max_health,
	}


func _apply_run_modifier_stats() -> void:
	var previous_health := _health
	var previous_max_health := max_health
	var modifiers := MapItemCatalog.compose_modifiers(_run_modifier_ids)
	var stats := MapItemCatalog.apply_modifiers_to_stats(_base_run_stats, modifiers)
	_apply_stats(stats)
	if max_health > previous_max_health:
		_health += max_health - previous_max_health
	elif _health > max_health:
		_health = max_health
	if previous_health != _health or previous_max_health != max_health:
		_broadcast_health()


func _apply_stats(stats: Dictionary) -> void:
	move_speed = float(stats.get("move_speed", move_speed))
	attack_cooldown = float(stats.get("attack_cooldown", attack_cooldown))
	fire_cooldown = float(stats.get("fire_cooldown", fire_cooldown))
	melee_damage = int(stats.get("melee_damage", melee_damage))
	bat_damage = int(stats.get("bat_damage", bat_damage))
	max_health = int(stats.get("max_health", max_health))


func _broadcast_run_modifiers_changed() -> void:
	var payload := {
		"item_ids": _run_modifier_ids.duplicate(),
		"modifiers": MapItemCatalog.compose_modifiers(_run_modifier_ids),
	}
	run_modifiers_changed.emit(payload.duplicate(true))


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
	_play_attack_anim(dir)


## 공격 모션 재생(비반복). animation_finished 에서 _is_attacking 을 해제한다.
func _play_attack_anim(dir: Vector2) -> void:
	if _sprite == null:
		return
	# 공격 시 조준 방향으로 캐릭터를 돌린다(뒤로 때리면 뒤돌아봄).
	if absf(dir.x) > 0.05:
		_sprite.flip_h = dir.x < 0.0
	_is_attacking = true
	_sprite.play(&"attack")


## 입력 상태에 맞는 애니메이션 — 공격 중이면 유지, 이동하면 walk, 정지면 idle.
## 좌우 이동에 맞춰 스프라이트를 좌우 반전한다.
func _update_animation(move: Vector2) -> void:
	if _sprite == null:
		return
	if _is_attacking:
		return  # 공격 중엔 조준 방향 반전을 유지(_play_attack_anim 이 설정)
	if absf(_facing.x) > 0.05:
		_sprite.flip_h = _facing.x < 0.0
	var next: StringName = &"walk" if move.length() > 0.1 else &"idle"
	if _sprite.animation != next:
		_sprite.play(next)


func _on_sprite_animation_finished() -> void:
	if _sprite != null and _sprite.animation == &"attack":
		_is_attacking = false


## 근접 휘두르기 — 무기(맨손/배트)에 따라 사거리·각·피해가 다르다. 배트면 넉백 + 적탄 되받아침(deflect).
func _attack_melee(dir: Vector2) -> void:
	var dmg := bat_damage if _has_bat else melee_damage
	var rng := bat_range if _has_bat else melee_range
	var arc := bat_arc if _has_bat else melee_arc
	for enemy: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e := enemy as Node2D
		if e == null or not is_instance_valid(e):
			continue
		var to := e.global_position - global_position
		var to_us := Vector2(to.x, to.y / swing_vertical_factor)
		if to_us.length() <= rng and in_melee_arc(dir, to_us, arc):
			if enemy.has_method("take_damage"):
				enemy.call("take_damage", dmg)
			if _has_bat:
				e.global_position += knockback_vector(global_position, e.global_position, bat_knockback)
	if _has_bat:
		_deflect_bullets_in_arc(dir, rng, arc)
	_show_swing(dir, rng, arc)


## 원거리 발사(야구공) — 보존된 무기. ranged_enabled 일 때만 사용. fired → ProjectileLauncher 가 스폰.
func _attack_ranged(dir: Vector2) -> void:
	fired.emit(global_position + dir * muzzle_offset, dir)
	velocity += recoil_velocity(dir, recoil_strength)
	HapticManager.on_fire()


## 휘두르기 시각 표시 — 실제 사거리(rng)·각(arc)으로 부채꼴을 그려 타격 범위와 일치시킨다.
func _show_swing(dir: Vector2, rng: float, arc: float) -> void:
	if _swing_visual == null:
		return
	if _swing_visual is Polygon2D:
		(_swing_visual as Polygon2D).polygon = _build_swing_polygon(dir, rng, arc)
	_swing_visual.rotation = 0.0
	_swing_visual.visible = true
	_swing_timer = swing_visual_time


## 타격 부채꼴 폴리곤 — dir 기준 ±arc/2, 반지름 rng 의 팬을 월드 정렬로 만들고
## 세로(Y)를 swing_vertical_factor 만큼 압축한다(판정 ellipse 와 일치).
func _build_swing_polygon(dir: Vector2, rng: float, arc: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var base := dir.angle()
	var segments := 12
	var half := arc * 0.5
	for i in range(segments + 1):
		var a := base - half + arc * (float(i) / float(segments))
		var p := Vector2(cos(a), sin(a)) * rng
		p.y *= swing_vertical_factor
		pts.append(p)
	return pts


## 야구배트 장착(맵 클리어 보상). 통합 단계에서 보상 지급 시 호출.
func equip_bat() -> void:
	ranged_enabled = false
	if _has_bat:
		return
	_has_bat = true
	weapon_changed.emit(current_weapon_name())


## 현재 무기 이름(UI용).
func current_weapon_name() -> String:
	return "야구배트" if _has_bat else "맨손"


## 앞쪽 부채꼴 안의 적 투사체(enemy_projectile)를 swing 방향으로 되받아친다(deflect). (배트 전용)
## 투사체가 deflect()를 지원하면 반사(적 타격으로 전환), 아니면 기존처럼 제거.
func _deflect_bullets_in_arc(dir: Vector2, rng: float, arc: float) -> void:
	var deflected := false
	for b: Node in get_tree().get_nodes_in_group(&"enemy_projectile"):
		var node := b as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var to := node.global_position - global_position
		var to_us := Vector2(to.x, to.y / swing_vertical_factor)
		if to_us.length() <= rng and in_melee_arc(dir, to_us, arc):
			deflected = true
			if node.has_method("deflect"):
				node.call("deflect", dir)
			else:
				node.queue_free()
	if deflected:
		HapticManager.on_deflect()
