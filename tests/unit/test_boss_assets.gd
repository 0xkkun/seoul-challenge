extends Node

const BOSS_SCENE_PATH := "res://scenes/enemies/boss.tscn"
const BOSS_MOVE_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_move.png"
const BOSS_WEAK_ATTACK_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_weak_attack.png"
const BOSS_STRONG_ATTACK_SHEET_PATH := "res://assets/sprites/enemies/boss/boss_strong_attack.png"
const BOSS_GROUND_EFFECT_SHEET_PATH := "res://assets/effects/boss_ground_impact.png"
const BOSS_WOUND_EFFECT_SHEET_PATH := "res://assets/effects/boss_wound_slash.png"
const BOSS_GROUND_EFFECT_FRAMES_PATH := "res://assets/effects/boss_ground_impact_frames.tres"
const BOSS_WOUND_EFFECT_FRAMES_PATH := "res://assets/effects/boss_wound_slash_frames.tres"
const BOSS_MOVE_SHEET_SHA256 := "198e587280591db55a7fe5e98cfe43665dd71473461a60c9affce6047fed991f"
const BOSS_WEAK_ATTACK_SHEET_SHA256 := "31ec726d331e17a71c662bc4a54dd2c5b3fe7ea943c6b180b293cbea4a5a36dc"
const BOSS_STRONG_ATTACK_SHEET_SHA256 := "6d36f04ba30b8b2ded82840a27a758953002da07f50a12566a7eff0ca3a5d8f3"
const BOSS_GROUND_EFFECT_SHEET_SHA256 := "acd1a36fe4f3d0283cc2ccd10e4299c8cdf3551f55e45801945fa4a5512ba7d4"
const BOSS_WOUND_EFFECT_SHEET_SHA256 := "8deee71f9dd4eb3d3935ff9c4db387b123a5b1f576436ba52c03c124232bee2e"

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
	_runner.assert_eq(
		FileAccess.get_sha256(BOSS_GROUND_EFFECT_SHEET_PATH),
		BOSS_GROUND_EFFECT_SHEET_SHA256,
		"boss weak attack ground effect sheet matches the downloaded asset"
	)
	_runner.assert_eq(
		FileAccess.get_sha256(BOSS_WOUND_EFFECT_SHEET_PATH),
		BOSS_WOUND_EFFECT_SHEET_SHA256,
		"boss strong attack wound effect sheet matches the downloaded asset"
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


func test_boss_attack_effect_frames_use_download_sheet_dimensions() -> void:
	_assert_effect_frames(
		BOSS_GROUND_EFFECT_FRAMES_PATH,
		13,
		Vector2i(48, 18),
		Vector2i(624, 18),
		"boss weak attack ground effect"
	)
	_assert_effect_frames(
		BOSS_WOUND_EFFECT_FRAMES_PATH,
		13,
		Vector2i(192, 192),
		Vector2i(2496, 192),
		"boss strong attack wound effect"
	)


func test_boss_scene_mounts_attack_effect_nodes() -> void:
	var boss := (load(BOSS_SCENE_PATH) as PackedScene).instantiate()
	add_child(boss)
	var ground := boss.get_node_or_null("GroundImpactEffect") as AnimatedSprite2D
	var wound := boss.get_node_or_null("WoundSlashEffect") as AnimatedSprite2D
	_runner.assert_not_null(ground, "boss scene mounts weak attack ground effect")
	_runner.assert_not_null(wound, "boss scene mounts strong attack wound effect")
	if ground != null:
		_runner.assert_false(ground.visible, "ground effect starts hidden")
		_runner.assert_not_null(ground.sprite_frames, "ground effect has SpriteFrames")
		if ground.sprite_frames != null:
			_runner.assert_eq(ground.sprite_frames.resource_path, BOSS_GROUND_EFFECT_FRAMES_PATH, "ground effect uses the 13-frame download sheet")
	if wound != null:
		_runner.assert_false(wound.visible, "wound effect starts hidden")
		_runner.assert_not_null(wound.sprite_frames, "wound effect has SpriteFrames")
		if wound.sprite_frames != null:
			_runner.assert_eq(wound.sprite_frames.resource_path, BOSS_WOUND_EFFECT_FRAMES_PATH, "wound effect uses the 13-frame download sheet")
	boss.queue_free()


func test_boss_visual_is_scaled_up_for_final_encounter_presence() -> void:
	var boss := (load(BOSS_SCENE_PATH) as PackedScene).instantiate()
	add_child(boss)
	var sprite := boss.get_node_or_null("Sprite") as AnimatedSprite2D
	_runner.assert_not_null(sprite, "boss uses an AnimatedSprite2D visual")
	if sprite == null:
		boss.queue_free()
		return

	_runner.assert_eq(sprite.scale, Vector2(1.35, 1.35), "boss visual is 1.5x larger than the previous 0.9 scale")
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
	_runner.assert_eq(sprite.animation, &"attack", "boss weak attack pattern plays the weak attack animation")
	boss.queue_free()
	target.queue_free()


func _assert_effect_frames(frames_path: String, expected_count: int, frame_size: Vector2i, sheet_size: Vector2i, message: String) -> void:
	var frames := load(frames_path) as SpriteFrames
	_runner.assert_not_null(frames, "%s SpriteFrames resource loads" % message)
	if frames == null:
		return
	_runner.assert_true(frames.has_animation(&"impact"), "%s exposes an impact animation" % message)
	_runner.assert_eq(frames.get_frame_count(&"impact"), expected_count, "%s keeps the downloaded 13-frame sequence" % message)
	_runner.assert_false(frames.get_animation_loop(&"impact"), "%s impact animation does not loop" % message)
	for i in range(expected_count):
		var frame := frames.get_frame_texture(&"impact", i) as AtlasTexture
		_runner.assert_not_null(frame, "%s frame %d uses an atlas texture" % [message, i])
		if frame != null and frame.atlas != null:
			_runner.assert_eq(frame.atlas.get_width(), sheet_size.x, "%s sheet width is preserved" % message)
			_runner.assert_eq(frame.atlas.get_height(), sheet_size.y, "%s sheet height is preserved" % message)
			_runner.assert_eq(frame.region, Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y), "%s frame %d cuts the expected region" % [message, i])
