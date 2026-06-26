extends CharacterBody2D
## 탑다운 플레이어 — 이동(#8) + 트윈스틱 조준·사격(#9)
##
## 입력: 이동 = WASD/방향키/패드 좌스틱, 조준 = 마우스/패드 우스틱, 발사 = 좌클릭/스페이스/우트리거.
## 이동·조준·쿨다운 수학은 순수 함수로 분리해 물리/입력 없이 단위 테스트한다.

## 발사 순간의 발사 지점(global)과 방향. #10 정화탄이 이 시그널을 받아 스폰한다.
signal fired(muzzle_position: Vector2, direction: Vector2)

@export var move_speed: float = 220.0      ## 최고 속도 (px/s)
@export var acceleration: float = 2200.0   ## 가속 (px/s^2)
@export var friction: float = 2600.0       ## 감속 (px/s^2)
@export var stick_deadzone: float = 0.2    ## 게임패드 스틱 데드존
@export var fire_cooldown: float = 0.22    ## 연사 간격 (s)
@export var muzzle_offset: float = 18.0    ## 발사 지점 오프셋 (px)

var _fire_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var input_vector := read_input_vector()
	velocity = step_velocity(velocity, input_vector, delta)
	move_and_slide()
	_process_firing(delta)


## 입력 벡터 → 목표 속도. 대각선도 최고 속도를 넘지 않도록 정규화. 순수 함수.
func desired_velocity(input_vector: Vector2) -> Vector2:
	var v := input_vector
	if v.length() > 1.0:
		v = v.normalized()
	return v * move_speed


## 현재 속도를 목표 속도로 가속/감속. 입력 있으면 acceleration, 없으면 friction. 순수 함수(테스트 대상).
func step_velocity(current: Vector2, input_vector: Vector2, delta: float) -> Vector2:
	var target := desired_velocity(input_vector)
	var rate := acceleration if input_vector.length() > 0.01 else friction
	return current.move_toward(target, rate * delta)


## from→to 단위 방향. 같은 위치면 ZERO. 순수 함수(테스트 대상).
func aim_direction_to(from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	return d.normalized() if d.length() > 0.001 else Vector2.ZERO


## 쿨다운 타이머를 delta만큼 감소(0 클램프). 순수 함수(테스트 대상).
func step_fire_cooldown(timer: float, delta: float) -> float:
	return maxf(0.0, timer - delta)


## 이동 입력 읽기 (WASD + 방향키 + 패드 좌스틱). I/O.
func read_input_vector() -> Vector2:
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


## 발사 입력/쿨다운 처리 → 준비되고 입력이 있으면 fired 시그널 방출. I/O.
func _process_firing(delta: float) -> void:
	_fire_timer = step_fire_cooldown(_fire_timer, delta)
	if _fire_timer > 0.0 or not is_firing():
		return
	var dir := aim_direction()
	if dir == Vector2.ZERO:
		return
	fired.emit(global_position + dir * muzzle_offset, dir)
	_fire_timer = fire_cooldown


## 현재 조준 방향 (패드 우스틱 우선, 없으면 마우스). I/O.
func aim_direction() -> Vector2:
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() >= stick_deadzone:
		return stick.normalized()
	return aim_direction_to(global_position, get_global_mouse_position())


## 발사 입력이 눌려 있는가 (좌클릭 / 스페이스 / 우트리거). I/O.
func is_firing() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_key_pressed(KEY_SPACE) \
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.3
