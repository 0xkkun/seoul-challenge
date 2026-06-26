extends Node
## #10 정화탄 — 순수 이동/수명 수학 + PoolManager 풀링 단위 테스트.

const BULLET_SCENE := preload("res://scenes/projectiles/purify_bullet.tscn")
const POOL_ID := &"test_purify_bullet"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()


func after_each() -> void:
	PoolManager.clear_all()


func test_step_position_is_straight_line() -> void:
	var b = BULLET_SCENE.instantiate()
	var p: Vector2 = b.step_position(Vector2.ZERO, Vector2.RIGHT, 100.0, 0.5)
	_runner.assert_true(is_equal_approx(p.x, 50.0), "직선 이동: x = speed*delta")
	_runner.assert_true(is_equal_approx(p.y, 0.0), "수평 이동: y 불변")
	b.free()


func test_lifetime_expiry() -> void:
	var b = BULLET_SCENE.instantiate()
	_runner.assert_true(is_equal_approx(b.step_lifetime(1.0, 0.3), 0.7), "수명은 delta만큼 감소")
	_runner.assert_true(b.is_expired(0.0), "0이면 만료")
	_runner.assert_false(b.is_expired(0.5), "양수면 미만료")
	b.free()


func test_pool_acquire_release_reuse() -> void:
	PoolManager.register_scene(POOL_ID, BULLET_SCENE, 0, self)
	var first = PoolManager.acquire(POOL_ID, self)
	_runner.assert_not_null(first, "acquire가 정화탄 인스턴스를 반환")
	first.activate(Vector2(10.0, 0.0), Vector2.RIGHT)
	_runner.assert_eq(PoolManager.get_active_count(POOL_ID), 1)
	PoolManager.release(first)
	_runner.assert_eq(PoolManager.get_active_count(POOL_ID), 0)
	_runner.assert_eq(PoolManager.get_available_count(POOL_ID), 1)
	var second = PoolManager.acquire(POOL_ID, self)
	_runner.assert_true(first == second, "released 인스턴스를 재사용")


func test_ignores_shooter() -> void:
	var b = BULLET_SCENE.instantiate()
	var shooter := Node.new()
	b.activate(Vector2.ZERO, Vector2.RIGHT, shooter)
	_runner.assert_false(b.is_blocking_hit(shooter), "발사자 충돌은 무시")
	_runner.assert_false(b.is_blocking_hit(null), "null 충돌은 무시")
	var other := Node.new()
	_runner.assert_true(b.is_blocking_hit(other), "다른 노드는 차단성 충돌")
	shooter.free()
	other.free()
	b.free()
