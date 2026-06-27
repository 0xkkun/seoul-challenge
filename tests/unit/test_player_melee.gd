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


func test_barehand_reach_is_forgiving_for_mobile_combat() -> void:
	var p = PlayerScript.new()
	_runner.assert_true(p.melee_range >= 44.0, "맨손 기본 사거리는 모바일에서 헛손질이 잦지 않게 넉넉해야 한다")
	p.free()


func test_barehand_hit_applies_small_knockback() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(30.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)

	p._attack_melee(Vector2.RIGHT)

	_runner.assert_true(e.position.x > 30.0, "맨손도 적을 살짝 밀어내 타격 반응을 만든다")
	e.free()
	p.free()


func test_melee_hit_emits_combat_feedback() -> void:
	_runner.assert_true(EventBus.has_signal("combat_feedback"), "전투 피드백 이벤트 표면이 존재한다")
	_runner.assert_true(EventBus.has_method("emit_combat_feedback"), "전투 피드백은 payload wrapper 로 발신한다")
	if not EventBus.has_signal("combat_feedback") or not EventBus.has_method("emit_combat_feedback"):
		return

	var payloads: Array[Dictionary] = []
	var callback := func(payload: Dictionary) -> void:
		payloads.append(payload)
	EventBus.combat_feedback.connect(callback)

	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(25.0, 0.0)
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)

	_runner.assert_eq(payloads.size(), 1, "근접 타격은 전투 피드백 이벤트를 1회 낸다")
	if payloads.size() == 1:
		_runner.assert_eq(payloads[0].get("kind", &""), &"melee_hit", "피드백 종류는 근접 히트")
		_runner.assert_true(float(payloads[0].get("intensity", 0.0)) > 0.0, "카메라/이펙트가 쓸 intensity 를 포함한다")

	EventBus.combat_feedback.disconnect(callback)
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


func test_dash_power_attack_is_consumed_even_while_dodge_remains_active() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.try_start_special_skill(Vector2.RIGHT)
	var first_enemy := StubEnemy.new()
	first_enemy.position = Vector2(25.0, 0.0)
	first_enemy.add_to_group(&"enemy")
	add_child(first_enemy)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(first_enemy.taken, p.melee_damage + p.dash_power_attack_damage_bonus, "first dash attack is powered")
	first_enemy.free()

	var second_enemy := StubEnemy.new()
	second_enemy.position = Vector2(25.0, 0.0)
	second_enemy.add_to_group(&"enemy")
	add_child(second_enemy)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(second_enemy.taken, p.melee_damage, "second attack in the same dodge is not powered")
	second_enemy.free()
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
	p.set_bat_awakened(true)
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
	p.set_bat_awakened(true)
	var b := StubBullet.new()
	b.position = Vector2(-40.0, 0.0)  # 뒤
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "뒤의 적탄은 안 튕김")
	b.free()
	p.free()


func test_unawakened_bat_clears_enemy_projectile_without_deflecting() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	p.set_bat_awakened(false)
	var b := StubBullet.new()
	b.position = Vector2(40.0, 0.0)
	b.add_to_group(&"enemy_projectile")
	add_child(b)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(b.deflect_count, 0, "미각성 배트는 적탄을 되받아치지 않는다")
	_runner.assert_true(b.is_queued_for_deletion(), "미각성 배트는 방어 보상으로 적탄만 제거한다")
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


func test_player_scene_includes_hidden_bat_swing_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("BatSwingImpact") as Node2D

	_runner.assert_not_null(impact, "player scene includes bat swing slash effect root")
	if impact != null:
		_runner.assert_false(impact.visible, "bat swing effect starts hidden")
		var slash_back := impact.get_node_or_null("BatSlashBack") as Line2D
		var slash_front := impact.get_node_or_null("BatSlashFront") as Line2D
		var slash_echo := impact.get_node_or_null("BatSlashEcho") as Line2D
		_runner.assert_not_null(slash_back, "bat swing has a broad blue trail")
		_runner.assert_not_null(slash_front, "bat swing has a bright crescent edge")
		_runner.assert_not_null(slash_echo, "bat swing has a trailing afterimage")


func test_bat_swing_show_builds_reference_style_crescent_arc() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("BatSwingImpact") as Node2D
	_runner.assert_not_null(impact, "player scene includes bat swing effect root")
	if impact == null:
		return

	player._show_bat_swing_effect(Vector2.RIGHT, 100.0, 2.2)

	var slash_front := impact.get_node_or_null("BatSlashFront") as Line2D
	var slash_echo := impact.get_node_or_null("BatSlashEcho") as Line2D
	_runner.assert_true(impact.visible, "showing bat swing reveals the effect root")
	_runner.assert_not_null(slash_front, "bat swing uses a bright crescent stroke")
	_runner.assert_not_null(slash_echo, "bat swing uses a fading afterimage")
	if slash_front != null:
		_runner.assert_true(slash_front.points.size() >= 12, "bat slash is a curved crescent")
		_runner.assert_true(slash_front.width >= 7.0, "bat slash is thick enough to read on mobile")
	if slash_echo != null:
		_runner.assert_true(slash_echo.points.size() >= 8, "bat echo is also curved")
	if slash_front != null and slash_echo != null:
		_runner.assert_true(slash_echo.default_color.a < slash_front.default_color.a, "bat echo reads as a trailing afterimage")


func test_bat_attack_hides_debug_like_melee_range_wedge() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	player.equip_bat()

	player._attack_melee(Vector2.RIGHT)

	var melee_swing := player.get_node_or_null("MeleeSwing") as CanvasItem
	var bat_swing := player.get_node_or_null("BatSwingImpact") as CanvasItem
	_runner.assert_not_null(melee_swing, "player keeps melee swing node for bare hands")
	_runner.assert_not_null(bat_swing, "player keeps bat swing effect node")
	if melee_swing != null:
		_runner.assert_false(melee_swing.visible, "bat attack does not show the white range wedge")
	if bat_swing != null:
		_runner.assert_true(bat_swing.visible, "bat attack still shows the authored slash effect")


func test_player_scene_includes_layered_power_impact_effect() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("PowerImpact") as Node2D

	_runner.assert_not_null(impact, "player scene includes dash power impact effect root")
	if impact != null:
		_runner.assert_false(impact.visible, "power impact starts hidden")
		_runner.assert_false(impact is Polygon2D, "power impact is not a single recolored wedge")
		var slash_back := impact.get_node_or_null("ImpactSlashBack") as Line2D
		var slash_front := impact.get_node_or_null("ImpactSlashFront") as Line2D
		var ring := impact.get_node_or_null("ImpactRing") as Line2D
		var sparks := impact.get_node_or_null("ImpactSparks") as Node2D
		_runner.assert_not_null(slash_back, "power impact has a broad slash trail")
		_runner.assert_not_null(slash_front, "power impact has a bright slash edge")
		_runner.assert_not_null(ring, "power impact has an expanding impact ring")
		_runner.assert_not_null(sparks, "power impact has spark children")
		if sparks != null:
			_runner.assert_true(sparks.get_child_count() >= 5, "power impact has multiple spark strokes")


func test_power_impact_show_builds_slash_ring_and_spark_geometry() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	var impact := player.get_node_or_null("PowerImpact") as Node2D
	_runner.assert_not_null(impact, "player scene includes power impact root")
	if impact == null:
		return

	player._show_power_impact(Vector2.RIGHT, 80.0, 1.6)

	var slash_front := impact.get_node_or_null("ImpactSlashFront") as Line2D
	var ring := impact.get_node_or_null("ImpactRing") as Line2D
	var sparks := impact.get_node_or_null("ImpactSparks") as Node2D
	_runner.assert_true(impact.visible, "showing a power impact reveals the effect root")
	_runner.assert_not_null(slash_front, "showing a power impact uses a slash stroke")
	_runner.assert_not_null(ring, "showing a power impact uses an impact ring")
	_runner.assert_not_null(sparks, "showing a power impact uses sparks")
	if slash_front != null:
		_runner.assert_true(slash_front.points.size() >= 10, "slash stroke is an arc, not a static triangle")
	if ring != null:
		_runner.assert_true(ring.points.size() >= 16, "impact ring is a multi-point expanding shape")
	if sparks != null and sparks.get_child_count() > 0:
		var spark := sparks.get_child(0) as Line2D
		_runner.assert_not_null(spark, "spark child is a line stroke")
		if spark != null:
			_runner.assert_eq(spark.points.size(), 2, "spark stroke has start and end points")
			_runner.assert_true(spark.points[1].length() > spark.points[0].length(), "spark shoots outward from impact center")


func test_power_slash_points_follow_attack_arc() -> void:
	var player = PlayerScript.new()
	_runner.assert_true(player.has_method("build_power_slash_points"), "player exposes pure slash geometry helper")
	if not player.has_method("build_power_slash_points"):
		player.free()
		return
	var points: PackedVector2Array = player.build_power_slash_points(Vector2.RIGHT, 80.0, 1.4, 0.86, 1.02, 8)
	_runner.assert_eq(points.size(), 9, "segments create inclusive arc points")
	_runner.assert_true(points[0].x > 0.0 and points[points.size() - 1].x > 0.0, "slash points stay in front of the player")
	_runner.assert_true(absf(points[0].y) > absf(points[4].y), "slash starts at the upper arc edge and crosses the center")
	player.free()


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
