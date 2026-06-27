extends Node

const DEATH_FX_SCRIPT_PATH := "res://scripts/combat/enemy_death_fade.gd"
const DEATH_SHEET_PATH := "res://assets/effects/enemy_death.png"
const DEATH_FRAME_SIZE := 64
const DEATH_FRAME_COUNT := 12
const DEATH_SHEET_SHA256 := "805d13e833a13ac3c3ca2f8f880cab2efc5d408039160ccbfa894efbde4469b3"
const ChaserScene := preload("res://scenes/enemies/chaser.tscn")
const RangedShooterScene := preload("res://scenes/enemies/ranged_shooter.tscn")
const BossScene := preload("res://scenes/enemies/boss.tscn")
const WolfScene := preload("res://scenes/enemies/wolf.tscn")
const EnemyDeathFade := preload("res://scripts/combat/enemy_death_fade.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_enemy_death_sheet_uses_twelve_64px_frames() -> void:
	_runner.assert_true(ResourceLoader.exists(DEATH_SHEET_PATH), "사망 PNG 에셋이 프로젝트에 포함된다")
	if not ResourceLoader.exists(DEATH_SHEET_PATH):
		return
	var texture := load(DEATH_SHEET_PATH) as Texture2D
	_runner.assert_not_null(texture, "사망 PNG를 텍스처로 읽을 수 있다")
	if texture == null:
		return
	_runner.assert_eq(texture.get_width(), DEATH_FRAME_SIZE * DEATH_FRAME_COUNT, "사망 PNG는 64px 12프레임 가로 시트다")
	_runner.assert_eq(texture.get_height(), DEATH_FRAME_SIZE, "사망 PNG 프레임 높이는 64px다")
	_runner.assert_eq(FileAccess.get_sha256(DEATH_SHEET_PATH), DEATH_SHEET_SHA256, "사망 PNG는 다운로드 폴더의 최신 에셋과 일치한다")


func test_enemy_death_fade_contract_exists() -> void:
	_runner.assert_true(ResourceLoader.exists(DEATH_FX_SCRIPT_PATH), "공용 몬스터 사망 페이드 스크립트가 존재한다")
	if not ResourceLoader.exists(DEATH_FX_SCRIPT_PATH):
		return

	var script := load(DEATH_FX_SCRIPT_PATH) as Script
	var fade: Node = script.new() as Node
	add_child(fade)
	_runner.assert_true(fade.has_method("get_visual_contract"), "사망 페이드는 테스트 가능한 시각 계약을 노출한다")
	if fade.has_method("get_visual_contract"):
		var contract: Dictionary = fade.call("get_visual_contract")
		_runner.assert_eq(contract.get("group"), &"enemy_death_fx", "사망 페이드는 검색 가능한 그룹을 가진다")
		_runner.assert_eq(contract.get("draw_style"), &"sprite_sheet_animation", "사망 페이드는 전용 스프라이트 시트 애니메이션을 쓴다")
		_runner.assert_eq(int(contract.get("frame_count", 0)), DEATH_FRAME_COUNT, "사망 페이드는 사망 PNG 12프레임을 모두 쓴다")
		_runner.assert_eq(int(contract.get("frame_size", 0)), DEATH_FRAME_SIZE, "사망 페이드 프레임 크기는 64px다")
		_runner.assert_true(float(contract.get("lifetime", 0.0)) >= 0.45, "사망 페이드는 애니메이션이 보일 만큼 남는다")
		_runner.assert_true(float(contract.get("lifetime", 1.0)) <= 0.8, "사망 페이드는 전투 흐름을 오래 막지 않는다")
		_runner.assert_eq(int(contract.get("shard_count", -1)), 0, "사망 페이드는 파편을 만들지 않는다")
		_runner.assert_eq(bool(contract.get("uses_line_art", true)), false, "사망 페이드는 링/선 이펙트를 쓰지 않는다")
		_runner.assert_eq(bool(contract.get("animates_scale", true)), false, "사망 페이드는 크기를 부풀리지 않는다")
		_runner.assert_eq(bool(contract.get("captures_visual", false)), true, "사망 페이드는 몬스터 visual을 잠깐 유지한다")
		_runner.assert_eq(bool(contract.get("squashes_captured_visual", true)), false, "사망 페이드는 몬스터 visual을 Y축으로 찌부시키지 않는다")
		_runner.assert_eq(bool(contract.get("preserves_captured_visual_scale", false)), true, "사망 페이드는 몬스터 visual 원본 비율을 유지한다")
		_runner.assert_true(float(contract.get("captured_visual_lift_pixels", 0.0)) >= 20.0, "사망 잔상은 짧게 위로 떠오른다")
		_runner.assert_eq(bool(contract.get("uses_white_flash", true)), false, "사망 페이드는 흰색 플래시를 쓰지 않는다")
	fade.queue_free()


func test_chaser_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(ChaserScene.instantiate(), "chaser")


func test_ranged_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(RangedShooterScene.instantiate(), "ranged")


func test_boss_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(BossScene.instantiate(), "boss")


func test_wolf_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(WolfScene.instantiate(), "wolf")


func test_death_fade_plays_dedicated_death_animation() -> void:
	var fade := _new_death_fade()
	add_child(fade)
	var animation := _find_death_animation(fade)
	_runner.assert_not_null(animation, "사망 페이드는 전용 AnimatedSprite2D를 가진다")
	if animation != null:
		_runner.assert_eq(animation.name, "DeathAnimation", "사망 애니메이션 노드 이름은 안정적이다")
		_runner.assert_eq(animation.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "사망 애니메이션은 픽셀 아트를 깨뜨리지 않는다")
		_runner.assert_eq(animation.animation, &"death", "사망 애니메이션을 재생한다")
		_runner.assert_true(animation.is_playing(), "사망 애니메이션은 생성 즉시 재생된다")
		_runner.assert_eq(animation.sprite_frames.get_frame_count(&"death"), DEATH_FRAME_COUNT, "사망 애니메이션은 12프레임을 모두 쓴다")
		_runner.assert_true(animation.position.is_equal_approx(Vector2(0.0, -DEATH_FRAME_SIZE * 0.5)), "사망 애니메이션 하단이 발 위치에 맞는다")
	fade.free()


func test_death_fade_captures_monster_visual_and_preserves_scale_from_feet() -> void:
	var fade := _new_death_fade()
	add_child(fade)
	fade.global_position = Vector2(100.0, 200.0)
	var source := Polygon2D.new()
	source.name = "SourceMonster"
	source.polygon = PackedVector2Array([
		Vector2(-10.0, -40.0),
		Vector2(10.0, -40.0),
		Vector2(10.0, 0.0),
		Vector2(-10.0, 0.0),
	])
	source.color = Color(0.8, 0.2, 0.4, 1.0)
	source.global_position = fade.global_position
	add_child(source)

	fade.call("capture_visual", source)

	var ghost := _find_captured_monster_ghost(fade)
	_runner.assert_not_null(ghost, "사망 페이드는 원본 몬스터 visual을 복제한 잔상 루트를 가진다")
	if ghost == null:
		source.queue_free()
		fade.queue_free()
		return
	_runner.assert_eq(ghost.name, "CapturedMonsterGhost", "잔상 visual 루트 이름은 안정적이다")
	_runner.assert_true(ghost.scale.is_equal_approx(Vector2.ONE), "잔상 visual은 원본 크기로 시작한다")
	_runner.assert_true(ghost.get_child_count() > 0, "잔상 visual은 복제된 몬스터 visual을 포함한다")
	var clone := ghost.get_child(0) as Polygon2D
	_runner.assert_not_null(clone, "Polygon2D 몬스터 visual도 복제할 수 있다")
	if clone != null:
		_runner.assert_true(clone != source, "잔상 visual은 곧 사라질 원본 노드를 직접 쓰지 않는다")
		_runner.assert_true(EnemyDeathFade.foot_position_for(fade, clone).is_equal_approx(fade.global_position), "복제 visual의 발은 사망 이펙트 기준점에 고정된다")

	fade.call("_process", 0.24)

	_runner.assert_true(ghost.scale.is_equal_approx(Vector2.ONE), "잔상 visual은 사망 중에도 원본 비율을 유지한다")
	_runner.assert_true(ghost.position.y < 0.0, "잔상 visual은 찌부 대신 짧게 위로 떠오른다")
	_runner.assert_true(ghost.modulate.a < 1.0, "잔상 visual은 사망 이펙트와 함께 사라진다")
	source.queue_free()
	fade.queue_free()


func test_death_fade_preserves_captured_animated_sprite_frame() -> void:
	var fade := _new_death_fade()
	add_child(fade)
	fade.global_position = Vector2(32.0, 96.0)
	var source := AnimatedSprite2D.new()
	source.name = "SourceAnimatedMonster"
	source.sprite_frames = _new_test_sprite_frames()
	source.animation = &"move"
	source.centered = true
	source.global_position = fade.global_position - Vector2(0.0, 32.0)
	add_child(source)
	source.play(&"move")
	source.set_frame_and_progress(1, 0.45)

	fade.call("capture_visual", source)

	var ghost := _find_captured_monster_ghost(fade)
	_runner.assert_not_null(ghost, "AnimatedSprite2D visual도 사망 순간 복제본을 가진다")
	if ghost == null:
		source.queue_free()
		fade.queue_free()
		return
	var clone := ghost.get_child(0) as AnimatedSprite2D
	_runner.assert_not_null(clone, "AnimatedSprite2D 몬스터 visual을 복제한다")
	if clone != null:
		_runner.assert_eq(clone.animation, &"move", "복제 visual은 원본 애니메이션을 유지한다")
		_runner.assert_eq(clone.frame, 1, "복제 visual은 사망 순간 프레임을 유지한다")
		_runner.assert_true(is_equal_approx(clone.frame_progress, 0.45), "복제 visual은 사망 순간 프레임 진행도를 유지한다")
		_runner.assert_false(clone.is_playing(), "복제 visual은 사망 후 애니메이션을 이어 재생하지 않는다")
	source.queue_free()
	fade.queue_free()


func test_death_fade_uses_attack_pose_instead_of_looping_walk_when_available() -> void:
	var fade := _new_death_fade()
	add_child(fade)
	fade.global_position = Vector2(32.0, 96.0)
	var source := AnimatedSprite2D.new()
	source.name = "SourceAnimatedMonster"
	source.sprite_frames = _new_test_sprite_frames_with_attack()
	source.animation = &"move"
	source.centered = true
	source.global_position = fade.global_position - Vector2(0.0, 32.0)
	add_child(source)
	source.play(&"move")
	source.set_frame_and_progress(1, 0.45)

	fade.call("capture_visual", source)

	var ghost := _find_captured_monster_ghost(fade)
	_runner.assert_not_null(ghost, "공격 포즈 잔상 visual 루트를 가진다")
	if ghost == null:
		source.queue_free()
		fade.queue_free()
		return
	var clone := ghost.get_child(0) as AnimatedSprite2D
	_runner.assert_not_null(clone, "AnimatedSprite2D 몬스터 visual을 복제한다")
	if clone != null:
		_runner.assert_eq(clone.animation, &"attack", "이동 중 죽어도 걷기 루프 대신 공격 포즈로 멈춘다")
		_runner.assert_eq(clone.frame, 1, "공격 포즈는 마지막 공격 프레임을 사용한다")
		_runner.assert_true(is_equal_approx(clone.frame_progress, 0.0), "공격 포즈는 루프 진행도를 이어받지 않는다")
		_runner.assert_false(clone.is_playing(), "복제 visual은 사망 후 애니메이션을 이어 재생하지 않는다")
	source.queue_free()
	fade.queue_free()


func test_death_fade_keeps_effect_scale_stable_until_lifetime_expires() -> void:
	var fade := _new_death_fade()
	add_child(fade)
	var before_scale := fade.scale
	var before_alpha := fade.modulate.a
	fade.call("_process", 0.12)
	_runner.assert_true(fade.scale.is_equal_approx(before_scale), "사망 페이드는 재생 중 크기를 부풀리지 않는다")
	_runner.assert_true(is_equal_approx(fade.modulate.a, before_alpha), "사망 PNG 자체 알파를 쓰고 루트 투명도 페이드는 쓰지 않는다")
	fade.free()


func _assert_enemy_death_spawns_fade(enemy: Node2D, label: String) -> void:
	_clear_death_fades()
	enemy.set("max_hp", 1)
	add_child(enemy)
	enemy.global_position = Vector2(123.0, 77.0)
	var defeated := {"count": 0}
	enemy.connect("defeated", func(_node): defeated["count"] += 1)

	enemy.call("take_damage", 1)

	_runner.assert_eq(defeated["count"], 1, "%s death still emits defeated immediately" % label)
	var fade := _find_death_fade()
	_runner.assert_not_null(fade, "%s death leaves a detached fade sibling" % label)
	if fade == null:
		return
	_runner.assert_true(fade != enemy, "%s death fade is not the enemy node being freed" % label)
	_runner.assert_eq(fade.name, "EnemyDeathFade", "%s death fade has a stable node name" % label)
	_runner.assert_true(fade.is_in_group(&"enemy_death_fx"), "%s death fade is searchable by group" % label)
	_runner.assert_true(fade.global_position.is_equal_approx(_expected_enemy_foot_position(enemy)), "%s death fade starts at the enemy feet" % label)
	_runner.assert_true(fade.z_index >= 40, "%s death fade draws above room actors briefly" % label)
	_runner.assert_true(_has_death_animation(fade), "%s death fade plays the shared death animation" % label)
	_runner.assert_not_null(_find_captured_monster_ghost(fade), "%s death fade keeps a scale-preserving monster ghost" % label)
	_runner.assert_eq(_count_line_nodes(fade), 0, "%s death fade does not draw rings or shards" % label)
	var before_scale := fade.scale
	var before_alpha := fade.modulate.a
	fade.call("_process", 0.12)
	_runner.assert_true(fade.scale.is_equal_approx(before_scale), "%s death fade keeps scale stable" % label)
	_runner.assert_true(is_equal_approx(fade.modulate.a, before_alpha), "%s death fade does not add a root opacity fade over the PNG" % label)
	_clear_death_fades()


func _find_death_fade() -> Node2D:
	for child in get_children():
		if child is Node2D and child.is_in_group(&"enemy_death_fx"):
			return child
	return null


func _clear_death_fades() -> void:
	for child in get_children():
		if child is Node and child.is_in_group(&"enemy_death_fx"):
			remove_child(child)
			child.free()


func _has_death_animation(root: Node) -> bool:
	return _find_death_animation(root) != null


func _find_death_animation(root: Node) -> AnimatedSprite2D:
	for child in root.get_children():
		if child is AnimatedSprite2D and child.name == "DeathAnimation":
			return child
	return null


func _find_captured_monster_ghost(root: Node) -> Node2D:
	for child in root.get_children():
		if child is Node2D and child.name == "CapturedMonsterGhost":
			return child
	return null


func _new_test_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	frames.add_animation(&"move")
	var texture := load(DEATH_SHEET_PATH) as Texture2D
	frames.add_frame(&"move", texture)
	frames.add_frame(&"move", texture)
	return frames


func _new_test_sprite_frames_with_attack() -> SpriteFrames:
	var frames := _new_test_sprite_frames()
	var texture := load(DEATH_SHEET_PATH) as Texture2D
	frames.add_animation(&"attack")
	frames.add_frame(&"attack", texture)
	frames.add_frame(&"attack", texture)
	frames.set_animation_loop(&"attack", false)
	return frames


func _new_death_fade() -> Node2D:
	var script := load(DEATH_FX_SCRIPT_PATH) as Script
	return script.new() as Node2D


func _expected_enemy_foot_position(enemy: Node2D) -> Vector2:
	var visual := enemy.get_node_or_null(^"Sprite") as AnimatedSprite2D
	if visual != null and visual.sprite_frames != null and visual.sprite_frames.has_animation(visual.animation):
		var frame_texture := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
		if frame_texture != null:
			var bottom_y: float = frame_texture.get_height() * 0.5 if visual.centered else frame_texture.get_height()
			return visual.to_global(Vector2(0.0, bottom_y))
	var placeholder := enemy.get_node_or_null(^"Placeholder") as Polygon2D
	if placeholder != null and not placeholder.polygon.is_empty():
		var max_y := placeholder.polygon[0].y
		for point: Vector2 in placeholder.polygon:
			max_y = maxf(max_y, point.y)
		return placeholder.to_global(Vector2(0.0, max_y))
	return enemy.global_position


func _count_line_nodes(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is Line2D:
			count += 1
		count += _count_line_nodes(child)
	return count
