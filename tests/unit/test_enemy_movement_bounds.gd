extends Node

const AKGWI_SCENE := preload("res://scenes/enemies/akgwi.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/boss.tscn")
const KUMIHO_SCENE := preload("res://scenes/enemies/kumiho.tscn")
const MovementBounds := preload("res://scripts/systems/movement_bounds.gd")
const RANGED_SHOOTER_SCENE := preload("res://scenes/enemies/ranged_shooter.tscn")
const WOLF_SCENE := preload("res://scenes/enemies/wolf.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_movement_bounds_helper_insets_position_by_collision_shape() -> void:
	var body := CharacterBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var bounds := Rect2(Vector2(0.0, -100.0), Vector2(100.0, 200.0))

	var position_bounds: Rect2 = MovementBounds.body_position_bounds(bounds, body)
	var clamped: Vector2 = MovementBounds.clamp_body_position_to_bounds(Vector2(500.0, 0.0), bounds, body)

	_runner.assert_eq(position_bounds.position, Vector2(12.0, -88.0), "collision radius insets the minimum allowed origin")
	_runner.assert_eq(position_bounds.end, Vector2(88.0, 88.0), "collision radius insets the maximum allowed origin")
	_runner.assert_eq(clamped, Vector2(88.0, 0.0), "body clamp keeps the whole circle inside the raw bounds")
	body.free()


func test_enemy_movement_bounds_keep_collision_body_inside_room_bounds() -> void:
	var cases := [
		{"label": "akgwi", "scene": AKGWI_SCENE},
		{"label": "ranged shooter", "scene": RANGED_SHOOTER_SCENE},
		{"label": "kumiho", "scene": KUMIHO_SCENE},
		{"label": "wolf", "scene": WOLF_SCENE},
	]
	var bounds := Rect2(Vector2(0.0, -100.0), Vector2(100.0, 200.0))
	var outside_positions := [
		Vector2(180.0, 0.0),
		Vector2(-80.0, 0.0),
		Vector2(50.0, -180.0),
		Vector2(50.0, 180.0),
	]

	for entry: Dictionary in cases:
		var enemy := (entry["scene"] as PackedScene).instantiate() as Node2D
		add_child(enemy)
		_runner.assert_true(enemy.has_method("set_movement_bounds"), "%s exposes movement bounds setup" % entry["label"])
		_runner.assert_true(enemy.has_method("clamp_to_movement_bounds"), "%s exposes movement bounds clamp" % entry["label"])
		if not enemy.has_method("set_movement_bounds") or not enemy.has_method("clamp_to_movement_bounds"):
			enemy.free()
			continue

		enemy.call("set_movement_bounds", bounds)
		for outside_position: Vector2 in outside_positions:
			enemy.global_position = outside_position
			enemy.call("clamp_to_movement_bounds")
			_assert_collision_body_inside_bounds(enemy, bounds, "%s at %s" % [entry["label"], outside_position])
		enemy.free()


func test_boss_uses_same_movement_bounds_contract_as_other_enemies() -> void:
	var boss := BOSS_SCENE.instantiate() as Node2D
	add_child(boss)
	var bounds := Rect2(Vector2(-120.0, -80.0), Vector2(240.0, 160.0))

	_runner.assert_true(boss.has_method("set_movement_bounds"), "boss exposes movement bounds setup")
	_runner.assert_true(boss.has_method("clamp_to_movement_bounds"), "boss exposes movement bounds clamp")
	if not boss.has_method("set_movement_bounds") or not boss.has_method("clamp_to_movement_bounds"):
		boss.free()
		return

	boss.global_position = Vector2(200.0, 0.0)
	boss.call("set_movement_bounds", bounds)
	_assert_collision_body_inside_bounds(boss, bounds, "boss after right-edge clamp")
	boss.free()


func _assert_collision_body_inside_bounds(body: Node2D, bounds: Rect2, label: String) -> void:
	var local_rect := _collision_local_rect(body)
	_runner.assert_true(local_rect.size.x > 0.0 and local_rect.size.y > 0.0, "%s has a measurable collision body" % label)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return
	var body_rect := Rect2(body.global_position + local_rect.position, local_rect.size)
	_runner.assert_true(body_rect.position.x >= bounds.position.x, "%s left collision edge stays inside room bounds" % label)
	_runner.assert_true(body_rect.end.x <= bounds.end.x, "%s right collision edge stays inside room bounds" % label)
	_runner.assert_true(body_rect.position.y >= bounds.position.y, "%s top collision edge stays inside room bounds" % label)
	_runner.assert_true(body_rect.end.y <= bounds.end.y, "%s bottom collision edge stays inside room bounds" % label)


func _collision_local_rect(body: Node2D) -> Rect2:
	var collision := body.get_node_or_null("Collision") as CollisionShape2D
	if collision == null:
		return Rect2()
	var circle := collision.shape as CircleShape2D
	if circle == null:
		return Rect2()
	var radius := circle.radius * maxf(absf(collision.scale.x), absf(collision.scale.y))
	return Rect2(collision.position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
