extends Node

const PlayerScript := preload("res://scripts/player/player.gd")
const PLAYER_DASH_SHEET_PATH := "res://assets/sprites/player/player_dash.png"
const PLAYER_DASH_SHEET_SHA256 := "5a4e69b5b9d2ec461aa2f2ab7e78077fda3fd7c21d96a194c84e573e8c15b199"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_default_dodge_cooldown_is_three_seconds() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(is_equal_approx(player.special_skill_cooldown, 3.0), "기본 대시 쿨타임은 3초다")
	player.free()


func test_special_cooldown_decrements_and_clamps() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("step_special_cooldown"), "player exposes special cooldown math")
	if not player.has_method("step_special_cooldown"):
		player.free()
		return
	_runner.assert_true(is_equal_approx(player.step_special_cooldown(1.5, 0.4), 1.1), "cooldown steps down")
	_runner.assert_true(is_equal_approx(player.step_special_cooldown(0.2, 0.4), 0.0), "cooldown clamps to zero")
	player.free()


func test_special_recharge_restores_one_charge_per_cooldown() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("step_special_recharge"), "player exposes special recharge math")
	if not player.has_method("step_special_recharge"):
		player.free()
		return

	var first: Dictionary = player.step_special_recharge(0, 3, 0.25, 0.25, 0.25)
	_runner.assert_eq(first["uses_remaining"], 1, "recharge completion restores one spent dodge")
	_runner.assert_true(is_equal_approx(float(first["recharge_remaining"]), 0.25), "partial charges keep recharging")

	var full: Dictionary = player.step_special_recharge(2, 3, 0.25, 0.25, 0.25)
	_runner.assert_eq(full["uses_remaining"], 3, "last recharge restores to max")
	_runner.assert_true(is_equal_approx(float(full["recharge_remaining"]), 0.0), "full charges stop recharge timer")
	player.free()


func test_special_use_requires_charge_and_inactive_dodge() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("can_use_special_skill"), "player exposes special use gate")
	if not player.has_method("can_use_special_skill"):
		player.free()
		return
	_runner.assert_true(player.can_use_special_skill(1, 0.0, false), "charge and ready cooldown allows skill")
	_runner.assert_false(player.can_use_special_skill(0, 0.0, false), "no charges blocks skill")
	_runner.assert_true(player.can_use_special_skill(1, 0.1, false), "recharge cooldown does not block a stored dash")
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


func test_dash_power_attack_window_uses_active_dodge_or_grace_timer() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("is_dash_power_attack_window_active"), "player exposes dash power attack window math")
	_runner.assert_true(player.has_method("step_dash_power_attack_window"), "player exposes dash power attack timer math")
	if not player.has_method("is_dash_power_attack_window_active") or not player.has_method("step_dash_power_attack_window"):
		player.free()
		return

	_runner.assert_true(player.is_dash_power_attack_window_active(0.1, 0.0), "active dodge enables power attack")
	_runner.assert_true(player.is_dash_power_attack_window_active(0.0, 0.1), "post-dodge grace enables power attack")
	_runner.assert_false(player.is_dash_power_attack_window_active(0.0, 0.0), "no dodge and no grace disables power attack")
	_runner.assert_true(is_equal_approx(player.step_dash_power_attack_window(0.15, 0.05), 0.1), "grace timer steps down")
	_runner.assert_true(is_equal_approx(player.step_dash_power_attack_window(0.05, 0.1), 0.0), "grace timer clamps to zero")
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


func test_dash_dust_state_places_effect_behind_dash_at_feet() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("build_dash_dust_effect_state"), "player exposes pure dash dust placement helper")
	if not player.has_method("build_dash_dust_effect_state"):
		player.free()
		return

	var right_state: Dictionary = player.call(
		"build_dash_dust_effect_state",
		Vector2.RIGHT,
		Vector2(108.0, 42.0),
		42.0,
		30.0,
		52.0
	)
	var up_state: Dictionary = player.call(
		"build_dash_dust_effect_state",
		Vector2.UP,
		Vector2(108.0, 42.0),
		42.0,
		30.0,
		52.0
	)

	_runner.assert_true((right_state["position"] as Vector2).x < 0.0, "right dash places dust behind the player")
	_runner.assert_true((right_state["position"] as Vector2).y > 40.0, "right dash keeps dust at foot height")
	_runner.assert_true(absf(absf(float(right_state["rotation"])) - PI) < 0.001, "right dash rotates sheet toward the trailing direction")
	_runner.assert_true((right_state["scale"] as Vector2).is_equal_approx(Vector2.ONE), "native 42px dash dust sheet displays without scaling")
	_runner.assert_true((up_state["position"] as Vector2).y > 52.0, "up dash trails below the player")
	player.free()


func test_player_sprite_frames_include_dash_animation_from_download_asset() -> void:
	var source_sheet := load(PLAYER_DASH_SHEET_PATH) as Texture2D
	var frames := load("res://assets/sprites/player/player_baseball_frames.tres") as SpriteFrames

	_runner.assert_not_null(source_sheet, "player dash uses the supplied download dash sheet")
	if source_sheet != null:
		_runner.assert_eq(source_sheet.get_width(), 512, "dash source sheet has four 128px frames")
		_runner.assert_eq(source_sheet.get_height(), 128, "dash source sheet keeps the supplied 128px height")
		_runner.assert_eq(FileAccess.get_sha256(PLAYER_DASH_SHEET_PATH), PLAYER_DASH_SHEET_SHA256, "dash PNG matches the latest download asset")
	_runner.assert_not_null(frames, "player sprite frames load")
	if frames == null:
		return
	_runner.assert_true(frames.has_animation(&"dash"), "player sprite frames include dash animation")
	if not frames.has_animation(&"dash"):
		return
	_runner.assert_false(frames.get_animation_loop(&"dash"), "dash animation is a one-shot motion")
	_runner.assert_eq(frames.get_frame_count(&"dash"), 4, "dash animation uses all four download frames")
	for index in range(frames.get_frame_count(&"dash")):
		var atlas := frames.get_frame_texture(&"dash", index) as AtlasTexture
		_runner.assert_not_null(atlas, "dash frame %d uses an atlas texture" % index)
		if atlas != null:
			_runner.assert_eq(atlas.region, Rect2(index * 128, 0, 128, 128), "dash frame %d cuts a clean 128px region" % index)


func test_player_scene_includes_hidden_dash_dust_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var player_sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	var dust_root := player.get_node_or_null("DashDust") as Node2D
	var source_sheet := load("res://assets/effects/player_dash_dust.png") as Texture2D

	_runner.assert_not_null(source_sheet, "dash dust uses the supplied character dash sheet")
	if source_sheet != null:
		_runner.assert_eq(source_sheet.get_width(), 648, "dash dust source sheet has six 108px frames")
		_runner.assert_eq(source_sheet.get_height(), 42, "dash dust source sheet keeps the supplied 42px height")
	_runner.assert_not_null(dust_root, "player scene includes dash dust effect root")
	if dust_root != null:
		_runner.assert_false(dust_root.visible, "dash dust starts hidden")
		_runner.assert_true(dust_root.z_index > 0, "dash dust renders over the floor")
		if player_sprite != null:
			_runner.assert_true(player_sprite.z_index > dust_root.z_index, "player sprite renders over foot dash dust")
		var dust_sprite := dust_root.get_node_or_null("DustSprite") as Sprite2D
		_runner.assert_not_null(dust_sprite, "dash dust uses a sprite sheet node")
		if dust_sprite != null:
			_runner.assert_false(dust_sprite.visible, "dash dust sprite starts hidden with the root")
			_runner.assert_eq(dust_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "dash dust keeps pixel edges crisp")
			_runner.assert_eq(dust_sprite.hframes, 6, "dash dust sheet has six horizontal frames")
			_runner.assert_eq(dust_sprite.vframes, 1, "dash dust sheet has one row")
			_runner.assert_not_null(dust_sprite.texture, "dash dust sprite has a texture")
			if dust_sprite.texture != null:
				_runner.assert_eq(dust_sprite.texture.resource_path, "res://assets/effects/player_dash_dust.png", "dash dust uses the supplied sheet")
	player.queue_free()


func test_start_dodge_plays_character_dash_animation() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.special_skill_max_uses = 1
	player.special_skill_uses_remaining = 1

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "ready dodge starts")

	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "player scene includes animated character sprite")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"dash", "dodge button starts the character dash animation")
		_runner.assert_eq(sprite.frame, 0, "dash animation starts from the first frame")
		_runner.assert_false(sprite.flip_h, "right dodge keeps the dash sprite facing right")
	player.queue_free()


func test_dash_animation_survives_animation_update_while_dodging() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.special_skill_max_uses = 1
	player.special_skill_uses_remaining = 1

	_runner.assert_true(player.try_start_special_skill(Vector2.LEFT), "ready dodge starts")
	player._update_animation(Vector2.LEFT)

	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "player scene includes animated character sprite")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"dash", "movement animation update keeps dash while dodge is active")
		_runner.assert_true(sprite.flip_h, "left dodge flips the dash sprite")
	player.queue_free()


func test_dodge_clears_interrupted_attack_animation_state() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.special_skill_max_uses = 1
	player.special_skill_uses_remaining = 1
	player.dodge_duration = 0.0
	player._play_attack_anim(Vector2.RIGHT)

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "dodge can interrupt an attack animation")
	player._update_animation(Vector2.ZERO)

	var sprite := player.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "player scene includes animated character sprite")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"idle", "interrupted attack state does not keep blocking animation updates after dodge")
	player.queue_free()


func test_start_dodge_shows_dash_dust_at_feet() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.special_skill_max_uses = 1
	player.special_skill_uses_remaining = 1

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "ready dodge starts")

	var dust_root := player.get_node_or_null("DashDust") as Node2D
	var dust_sprite := dust_root.get_node_or_null("DustSprite") as Sprite2D if dust_root != null else null
	_runner.assert_not_null(dust_root, "player scene includes dash dust effect root")
	if dust_root != null:
		_runner.assert_true(dust_root.visible, "dodge reveals dash dust root")
		_runner.assert_true(dust_root.position.x < 0.0, "right dodge puts dust behind the player")
		_runner.assert_true(dust_root.position.y > 40.0, "dodge dust is anchored at the player's feet")
	_runner.assert_not_null(dust_sprite, "dash dust root has a sprite")
	if dust_sprite != null:
		_runner.assert_true(dust_sprite.visible, "dodge reveals dash dust sprite")
		_runner.assert_eq(dust_sprite.frame, 0, "dash dust animation starts from the first frame")
	player.queue_free()


func test_stored_dodge_charge_can_chain_before_recharge_cooldown_finishes() -> void:
	var player = PlayerScript.new()
	add_child(player)
	player.special_skill_max_uses = 3
	player.special_skill_uses_remaining = 3
	player.special_skill_cooldown = 3.0
	player.dodge_duration = 0.0
	player.dodge_invuln_time = 0.0

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "first stored dash starts")
	_runner.assert_eq(player.special_skill_uses_remaining, 2, "first dash consumes one stored charge")
	_runner.assert_true(player.get_special_cooldown_remaining() > 0.0, "spent dash starts recharge cooldown")

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "second stored dash can start before recharge cooldown ends")
	_runner.assert_eq(player.special_skill_uses_remaining, 1, "second dash consumes the next stored charge")
	_runner.assert_true(player.get_special_cooldown_remaining() > 0.0, "recharge cooldown keeps running after chained dash")


func test_spent_dodge_charge_recharges_and_becomes_usable_again() -> void:
	var player = PlayerScript.new()
	add_child(player)
	_runner.assert_true(player.has_method("get_special_recharge_remaining"), "player exposes special recharge timer state")
	if not player.has_method("get_special_recharge_remaining"):
		return
	player.special_skill_max_uses = 2
	player.special_skill_uses_remaining = 1
	player.special_skill_cooldown = 0.2
	player.dodge_duration = 0.0
	player.dodge_invuln_time = 0.0

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "last available dodge starts")
	_runner.assert_eq(player.special_skill_uses_remaining, 0, "dodge can spend the last charge")

	player._process_special_skill(0.2, Vector2.ZERO)

	_runner.assert_eq(player.special_skill_uses_remaining, 1, "cooldown completion recharges one dodge")
	_runner.assert_true(is_equal_approx(player.get_special_recharge_remaining(), 0.2), "partial charges keep recharging after one dodge returns")
	_runner.assert_true(player.can_use_special_skill(
		player.special_skill_uses_remaining,
		player.get_special_cooldown_remaining(),
		player.is_dodging()
	), "recharged dodge is immediately usable while the next charge refills")

	player._process_special_skill(0.2, Vector2.ZERO)

	_runner.assert_eq(player.special_skill_uses_remaining, 2, "unused recharge continues back to full")
	_runner.assert_true(is_equal_approx(player.get_special_recharge_remaining(), 0.0), "full dodge charges stop recharge")


func test_dodge_recharge_timer_does_not_block_extra_charges() -> void:
	var player = PlayerScript.new()
	add_child(player)
	player.special_skill_max_uses = 2
	player.special_skill_uses_remaining = 2
	player.special_skill_cooldown = 0.2
	player.dodge_duration = 0.0
	player.dodge_invuln_time = 0.0

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "first dodge starts from full")
	_runner.assert_eq(player.special_skill_uses_remaining, 1, "first dodge spends one charge")

	player._process_special_skill(0.1, Vector2.ZERO)

	_runner.assert_eq(player.special_skill_uses_remaining, 1, "partial recharge does not restore the spent charge yet")
	_runner.assert_true(player.can_use_special_skill(
		player.special_skill_uses_remaining,
		player.get_special_cooldown_remaining(),
		player.is_dodging()
	), "remaining stored charge is usable while recharge timer runs")

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "second stored dodge starts before recharge finishes")
	_runner.assert_eq(player.special_skill_uses_remaining, 0, "second dodge spends the remaining stored charge")


func test_start_dodge_opens_dash_power_attack_window() -> void:
	var player = PlayerScript.new()
	add_child(player)
	_runner.assert_true(player.has_method("get_dash_power_attack_remaining"), "player exposes dash power attack window state")
	if not player.has_method("get_dash_power_attack_remaining"):
		return
	player.dodge_duration = 0.16
	player.dash_power_attack_grace_time = 0.15

	_runner.assert_true(player.try_start_special_skill(Vector2.RIGHT), "ready dodge starts")

	_runner.assert_true(player.get_dash_power_attack_remaining() >= 0.15, "dodge opens post-dodge power attack grace")
