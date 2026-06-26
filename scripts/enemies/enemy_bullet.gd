extends Area2D
## 적 투사체(#17 보스 탄막 / #16 원거리 잡몹 공용) — 직선 이동, 플레이어 피격 시 take_damage.
## 충돌 마스크 = 플레이어 레이어(2)만 → 적/적탄끼리는 안 맞음.

@export var speed: float = 320.0
@export var lifetime: float = 3.0
@export var damage: int = 1

var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0


func _ready() -> void:
	add_to_group(&"enemy_projectile")  ## 배트가 부채꼴 안에서 지울 수 있게(#24)
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


## 발사 — 위치/방향 설정 후 활성.
func launch(spawn_position: Vector2, direction: Vector2) -> void:
	global_position = spawn_position
	_direction = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	rotation = _direction.angle()
	_life = lifetime


func _physics_process(delta: float) -> void:
	global_position = step_position(global_position, _direction, speed, delta)
	_life -= delta
	if _life <= 0.0:
		queue_free()


## 직선 이동. 순수 함수(테스트 대상).
func step_position(pos: Vector2, direction: Vector2, spd: float, delta: float) -> Vector2:
	return pos + direction * spd * delta


func _on_hit(other: Node) -> void:
	if other != null and other.has_method("take_damage"):
		other.call("take_damage", damage)
	queue_free()
