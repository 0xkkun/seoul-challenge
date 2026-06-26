extends CharacterBody2D
## 탑다운 플레이어 이동 (#8)
##
## 입력: WASD + 방향키 + 게임패드 좌스틱.
## 이동 수학(desired_velocity / step_velocity)은 순수 함수로 분리해 단위 테스트가 가능하다.
## 실시간 입력 읽기와 물리는 _physics_process / read_input_vector 에서만 처리한다.

@export var move_speed: float = 220.0      ## 최고 속도 (px/s)
@export var acceleration: float = 2200.0   ## 가속 (px/s^2)
@export var friction: float = 2600.0       ## 감속 (px/s^2)
@export var stick_deadzone: float = 0.2    ## 게임패드 좌스틱 데드존


func _physics_process(delta: float) -> void:
	var input_vector := read_input_vector()
	velocity = step_velocity(velocity, input_vector, delta)
	move_and_slide()


## 입력 벡터 → 목표 속도. 대각선 입력도 최고 속도를 넘지 않도록 정규화. 순수 함수.
func desired_velocity(input_vector: Vector2) -> Vector2:
	var v := input_vector
	if v.length() > 1.0:
		v = v.normalized()
	return v * move_speed


## 현재 속도를 목표 속도로 가속/감속한다. 입력이 있으면 acceleration, 없으면 friction. 순수 함수(테스트 대상).
func step_velocity(current: Vector2, input_vector: Vector2, delta: float) -> Vector2:
	var target := desired_velocity(input_vector)
	var rate := acceleration if input_vector.length() > 0.01 else friction
	return current.move_toward(target, rate * delta)


## 실시간 입력을 모아 방향 벡터로 반환한다 (I/O — 단위 테스트 제외).
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
