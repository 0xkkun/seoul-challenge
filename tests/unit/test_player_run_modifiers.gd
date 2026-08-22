extends Node

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	HitStopManager.restore()


func after_each() -> void:
	HitStopManager.restore()
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


func test_shadow_knot_extends_dodge_invulnerability() -> void:
	var player = PlayerScript.new()
	add_child(player)
	var base_invuln: float = player.dodge_invuln_time

	_runner.assert_true(player.apply_run_modifier(&"shadow_knot"), "shadow knot item applies")
	_runner.assert_true(is_equal_approx(player.dodge_invuln_time, base_invuln + 0.25), "shadow knot extends dodge invulnerability by 0.25 seconds")

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "dodge starts after shadow knot is applied")
	_runner.assert_true(is_equal_approx(player.get_invuln_remaining(), player.dodge_invuln_time), "dodge uses the extended invulnerability window")


func test_full_swing_stance_boosts_bat_knockback_with_attack_speed_tradeoff() -> void:
	var player = PlayerScript.new()
	add_child(player)
	var base_knockback: float = player.bat_knockback
	var base_attack_cooldown: float = player.attack_cooldown

	_runner.assert_true(player.apply_run_modifier(&"full_swing_stance"), "full swing stance applies")
	_runner.assert_true(is_equal_approx(player.bat_knockback, base_knockback * 1.4), "full swing increases bat knockback")
	_runner.assert_true(player.attack_cooldown > base_attack_cooldown, "full swing slows melee attack cadence")


func test_breathing_room_heals_on_later_room_clear_without_instant_heal() -> void:
	var player = PlayerScript.new()
	var health_events: Array[Dictionary] = []
	var on_health_changed := func(payload: Dictionary) -> void:
		health_events.append(payload)
	EventBus.player_health_changed.connect(on_health_changed)
	add_child(player)

	player.take_damage(2)
	_runner.assert_eq(player.get_health(), 3, "test starts from damaged health")
	_runner.assert_true(player.apply_run_modifier(&"breathing_room"), "breathing room applies")
	_runner.assert_eq(player.get_health(), 3, "breathing room does not heal immediately on pickup")
	_runner.assert_true(player.has_method("apply_room_clear_modifier_effects"), "player exposes room clear modifier hook")
	if not player.has_method("apply_room_clear_modifier_effects"):
		EventBus.player_health_changed.disconnect(on_health_changed)
		return

	_runner.assert_true(player.call("apply_room_clear_modifier_effects"), "breathing room heals on room clear")
	_runner.assert_eq(player.get_health(), 4, "breathing room restores one heart after a later room clear")
	_runner.assert_eq(health_events[health_events.size() - 1]["current"], 4, "room clear healing broadcasts HUD health update")
	_runner.assert_true(player.call("apply_room_clear_modifier_effects"), "breathing room can heal on each later room clear")
	_runner.assert_eq(player.get_health(), 5, "room clear healing clamps to max health")
	EventBus.player_health_changed.disconnect(on_health_changed)
