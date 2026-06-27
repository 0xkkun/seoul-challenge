extends Node

const AKGWI_SCENE_PATH := "res://scenes/enemies/akgwi.tscn"
const COMBAT_ROOM_SCENE_PATH := "res://scenes/interactables/combat_room.tscn"

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


func test_combat_room_uses_akgwi_as_default_melee_enemy() -> void:
	var room := (load(COMBAT_ROOM_SCENE_PATH) as PackedScene).instantiate()
	add_child(room)
	_runner.assert_eq(room.chaser_scene.resource_path, AKGWI_SCENE_PATH, "combat room default melee enemy is akgwi")
