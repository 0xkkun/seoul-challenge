extends Node
## 플레이어 근접 공격 — 부채꼴 판정(순수) + 실제 타격 단위 테스트.
## (기본 공격을 원거리→근접으로 변경. 원거리는 ranged_enabled 로 보존.)

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


class StubEnemy extends Node2D:
	var taken: int = 0
	func take_damage(amount: int) -> void:
		taken += amount


class StubBullet extends Node2D:
	var deflect_count: int = 0
	var deflected_dir: Vector2 = Vector2.ZERO
	func deflect(direction: Vector2) -> void:
		deflect_count += 1
		deflected_dir = direction


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_in_melee_arc_front_is_hit() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.in_melee_arc(Vector2.RIGHT, Vector2(10.0, 0.0), 1.6), "정면은 부채꼴 안")
	p.free()


func test_in_melee_arc_back_is_miss() -> void:
	var p = PlayerScript.new()
	_runner.assert_false(p.in_melee_arc(Vector2.RIGHT, Vector2(-10.0, 0.0), 1.6), "뒤는 부채꼴 밖")
	_runner.assert_false(p.in_melee_arc(Vector2.RIGHT, Vector2(0.0, -10.0), 1.6), "90도는 부채꼴 밖")
	p.free()


func test_melee_hits_enemy_in_front() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, 1, "정면 사거리 안 적이 피해를 받음")
	e.free()
	p.free()


func test_dash_power_attack_hits_farther_and_deals_bonus_damage() -> void:
	var p = PlayerScript.new()
	add_child(p)
	_runner.assert_true(_has_property(p, "dash_power_attack_damage_bonus"), "player exposes dash power damage bonus")
	_runner.assert_true(p.has_method("get_dash_power_attack_remaining"), "player exposes dash power window state")
	if not _has_property(p, "dash_power_attack_damage_bonus") or not p.has_method("get_dash_power_attack_remaining"):
		p.free()
		return
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(38.0, 0.0)  # regular melee_range(34) misses, dash power range reaches
	e.add_to_group(&"enemy")
	add_child(e)
	p.try_start_special_skill(Vector2.RIGHT)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(e.taken, p.melee_damage + p.dash_power_attack_damage_bonus, "dash power attack deals bonus damage")
	_runner.assert_true(is_equal_approx(p.get_dash_power_attack_remaining(), 0.0), "power attack consumes the window")
	e.free()
	p.free()


func test_player_collision_radius_stays_inside_melee_range() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var collision := player.get_node("Collision") as CollisionShape2D
	var shape := collision.shape as CircleShape2D

	_runner.assert_not_null(shape, "player collision uses a circle shape")
	if shape != null:
		_runner.assert_true(
			shape.radius <= player.melee_range,
			"melee-only player can move close enough to hit enemy centers"
		)


func test_melee_misses_enemy_behind() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(-25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, 0, "뒤의 적은 안 맞음")
	e.free()
	p.free()


func test_bat_deflects_enemy_projectile_in_arc() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var b := StubBullet.new()
	b.position = Vector2(40.0, 0.0)  # 정면, bat_range(56) 안
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 1, "배트 부채꼴 안 적탄을 되받아침")
	_runner.assert_eq(b.deflected_dir, Vector2.RIGHT, "스윙 방향으로 되받아침")
	b.free()
	p.free()


func test_bat_does_not_deflect_projectile_behind() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var b := StubBullet.new()
	b.position = Vector2(-40.0, 0.0)  # 뒤
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "뒤의 적탄은 안 튕김")
	b.free()
	p.free()


func test_bare_hands_do_not_deflect_projectiles() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var b := StubBullet.new()
	b.position = Vector2(20.0, 0.0)  # 정면, melee_range(34) 안이지만 배트 없음
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "맨손은 적탄을 못 튕김(배트 전용)")
	b.free()
	p.free()


func test_enemy_bullet_deflect_retargets_to_enemy_layer() -> void:
	var bullet := (load("res://scenes/enemies/enemy_bullet.tscn") as PackedScene).instantiate()
	add_child(bullet)
	bullet.launch(Vector2.ZERO, Vector2.LEFT)
	_runner.assert_true(bullet.is_in_group(&"enemy_projectile"), "발사 시 적탄 그룹")
	_runner.assert_eq(bullet.collision_mask, 2, "발사 시 플레이어(레이어2) 타격")
	bullet.deflect(Vector2.RIGHT)
	_runner.assert_eq(bullet.collision_mask, 1, "deflect 후 적(레이어1) 타격으로 전환")
	_runner.assert_false(bullet.is_in_group(&"enemy_projectile"), "deflect 후 적탄 그룹에서 빠짐")
	_runner.assert_eq(bullet.damage, bullet.deflect_damage, "deflect 후 반사 피해로 전환")
	bullet.free()


func test_bat_dash_power_attack_knocks_back_farther_than_normal_bat() -> void:
	var normal_player = PlayerScript.new()
	add_child(normal_player)
	normal_player.position = Vector2.ZERO
	normal_player.equip_bat()
	var normal_enemy := StubEnemy.new()
	normal_enemy.position = Vector2(50.0, 0.0)
	normal_enemy.add_to_group(&"enemy")
	add_child(normal_enemy)
	normal_player._attack_melee(Vector2.RIGHT)
	var normal_knockback_x := normal_enemy.position.x
	normal_enemy.free()
	normal_player.free()

	var power_player = PlayerScript.new()
	add_child(power_player)
	power_player.position = Vector2.ZERO
	power_player.equip_bat()
	var power_enemy := StubEnemy.new()
	power_enemy.position = Vector2(50.0, 0.0)
	power_enemy.add_to_group(&"enemy")
	add_child(power_enemy)
	power_player.try_start_special_skill(Vector2.RIGHT)
	power_player._attack_melee(Vector2.RIGHT)

	_runner.assert_true(power_enemy.position.x > normal_knockback_x, "dash power bat attack applies stronger knockback")
	power_enemy.free()
	power_player.free()


func test_player_scene_includes_hidden_power_impact_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("PowerImpact") as Polygon2D

	_runner.assert_not_null(impact, "player scene includes dash power impact effect")
	if impact != null:
		_runner.assert_false(impact.visible, "power impact starts hidden")
		_runner.assert_true(impact.color.a > 0.5, "power impact is brighter than the regular swing")


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
