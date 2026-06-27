extends Node

const BOSS_SCENE_PATH := "res://scenes/enemies/boss.tscn"
const BOSS_MOVE_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_move.png"
const BOSS_WEAK_ATTACK_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_weak_attack.png"
const BOSS_STRONG_ATTACK_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_strong_attack.png"
const BOSS_MOVE_SHEET_SHA256 := "198e587280591db55a7fe5e98cfe43665dd71473461a60c9affce6047fed991f"
const BOSS_WEAK_ATTACK_SHEET_SHA256 := "31ec726d331e17a71c662bc4a54dd2c5b3fe7ea943c6b180b293cbea4a5a36dc"
const BOSS_STRONG_ATTACK_SHEET_SHA256 := "6d36f04ba30b8b2ded82840a27a758953002da07f50a12566a7eff0ca3a5d8f3"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_boss_png_sources_match_latest_download_assets() -> void:
	_runner.assert_eq(
		FileAccess.get_sha256(BOSS_MOVE_SHEET_PATH),
		BOSS_MOVE_SHEET_SHA256,
		"boss move source sheet matches the latest downloaded asset"
	)
	_runner.assert_eq(
		FileAccess.get_sha256(BOSS_WEAK_ATTACK_SHEET_PATH),
		BOSS_WEAK_ATTACK_SHEET_SHA256,
		"boss weak attack source sheet matches the latest downloaded asset"
	)
	_runner.assert_eq(
		FileAccess.get_sha256(BOSS_STRONG_ATTACK_SHEET_PATH),
		BOSS_STRONG_ATTACK_SHEET_SHA256,
		"boss strong attack source sheet matches the latest downloaded asset"
	)


func test_boss_scene_uses_move_weak_and_strong_attack_frames() -> void:
	var boss := (load(BOSS_SCENE_PATH) as PackedScene).instantiate()
	add_child(boss)
	var sprite := boss.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "boss uses an AnimatedSprite2D visual")
	if sprite == null or sprite.sprite_frames == null:
		boss.queue_free()
		return

	var frames := sprite.sprite_frames
	_runner.assert_eq(frames.get_frame_count(&"move"), 7, "boss move sheet is split into seven 200x160 frames")
	_runner.assert_eq(frames.get_frame_count(&"attack"), 7, "boss weak attack sheet is split into seven 200x160 frames")
	_runner.assert_eq(frames.get_frame_count(&"strong_attack"), 8, "boss strong attack sheet is split into eight 200x160 frames")
	_runner.assert_true(frames.get_animation_loop(&"move"), "boss movement loops")
	_runner.assert_false(frames.get_animation_loop(&"attack"), "boss weak attack does not loop")
	_runner.assert_false(frames.get_animation_loop(&"strong_attack"), "boss strong attack does not loop")

	var move_frame := frames.get_frame_texture(&"move", 6) as AtlasTexture
	var weak_frame := frames.get_frame_texture(&"attack", 6) as AtlasTexture
	var strong_frame := frames.get_frame_texture(&"strong_attack", 7) as AtlasTexture
	_runner.assert_not_null(move_frame, "boss final move frame uses atlas texture")
	_runner.assert_not_null(weak_frame, "boss final weak attack frame uses atlas texture")
	_runner.assert_not_null(strong_frame, "boss final strong attack frame uses atlas texture")
	if move_frame != null and move_frame.atlas != null:
		_runner.assert_eq(move_frame.atlas.get_width(), 1400, "boss move sheet width stays 1400px")
		_runner.assert_eq(move_frame.region, Rect2(1200, 0, 200, 160), "seventh move frame cuts the final 200px region")
	if weak_frame != null and weak_frame.atlas != null:
		_runner.assert_eq(weak_frame.atlas.get_width(), 1400, "boss weak attack sheet width stays 1400px")
		_runner.assert_eq(weak_frame.region, Rect2(1200, 0, 200, 160), "seventh weak attack frame cuts the final 200px region")
	if strong_frame != null and strong_frame.atlas != null:
		_runner.assert_eq(strong_frame.atlas.get_width(), 1600, "boss strong attack sheet width stays 1600px")
		_runner.assert_eq(strong_frame.region, Rect2(1400, 0, 200, 160), "eighth strong attack frame cuts the final 200px region")
	boss.queue_free()


func test_boss_patterns_play_asset_animations() -> void:
	var boss := (load(BOSS_SCENE_PATH) as PackedScene).instantiate()
	var target := Node2D.new()
	add_child(boss)
	add_child(target)
	boss.global_position = Vector2.ZERO
	target.global_position = Vector2.RIGHT * 100.0

	var sprite := boss.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "boss uses an AnimatedSprite2D visual")
	if sprite == null:
		boss.queue_free()
		target.queue_free()
		return

	boss.call("_begin_telegraph")
	boss.call("_begin_pattern", target)
	_runner.assert_eq(sprite.animation, &"strong_attack", "boss charge pattern plays the strong attack animation")

	boss.call("_begin_recover")
	_runner.assert_eq(sprite.animation, &"move", "boss recover phase returns to the move animation")

	boss.call("_begin_telegraph")
	boss.call("_begin_pattern", target)
	_runner.assert_eq(sprite.animation, &"attack", "boss burst pattern plays the weak attack animation")
	boss.queue_free()
	target.queue_free()
