extends Node

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_apply_run_modifier_changes_stats_and_tracks_item() -> void:
	var player = PlayerScript.new()
	add_child(player)

	_runner.assert_true(player.has_method("apply_run_modifier"), "player exposes run modifier hook")
	_runner.assert_true(player.has_method("get_run_modifier_ids"), "player exposes active run modifiers")
	if not player.has_method("apply_run_modifier") or not player.has_method("get_run_modifier_ids"):
		return

	_runner.assert_true(player.apply_run_modifier(&"gung_talisman"), "known item applies")
	_runner.assert_eq(player.melee_damage, 2, "damage item changes barehand damage immediately")
	_runner.assert_eq(player.bat_damage, 3, "damage item changes bat damage immediately")
	_runner.assert_true(player.get_run_modifier_ids().has(&"gung_talisman"), "player tracks active run item")

	player.reset_run_modifiers()

	_runner.assert_eq(player.melee_damage, 1, "reset restores base melee damage")
	_runner.assert_eq(player.bat_damage, 2, "reset restores base bat damage")
	_runner.assert_eq(player.get_run_modifier_ids().size(), 0, "reset clears run item ids")


func test_max_health_modifier_heals_then_session_finish_resets() -> void:
	var player = PlayerScript.new()
	add_child(player)

	_runner.assert_true(player.has_method("apply_run_modifier"), "player exposes run modifier hook")
	_runner.assert_true(player.has_method("get_run_modifier_ids"), "player exposes active run modifiers")
	_runner.assert_true(player.has_method("reset_run_modifiers"), "player exposes run modifier reset")
	if not player.has_method("apply_run_modifier") or not player.has_method("get_run_modifier_ids") or not player.has_method("reset_run_modifiers"):
		return

	_runner.assert_true(player.apply_run_modifier(&"moon_guard"), "health item applies")
	_runner.assert_eq(player.max_health, 6, "health item raises max health")
	_runner.assert_eq(player.get_health(), 6, "health item grants the extra heart immediately")

	EventBus.emit_session_finished({"reason": "unit_test"})

	_runner.assert_eq(player.max_health, 5, "session finish resets run max health")
	_runner.assert_eq(player.get_health(), 5, "session finish clamps current health to restored max")
	_runner.assert_eq(player.get_run_modifier_ids().size(), 0, "session finish clears run items")


func test_health_restore_modifier_heals_current_health_without_raising_max() -> void:
	var player = PlayerScript.new()
	var health_events: Array[Dictionary] = []
	var on_health_changed := func(payload: Dictionary) -> void:
		health_events.append(payload)
	EventBus.player_health_changed.connect(on_health_changed)
	add_child(player)

	_runner.assert_true(player.has_method("apply_run_modifier"), "player exposes run modifier hook")
	if not player.has_method("apply_run_modifier"):
		EventBus.player_health_changed.disconnect(on_health_changed)
		return

	player.take_damage(3)
	_runner.assert_eq(player.get_health(), 2, "test starts from damaged current health")

	_runner.assert_true(player.apply_run_modifier(&"nurse_bandage"), "health recovery item applies")
	_runner.assert_eq(player.max_health, 5, "health recovery does not raise max health")
	_runner.assert_eq(player.get_health(), 4, "health recovery restores two current hearts")
	_runner.assert_eq(health_events[health_events.size() - 1]["current"], 4, "health recovery broadcasts HUD health update")
	_runner.assert_true(player.get_run_modifier_ids().has(&"nurse_bandage"), "player tracks health recovery reward")

	player.set("_invuln_timer", 0.0)
	player.take_damage(1)
	_runner.assert_eq(player.get_health(), 3, "test can damage player again after clearing invulnerability")
	_runner.assert_true(player.apply_run_modifier(&"nurse_bandage"), "second health recovery item applies")
	_runner.assert_eq(player.get_health(), 5, "health recovery clamps to max health")
	_runner.assert_eq(health_events[health_events.size() - 1]["current"], 5, "clamped health recovery broadcasts the clamped value")
	EventBus.player_health_changed.disconnect(on_health_changed)
