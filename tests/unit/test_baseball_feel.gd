extends Node
## #15 야구공 손맛 — 반동/스핀 순수 함수 + 무기 정체성 단위 테스트.

const PlayerScript := preload("res://scripts/player/player.gd")
const BulletScene := preload("res://scenes/projectiles/purify_bullet.tscn")
const LauncherScript := preload("res://scripts/player/projectile_launcher.gd")
const BaseballFrames := preload("res://assets/sprites/player/player_baseball_frames.tres")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_recoil_kicks_opposite_to_aim() -> void:
	var p = PlayerScript.new()
	var r: Vector2 = p.recoil_velocity(Vector2.RIGHT, 50.0)
	_runner.assert_true(is_equal_approx(r.x, -50.0), "오른쪽 조준 → 왼쪽 반동")
	_runner.assert_true(is_equal_approx(r.y, 0.0), "수평 반동")
	p.free()


func test_recoil_zero_without_aim() -> void:
	var p = PlayerScript.new()
	var r: Vector2 = p.recoil_velocity(Vector2.ZERO, 50.0)
	_runner.assert_true(r == Vector2.ZERO, "조준 없으면 반동 없음")
	p.free()


func test_spin_advances_rotation() -> void:
	var b = BulletScene.instantiate()
	var rot: float = b.step_spin(0.0, 10.0, 0.5)
	_runner.assert_true(is_equal_approx(rot, 5.0), "스핀: rotation += spin*delta")
	b.free()


func test_weapon_identity_is_baseball() -> void:
	var l = LauncherScript.new()
	var info: Dictionary = l.weapon_info()
	_runner.assert_eq(info.get("name"), "낡은 야구공")
	_runner.assert_true(String(info.get("flavor")).length() > 0, "기억 플레이버 텍스트 존재")
	l.free()


func test_baseball_walk_frames_fit_updated_sprite_sheet() -> void:
	_runner.assert_eq(BaseballFrames.get_frame_count(&"walk"), 7, "야구부 걷기 시트는 7프레임")

	for index in range(BaseballFrames.get_frame_count(&"walk")):
		var frame_texture := BaseballFrames.get_frame_texture(&"walk", index) as AtlasTexture
		_runner.assert_not_null(frame_texture, "walk frame %d uses atlas texture" % index)
		if frame_texture == null:
			continue

		var atlas := frame_texture.atlas
		_runner.assert_not_null(atlas, "walk frame %d has atlas" % index)
		if atlas == null:
			continue

		_runner.assert_eq(atlas.get_width(), 896, "걷기 시트 폭은 7 * 128")
		_runner.assert_eq(atlas.get_height(), 128, "걷기 시트 높이는 128")
		_runner.assert_eq(frame_texture.region.size, Vector2(128, 128), "walk frame %d keeps 128px square" % index)
		_runner.assert_true(
			frame_texture.region.position.x + frame_texture.region.size.x <= float(atlas.get_width()),
			"walk frame %d stays inside updated sheet" % index
		)
