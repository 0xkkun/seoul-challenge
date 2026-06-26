extends Area2D
## #10 정화탄 — PoolManager 로 풀링되는 직선 투사체.
##
## ProjectileLauncher 가 플레이어의 fired 시그널을 받아 풀에서 꺼내 activate() 한다.
## 이동/수명 수학은 순수 함수로 분리해 물리 없이 단위 테스트한다.
## 자기 자신을 free() 하지 않고 PoolManager.release(self) 로 풀에 반환한다.

@export var speed: float = 620.0      ## 이동 속도 (px/s)
@export var lifetime: float = 1.2     ## 최대 수명 (s)
@export var damage: int = 1           ## 적에게 주는 피해

var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _shooter: Node = null


func _ready() -> void:
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)


## 풀에서 꺼내 발사 지점/방향으로 활성화한다.
func activate(spawn_position: Vector2, direction: Vector2, shooter: Node = null) -> void:
	global_position = spawn_position
	_direction = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	rotation = _direction.angle()
	_life = lifetime
	_shooter = shooter


func _physics_process(delta: float) -> void:
	global_position = step_position(global_position, _direction, speed, delta)
	_life = step_lifetime(_life, delta)
	if is_expired(_life):
		_release()


# --- 순수 함수(테스트 대상) ---

func step_position(pos: Vector2, direction: Vector2, spd: float, delta: float) -> Vector2:
	return pos + direction * spd * delta


func step_lifetime(life: float, delta: float) -> float:
	return life - delta


func is_expired(life: float) -> bool:
	return life <= 0.0


## 차단성 충돌 판정 — 발사자 자신/null 은 무시한다 (스폰 시 겹침으로 인한 자기 회수 방지).
func is_blocking_hit(other: Node) -> bool:
	return other != null and other != _shooter


# --- 풀 훅 / 충돌 ---

func reset_for_pool() -> void:
	_life = 0.0
	_direction = Vector2.RIGHT
	_shooter = null


func _on_hit(other: Node) -> void:
	if not is_blocking_hit(other):
		return
	if other.has_method("take_damage"):
		other.call("take_damage", damage)
	call_deferred("_release")


func _release() -> void:
	PoolManager.release(self)
