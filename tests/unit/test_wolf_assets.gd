extends Node

const WOLF_SCENE_PATH := "res://scenes/enemies/wolf.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"
const PlayerScript := preload("res://scripts/player/player.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const L_STRONG := 2

var _runner: Node


class DamageTarget:
	extends Node2D

	var damage_taken := 0

	func take_damage(amount: int) -> void:
		damage_taken += amount


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_wolf_scene_uses_5_move_and_6_attack_frames() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "wolf uses an AnimatedSprite2D visual")
	if sprite == null or sprite.sprite_frames == null:
		return

	var frames := sprite.sprite_frames
	_runner.assert_eq(frames.get_frame_count(&"move"), 5, "wolf move sheet is split into five 144px frames")
	_runner.assert_eq(frames.get_frame_count(&"attack"), 6, "wolf attack sheet is split into six 144px frames")
	_runner.assert_true(frames.get_animation_loop(&"move"), "wolf movement loops")
	_runner.assert_false(frames.get_animation_loop(&"attack"), "wolf attack does not loop")


func test_wolf_takes_three_default_bat_hits() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var player := PlayerScript.new()
	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	add_child(player)
	add_child(enemy)

	_runner.assert_true(enemy.max_hp > player.bat_damage * 2, "wolf should survive two default bat hits")
	_runner.assert_true(enemy.max_hp <= player.bat_damage * 3, "wolf should die by the third default bat hit")


func test_wolf_contact_range_starts_before_body_overlap() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	var player := PlayerScene.instantiate()

	var enemy_collision := enemy.get_node_or_null("Collision") as CollisionShape2D
	var player_collision := player.get_node_or_null("Collision") as CollisionShape2D
	_runner.assert_not_null(enemy_collision, "wolf has a collision shape")
	_runner.assert_not_null(player_collision, "player has a collision shape")
	if enemy_collision == null or player_collision == null:
		enemy.free()
		player.free()
		return

	var enemy_shape := enemy_collision.shape as CircleShape2D
	var player_shape := player_collision.shape as CircleShape2D
	_runner.assert_not_null(enemy_shape, "wolf collision shape is circular")
	_runner.assert_not_null(player_shape, "player collision shape is circular")
	if enemy_shape == null or player_shape == null:
		enemy.free()
		player.free()
		return

	var body_touch_distance := enemy_shape.radius + player_shape.radius
	_runner.assert_true(
		enemy.contact_range >= body_touch_distance + 16.0,
		"wolf dash hit range should start before collision bodies overlap"
	)
	enemy.free()
	player.free()


func test_wolf_dash_state_machine_prepares_charges_and_recovers() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	_runner.assert_true(enemy.has_method("tick_dash_ai"), "wolf exposes a testable dash AI tick")
	_runner.assert_true(enemy.has_method("get_dash_state"), "wolf exposes dash state for contract tests")
	if not enemy.has_method("tick_dash_ai") or not enemy.has_method("get_dash_state"):
		return

	var far_velocity: Vector2 = enemy.call("tick_dash_ai", 0.1, Vector2.ZERO, Vector2.RIGHT * 180.0)
	_runner.assert_eq(enemy.call("get_dash_state"), &"chase", "wolf starts by chasing outside dash range")
	_runner.assert_true(
		far_velocity.x > 0.0 and far_velocity.length() <= enemy.move_speed + 0.001,
		"wolf chases toward a far target"
	)

	var prepare_velocity: Vector2 = enemy.call("tick_dash_ai", 0.1, Vector2.ZERO, Vector2.RIGHT * enemy.dash_trigger_range)
	_runner.assert_eq(enemy.call("get_dash_state"), &"prepare", "wolf prepares when the target enters dash range")
	_runner.assert_eq(prepare_velocity, Vector2.ZERO, "wolf pauses during dash windup")

	var dash_velocity: Vector2 = enemy.call(
		"tick_dash_ai",
		enemy.dash_windup_time,
		Vector2.ZERO,
		Vector2.RIGHT * enemy.dash_trigger_range
	)
	_runner.assert_eq(enemy.call("get_dash_state"), &"dash", "wolf enters dash after windup")
	_runner.assert_true(is_equal_approx(dash_velocity.length(), enemy.dash_speed), "wolf dashes at configured dash speed")

	var recover_velocity: Vector2 = enemy.call(
		"tick_dash_ai",
		enemy.dash_duration,
		Vector2.ZERO,
		Vector2.RIGHT * enemy.dash_trigger_range
	)
	_runner.assert_eq(enemy.call("get_dash_state"), &"recover", "wolf recovers after dash duration")
	_runner.assert_eq(recover_velocity, Vector2.ZERO, "wolf pauses during recovery")

	enemy.call("tick_dash_ai", enemy.dash_recover_time, Vector2.ZERO, Vector2.RIGHT * 180.0)
	_runner.assert_eq(enemy.call("get_dash_state"), &"chase", "wolf returns to chase after recovery")


func test_wolf_dash_hit_applies_damage_once_per_dash() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	var target := DamageTarget.new()
	add_child(enemy)
	add_child(target)
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 8.0

	enemy.call("tick_dash_ai", 0.1, enemy.global_position, target.global_position)
	enemy.call("tick_dash_ai", enemy.dash_windup_time, enemy.global_position, target.global_position)
	enemy.call("_try_dash_hit", target)
	enemy.call("_try_dash_hit", target)

	_runner.assert_eq(
		target.damage_taken,
		enemy.contact_damage,
		"wolf dash only damages a target once during the active dash"
	)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "wolf sprite remains mounted after dash hit")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"attack", "wolf plays attack animation during dash")


func test_wolf_dash_hit_is_blocked_while_stunned() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	var target := DamageTarget.new()
	add_child(enemy)
	add_child(target)
	enemy.target_group = &"wolf_status_test_target"
	target.add_to_group(&"wolf_status_test_target")
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 8.0

	enemy.call("tick_dash_ai", 0.1, enemy.global_position, target.global_position)
	enemy.call("tick_dash_ai", enemy.dash_windup_time, enemy.global_position, target.global_position)
	_runner.assert_eq(enemy.call("get_dash_state"), &"dash", "test setup puts wolf in active dash")

	enemy.call("apply_status_effect", &"stun", 1.0)
	_runner.assert_true(enemy.call("is_status_action_blocked"), "test setup blocks wolf actions")
	enemy.call("_try_dash_hit", target)

	_runner.assert_eq(target.damage_taken, 0, "stunned wolf dash cannot damage the player")


func test_wolf_dash_can_be_parried_into_recovery() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	var target := DamageTarget.new()
	add_child(enemy)
	add_child(target)
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 8.0

	enemy.call("tick_dash_ai", 0.1, enemy.global_position, target.global_position)
	enemy.call("tick_dash_ai", enemy.dash_windup_time, enemy.global_position, target.global_position)
	_runner.assert_eq(enemy.call("get_dash_state"), &"dash", "test setup puts wolf in active dash")
	_runner.assert_true(enemy.has_method("parry_dash"), "wolf exposes a dash parry API for bat timing")
	if not enemy.has_method("parry_dash"):
		return

	var parried: bool = bool(enemy.call("parry_dash", Vector2.LEFT))
	_runner.assert_true(parried, "active wolf dash can be parried")
	_runner.assert_eq(enemy.call("get_dash_state"), &"recover", "parried wolf exits active dash into recovery")

	enemy.call("_try_dash_hit", target)
	_runner.assert_eq(target.damage_taken, 0, "parried wolf dash cannot damage after being stopped")


func test_wolf_dash_parry_vibrates() -> void:
	_runner.assert_true(ResourceLoader.exists(WOLF_SCENE_PATH), "wolf dash enemy scene exists")
	if not ResourceLoader.exists(WOLF_SCENE_PATH):
		return

	HapticManager.test_mode = true
	HapticManager.test_log.clear()
	HapticManager._enabled = true
	HapticManager._last_any_ms = -100000
	HapticManager._last_cat_ms.clear()
	HapticManager._test_now = 1000

	var enemy := (load(WOLF_SCENE_PATH) as PackedScene).instantiate()
	var target := DamageTarget.new()
	add_child(enemy)
	add_child(target)
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 8.0
	enemy.call("tick_dash_ai", 0.1, enemy.global_position, target.global_position)
	enemy.call("tick_dash_ai", enemy.dash_windup_time, enemy.global_position, target.global_position)

	enemy.call("parry_dash", Vector2.LEFT)

	_runner.assert_eq(HapticManager.test_log, [L_STRONG], "늑대 돌격 패링은 강한 진동을 준다")
	HapticManager.test_mode = false
	HapticManager.test_log.clear()
	HapticManager._test_now = -1


func test_combat_room_can_spawn_wolf_dash_enemy_from_config() -> void:
	var room := (load(COMBAT_ROOM_SCENE_PATH) as PackedScene).instantiate()
	add_child(room)
	room.call("apply_room_config", {
		"chaser_count": 0,
		"ranged_count": 0,
		"wolf_count": 1,
		"elite_wolf_count": 1,
		"wave_count": 1,
	})

	var summary: Dictionary = room.call("get_encounter_summary")
	_runner.assert_eq(summary.get("wolf_count", -1), 1, "combat summary includes normal wolf count")
	_runner.assert_eq(summary.get("elite_wolf_count", -1), 1, "combat summary includes elite wolf count")
	_runner.assert_eq(summary.get("total_count", -1), 2, "combat total includes wolves")

	room.enter()

	_runner.assert_eq(room.call("get_remaining_enemy_count"), 2, "combat room spawns configured wolf enemies")
	var wolf_count := 0
	var elite_wolf_count := 0
	for enemy: Node in room.call("get_active_enemies"):
		if String(enemy.name).begins_with("Wolf"):
			wolf_count += 1
		if String(enemy.name).begins_with("EliteWolf"):
			elite_wolf_count += 1
			_runner.assert_true(enemy.is_in_group(&"elite_enemy"), "elite wolf joins elite group")
	_runner.assert_eq(wolf_count, 1, "normal wolf has a clear scene name")
	_runner.assert_eq(elite_wolf_count, 1, "elite wolf has a clear scene name")
