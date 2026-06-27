extends Node
## #51 플레이어·적 공용 상태이상 적용 계약.

const PlayerScript := preload("res://scripts/player/player.gd")
const ChaserScene := preload("res://scenes/enemies/chaser.tscn")
const RangedShooterScene := preload("res://scenes/enemies/ranged_shooter.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_player_exposes_common_status_effect_api() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("apply_status_effect"), "플레이어는 공용 상태이상 적용 API를 노출한다")
	if not player.has_method("apply_status_effect"):
		player.free()
		return
	player.call("apply_status_effect", &"stun", 1.0)
	_runner.assert_true(player.call("is_status_movement_blocked"), "기절 상태의 플레이어는 이동할 수 없다")
	_runner.assert_true(player.call("is_status_action_blocked"), "기절 상태의 플레이어는 행동할 수 없다")
	_runner.assert_false(player.try_start_special_skill(Vector2.RIGHT), "기절 중 특수 스킬을 시작하지 않는다")
	player.free()


func test_player_can_cleanse_negative_status_effects() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("clear_negative_status_effects"), "플레이어는 정화 API를 노출한다")
	if not player.has_method("clear_negative_status_effects"):
		player.free()
		return
	player.call("apply_status_effect", &"slow", 3.0, {"speed_multiplier": 0.4})
	player.call("clear_negative_status_effects")
	_runner.assert_false(player.call("has_status_effect", &"slow"), "정화 후 둔화가 제거된다")
	_runner.assert_true(is_equal_approx(player.call("get_status_speed_multiplier"), 1.0), "정화 후 이동 배속이 복구된다")
	player.free()


func test_player_root_stops_existing_velocity_immediately() -> void:
	var player = PlayerScript.new()
	add_child(player)
	player.velocity = Vector2.RIGHT * 120.0
	player.call("apply_status_effect", &"root", 1.0)
	player.call("_physics_process", 0.016)
	_runner.assert_true(player.velocity == Vector2.ZERO, "속박은 기존 이동 속도를 즉시 정지한다")
	player.queue_free()


func test_player_root_blocks_dodge_without_spending_charge() -> void:
	var player = PlayerScript.new()
	player.special_skill_uses_remaining = 2
	player.call("apply_status_effect", &"root", 1.0)
	var started: bool = player.try_start_special_skill(Vector2.RIGHT)
	_runner.assert_false(started, "속박 중 회피는 시작되지 않는다")
	_runner.assert_eq(player.special_skill_uses_remaining, 2, "속박 중 회피 충전을 소비하지 않는다")
	_runner.assert_false(player.is_dodging(), "속박 중 회피 타이머를 열지 않는다")
	player.free()


func test_chaser_status_effects_affect_physics() -> void:
	var target := Node2D.new()
	target.add_to_group(&"player")
	add_child(target)
	target.global_position = Vector2(100.0, 0.0)

	var enemy = ChaserScene.instantiate()
	add_child(enemy)
	_runner.assert_true(enemy.has_method("apply_status_effect"), "체이서는 공용 상태이상 API를 노출한다")
	if not enemy.has_method("apply_status_effect"):
		enemy.queue_free()
		target.queue_free()
		return
	enemy.call("apply_status_effect", &"slow", 1.0, {"speed_multiplier": 0.5})
	enemy.call("_physics_process", 0.1)
	_runner.assert_true(enemy.velocity.length() > 0.0, "둔화는 이동을 막지는 않는다")
	_runner.assert_true(enemy.velocity.length() <= enemy.move_speed * 0.5 + 0.01, "둔화 배속이 추적 속도에 반영된다")
	enemy.call("apply_status_effect", &"root", 1.0)
	enemy.call("_physics_process", 0.1)
	_runner.assert_true(enemy.velocity == Vector2.ZERO, "속박은 체이서 이동을 막는다")
	enemy.queue_free()
	target.queue_free()


func test_ranged_shooter_stun_blocks_movement_and_fire() -> void:
	var target := Node2D.new()
	target.add_to_group(&"player")
	add_child(target)
	target.global_position = Vector2(400.0, 0.0)

	var enemy = RangedShooterScene.instantiate()
	add_child(enemy)
	var shots := 0
	enemy.fired.connect(func(_origin, _dir): shots += 1)
	_runner.assert_true(enemy.has_method("apply_status_effect"), "원거리 적은 공용 상태이상 API를 노출한다")
	if not enemy.has_method("apply_status_effect"):
		enemy.queue_free()
		target.queue_free()
		return
	enemy.call("apply_status_effect", &"stun", enemy.fire_interval + 1.0)
	enemy.call("_physics_process", enemy.fire_interval + 0.1)
	_runner.assert_true(enemy.velocity == Vector2.ZERO, "기절은 원거리 적 이동을 막는다")
	_runner.assert_eq(shots, 0, "기절은 원거리 적 발사를 막는다")
	enemy.queue_free()
	target.queue_free()
