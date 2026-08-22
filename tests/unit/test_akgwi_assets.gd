extends Node

const AKGWI_SCENE_PATH := "res://scenes/enemies/akgwi.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"
const PlayerScript := preload("res://scripts/player/player.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")

var _runner: Node


class DamageTarget:
	extends Node2D

	var damage_taken := 0

	func take_damage(amount: int) -> void:
		damage_taken += amount


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_akgwi_scene_uses_6_move_and_6_attack_frames() -> void:
	_runner.assert_true(ResourceLoader.exists(AKGWI_SCENE_PATH), "akgwi melee enemy scene exists")
	if not ResourceLoader.exists(AKGWI_SCENE_PATH):
		return

	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "akgwi uses an AnimatedSprite2D visual")
	if sprite == null:
		return

	var frames := sprite.sprite_frames
	_runner.assert_not_null(frames, "akgwi has sprite frames")
	if frames == null:
		return
	_runner.assert_eq(frames.get_frame_count(&"move"), 6, "akgwi move sheet is split into six 128px frames")
	_runner.assert_eq(frames.get_frame_count(&"attack"), 6, "akgwi attack sheet is split into six 128px frames")
	_runner.assert_true(frames.get_animation_loop(&"move"), "akgwi movement loops")
	_runner.assert_false(frames.get_animation_loop(&"attack"), "akgwi attack does not loop")


func test_akgwi_contact_damage_plays_attack_animation() -> void:
	_runner.assert_true(ResourceLoader.exists(AKGWI_SCENE_PATH), "akgwi melee enemy scene exists")
	if not ResourceLoader.exists(AKGWI_SCENE_PATH):
		return

	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	var target := DamageTarget.new()
	add_child(enemy)
	add_child(target)
	enemy.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT

	enemy.call("_try_contact", target)

	_runner.assert_eq(target.damage_taken, enemy.contact_damage, "akgwi applies melee contact damage")
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "akgwi sprite remains mounted after contact")
	if sprite != null:
		_runner.assert_eq(sprite.animation, &"attack", "akgwi switches to attack animation on melee contact")


func test_akgwi_takes_three_default_bat_hits() -> void:
	_runner.assert_true(ResourceLoader.exists(AKGWI_SCENE_PATH), "akgwi melee enemy scene exists")
	if not ResourceLoader.exists(AKGWI_SCENE_PATH):
		return

	var player := PlayerScript.new()
	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	add_child(player)
	add_child(enemy)

	_runner.assert_true(enemy.max_hp > player.bat_damage * 2, "akgwi should survive two default bat hits")
	_runner.assert_true(enemy.max_hp <= player.bat_damage * 3, "akgwi should die by the third default bat hit")


func test_akgwi_contact_range_starts_before_body_overlap() -> void:
	_runner.assert_true(ResourceLoader.exists(AKGWI_SCENE_PATH), "akgwi melee enemy scene exists")
	if not ResourceLoader.exists(AKGWI_SCENE_PATH):
		return

	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	var player := PlayerScene.instantiate()

	var enemy_collision := enemy.get_node_or_null("Collision") as CollisionShape2D
	var player_collision := player.get_node_or_null("Collision") as CollisionShape2D
	_runner.assert_not_null(enemy_collision, "akgwi has a collision shape")
	_runner.assert_not_null(player_collision, "player has a collision shape")
	if enemy_collision == null or player_collision == null:
		enemy.free()
		player.free()
		return

	var enemy_shape := enemy_collision.shape as CircleShape2D
	var player_shape := player_collision.shape as CircleShape2D
	_runner.assert_not_null(enemy_shape, "akgwi collision shape is circular")
	_runner.assert_not_null(player_shape, "player collision shape is circular")
	if enemy_shape == null or player_shape == null:
		enemy.free()
		player.free()
		return

	var body_touch_distance := enemy_shape.radius + player_shape.radius
	_runner.assert_true(
		enemy.contact_range >= body_touch_distance + 16.0,
		"akgwi attack range should start before collision bodies overlap"
	)
	enemy.free()
	player.free()


func test_akgwi_sprite_flips_with_horizontal_movement_and_holds_when_idle() -> void:
	_runner.assert_true(ResourceLoader.exists(AKGWI_SCENE_PATH), "akgwi melee enemy scene exists")
	if not ResourceLoader.exists(AKGWI_SCENE_PATH):
		return

	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	add_child(enemy)
	var sprite := enemy.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "akgwi uses an AnimatedSprite2D visual")
	if sprite == null:
		return

	enemy.velocity = Vector2.LEFT
	enemy.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "akgwi flips left while moving left")

	enemy.velocity = Vector2.DOWN
	enemy.call("_update_animation")
	_runner.assert_true(sprite.flip_h, "akgwi keeps the last horizontal facing while moving vertically")

	enemy.velocity = Vector2.RIGHT
	enemy.call("_update_animation")
	_runner.assert_false(sprite.flip_h, "akgwi faces right while moving right")


func test_combat_room_uses_akgwi_as_default_melee_enemy() -> void:
	var room := (load(COMBAT_ROOM_SCENE_PATH) as PackedScene).instantiate()
	add_child(room)
	_runner.assert_eq(room.chaser_scene.resource_path, AKGWI_SCENE_PATH, "combat room default melee enemy is akgwi")
	var enemy := (load(AKGWI_SCENE_PATH) as PackedScene).instantiate()
	_runner.assert_eq(enemy.move_speed, 140.0, "akgwi scene inherits the calibrated chaser default")
	enemy.free()
