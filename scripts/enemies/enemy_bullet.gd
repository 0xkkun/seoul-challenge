extends Area2D
## 적 투사체(#16 원거리 잡몹 공용) — 직선 이동, 플레이어 피격 시 take_damage.
## 충돌 마스크 = 플레이어 레이어(2)만 → 적/적탄끼리는 안 맞음.

@export var speed: float = 320.0
@export var lifetime: float = 3.0
@export var damage: int = 1
@export var deflect_speed: float = 540.0  ## 배트로 되받아칠 때 속도(되돌아가는 손맛)
@export var deflect_damage: int = 3       ## 반사탄이 적에게 주는 피해(타이밍 패리 보상)

const DEFLECT_COLOR := Color(0.35, 0.85, 1.0)  ## 반사탄 시각 표시(청록)

var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _deflected: bool = false


func _ready() -> void:
	add_to_group(&"enemy_projectile")  ## 배트가 부채꼴 안에서 되받아칠 수 있게(#24)
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


## 발사 — 위치/방향 설정 후 활성.
func launch(spawn_position: Vector2, direction: Vector2) -> void:
	global_position = spawn_position
	_direction = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	rotation = _direction.angle()
	_life = lifetime


## 배트로 되받아치기(#24 deflect) — swing 방향으로 진행 방향을 바꾸고, 타격 대상을
## 플레이어(레이어2) → 적(레이어1)으로 전환한다. 적탄 그룹에서 빠져 재반사도 방지.
func deflect(new_direction: Vector2) -> void:
	if _deflected:
		return
	_deflected = true
	_direction = new_direction.normalized() if new_direction.length() > 0.001 else -_direction
	rotation = _direction.angle()
	speed = deflect_speed
	damage = deflect_damage
	collision_mask = 1
	remove_from_group(&"enemy_projectile")
	_life = lifetime
	modulate = DEFLECT_COLOR


func _physics_process(delta: float) -> void:
	global_position = step_position(global_position, _direction, speed, delta)
	_life -= delta
	if _life <= 0.0:
		queue_free()


## 직선 이동. 순수 함수(테스트 대상).
func step_position(pos: Vector2, direction: Vector2, spd: float, delta: float) -> Vector2:
	return pos + direction * spd * delta


func _on_hit(other: Node) -> void:
	# deflect 후엔 적을 타격하는데, 마지막 적 처치가 body_entered(물리 플러시) 중
	# CombatRoom 클리어 → 문 monitoring/collision 변경을 유발할 수 있다(신호 중 차단 위험).
	# purify_bullet 과 동일하게 피해 적용을 deferred 로 미뤄 idle 에서 일어나게 한다.
	if other != null and other.has_method("take_damage"):
		other.call_deferred("take_damage", damage)
	queue_free()
