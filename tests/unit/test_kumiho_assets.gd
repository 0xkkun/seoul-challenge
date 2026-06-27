extends Node

const KUMIHO_SCENE_PATH := "res://scenes/enemies/kumiho.tscn"
const KUMIHO_FIREBALL_SCENE_PATH := "res://scenes/enemies/kumiho_fireball.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_kumiho_scene_uses_5_move_and_6_attack_frames() -> void:
	_runner.assert_true(ResourceLoader.exists(KUMIHO_SCENE_PATH), "kumiho ranged enemy scene exists")
	if not ResourceLoader.exists(KUMIHO_SCENE_PATH):
		return

	var enemy := (load(KUMIHO_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "kumiho uses an AnimatedSprite2D visual")
	if sprite == null:
		return

	var frames := sprite.sprite_frames
	_runner.assert_not_null(frames, "kumiho has sprite frames")
	if frames == null:
		return
	_runner.assert_eq(frames.get_frame_count(&"move"), 5, "kumiho move sheet is split into five 128px frames")
	_runner.assert_eq(frames.get_frame_count(&"attack"), 6, "kumiho attack sheet is split into six 128px frames")
	_runner.assert_true(frames.get_animation_loop(&"move"), "kumiho movement loops")
	_runner.assert_false(frames.get_animation_loop(&"attack"), "kumiho attack does not loop")


func test_kumiho_fireball_uses_4_fly_frames() -> void:
	_runner.assert_true(ResourceLoader.exists(KUMIHO_FIREBALL_SCENE_PATH), "kumiho fireball projectile scene exists")
	if not ResourceLoader.exists(KUMIHO_FIREBALL_SCENE_PATH):
		return

	var bullet := (load(KUMIHO_FIREBALL_SCENE_PATH) as PackedScene).instantiate()
	add_child(bullet)
	var sprite := bullet.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "kumiho fireball uses an AnimatedSprite2D visual")
	if sprite == null or sprite.sprite_frames == null:
		return
	_runner.assert_eq(sprite.sprite_frames.get_frame_count(&"fly"), 4, "kumiho fireball sheet is split into four 128px frames")
	_runner.assert_true(sprite.sprite_frames.get_animation_loop(&"fly"), "kumiho fireball loops while traveling")


func test_kumiho_fires_fireball_and_plays_attack_animation() -> void:
	_runner.assert_true(ResourceLoader.exists(KUMIHO_SCENE_PATH), "kumiho ranged enemy scene exists")
	if not ResourceLoader.exists(KUMIHO_SCENE_PATH):
		return

	var enemy := (load(KUMIHO_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	_runner.assert_true(enemy.has_method("get_projectile_scene_path"), "ranged enemy exposes projectile scene contract")
	if enemy.has_method("get_projectile_scene_path"):
		_runner.assert_eq(enemy.get_projectile_scene_path(), KUMIHO_FIREBALL_SCENE_PATH, "kumiho fires the kumiho fireball projectile")

	var fired: bool = bool(enemy.tick_fire(enemy.fire_interval, Vector2.ZERO, Vector2.RIGHT))
	_runner.assert_true(fired, "kumiho fires after its interval")
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "kumiho sprite remains mounted after firing")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"attack", "kumiho switches to attack animation when firing")


func test_kumiho_attack_faces_target_even_while_retreating() -> void:
	_runner.assert_true(ResourceLoader.exists(KUMIHO_SCENE_PATH), "kumiho ranged enemy scene exists")
	if not ResourceLoader.exists(KUMIHO_SCENE_PATH):
		return

	var enemy := (load(KUMIHO_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "kumiho uses an AnimatedSprite2D visual")
	if sprite == null:
		return

	enemy.velocity = Vector2.RIGHT
	var fired: bool = bool(enemy.tick_fire(enemy.fire_interval, Vector2.ZERO, Vector2.LEFT))

	_runner.assert_true(fired, "kumiho fires when cooldown is ready")
	_runner.assert_true(sprite.flip_h, "kumiho attack faces the target even when retreat velocity points away")
	enemy.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "kumiho attack facing is not overwritten by retreat velocity while attack plays")


func test_kumiho_sprite_flips_with_horizontal_movement_and_holds_when_idle() -> void:
	_runner.assert_true(ResourceLoader.exists(KUMIHO_SCENE_PATH), "kumiho ranged enemy scene exists")
	if not ResourceLoader.exists(KUMIHO_SCENE_PATH):
		return

	var enemy := (load(KUMIHO_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "kumiho uses an AnimatedSprite2D visual")
	if sprite == null:
		return

	enemy.velocity = Vector2.LEFT
	enemy.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "kumiho flips left while moving left")

	enemy.velocity = Vector2.UP
	enemy.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "kumiho keeps the last horizontal facing while moving vertically")

	enemy.velocity = Vector2.RIGHT
	enemy.call("_update_animation")
	_runner.assert_false(sprite.flip_h, "kumiho faces right while moving right")


func test_combat_room_uses_kumiho_as_default_ranged_enemy() -> void:
	var room := (load(COMBAT_ROOM_SCENE_PATH) as PackedScene).instantiate()
	add_child(room)
	_runner.assert_eq(room.ranged_scene.resource_path, KUMIHO_SCENE_PATH, "combat room default ranged enemy is kumiho")
