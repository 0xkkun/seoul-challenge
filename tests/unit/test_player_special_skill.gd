extends Node

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_special_cooldown_decrements_and_clamps() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("step_special_cooldown"), "player exposes special cooldown math")
	if not player.has_method("step_special_cooldown"):
		player.free()
		return
	_runner.assert_true(is_equal_approx(player.step_special_cooldown(1.5, 0.4), 1.1), "cooldown steps down")
	_runner.assert_true(is_equal_approx(player.step_special_cooldown(0.2, 0.4), 0.0), "cooldown clamps to zero")
	player.free()


func test_special_use_requires_charge_and_ready_cooldown() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("can_use_special_skill"), "player exposes special use gate")
	if not player.has_method("can_use_special_skill"):
		player.free()
		return
	_runner.assert_true(player.can_use_special_skill(1, 0.0, false), "charge and ready cooldown allows skill")
	_runner.assert_false(player.can_use_special_skill(0, 0.0, false), "no charges blocks skill")
	_runner.assert_false(player.can_use_special_skill(1, 0.1, false), "cooldown blocks skill")
	_runner.assert_false(player.can_use_special_skill(1, 0.0, true), "active dodge blocks duplicate skill")
	player.free()


func test_dodge_direction_prefers_move_then_facing() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("choose_dodge_direction"), "player exposes dodge direction math")
	if not player.has_method("choose_dodge_direction"):
		player.free()
		return
	_runner.assert_eq(player.choose_dodge_direction(Vector2.RIGHT, Vector2.DOWN), Vector2.RIGHT, "move input wins")
	_runner.assert_eq(player.choose_dodge_direction(Vector2.ZERO, Vector2.UP), Vector2.UP, "facing is fallback")
	player.free()


func test_start_dodge_consumes_charge_sets_cooldown_and_invuln() -> void:
	var player = PlayerScript.new()
	add_child(player)
	_runner.assert_true(player.has_method("try_start_special_skill"), "player exposes special skill trigger")
	if not player.has_method("try_start_special_skill"):
		return
	player.special_skill_max_uses = 2
	player.special_skill_uses_remaining = 2
	player.special_skill_cooldown = 1.25
	player.dodge_duration = 0.16
	player.dodge_invuln_time = 0.24

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "ready skill starts dodge")
	_runner.assert_true(player.is_dodging(), "player enters dodge state")
	_runner.assert_eq(player.special_skill_uses_remaining, 1, "dodge consumes one charge")
	_runner.assert_true(is_equal_approx(player.get_special_cooldown_remaining(), 1.25), "dodge starts cooldown")
	_runner.assert_true(player.get_invuln_remaining() >= 0.24, "dodge grants short invulnerability")
