extends Node

const ENEMY_SCENE_PATHS := [
	"res://scenes/enemies/akgwi.tscn",
	"res://scenes/enemies/kumiho.tscn",
	"res://scenes/enemies/wolf.tscn",
	"res://scenes/enemies/boss.tscn",
	"res://scenes/enemies/chaser.tscn",
	"res://scenes/enemies/ranged_shooter.tscn",
]

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_enemy_scenes_mount_tailbound_style_health_bar_nodes() -> void:
	for path: String in ENEMY_SCENE_PATHS:
		var enemy := _instantiate_enemy(path)
		if enemy == null:
			continue

		var bg := enemy.get_node_or_null("HealthBarBg") as ColorRect
		var fill := enemy.get_node_or_null("HealthBarFill") as ColorRect

		_runner.assert_not_null(bg, "%s has a HealthBarBg node" % path)
		_runner.assert_not_null(fill, "%s has a HealthBarFill node" % path)
		if bg == null or fill == null:
			enemy.queue_free()
			continue

		_runner.assert_false(bg.visible, "%s health bar starts hidden at full HP" % path)
		_runner.assert_false(fill.visible, "%s health fill starts hidden at full HP" % path)
		_runner.assert_true(fill.size.x <= bg.size.x, "%s fill fits inside the bar" % path)
		_runner.assert_true(bg.position.y < 0.0, "%s health bar is positioned above the enemy" % path)
		enemy.queue_free()


func test_enemy_damage_reveals_overhead_health_bar_ratio() -> void:
	for path: String in ENEMY_SCENE_PATHS:
		var enemy := _instantiate_enemy(path)
		if enemy == null:
			continue

		_runner.assert_true(
			enemy.has_method("get_health_bar_snapshot"),
			"%s exposes a health bar snapshot for visual contract tests" % path
		)
		if not enemy.has_method("get_health_bar_snapshot"):
			enemy.queue_free()
			continue

		var full_snapshot: Dictionary = enemy.call("get_health_bar_snapshot")
		_runner.assert_false(
			bool(full_snapshot.get("visible", true)),
			"%s keeps the health bar hidden while undamaged" % path
		)

		enemy.call("take_damage", 1)
		var damaged_snapshot: Dictionary = enemy.call("get_health_bar_snapshot")
		var max_hp := float(enemy.get("max_hp"))
		var expected_ratio := clampf((max_hp - 1.0) / max_hp, 0.0, 1.0)

		_runner.assert_true(
			bool(damaged_snapshot.get("visible", false)),
			"%s shows the health bar after taking damage" % path
		)
		_runner.assert_true(
			absf(float(damaged_snapshot.get("ratio", -1.0)) - expected_ratio) <= 0.001,
			"%s health fill ratio tracks current HP" % path
		)
		_runner.assert_true(
			float(damaged_snapshot.get("position_y", 0.0)) < 0.0,
			"%s damaged health bar remains above the enemy" % path
		)
		enemy.queue_free()


func _instantiate_enemy(path: String) -> Node2D:
	_runner.assert_true(ResourceLoader.exists(path), "%s exists" % path)
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	_runner.assert_not_null(scene, "%s loads as a scene" % path)
	if scene == null:
		return null
	var enemy := scene.instantiate() as Node2D
	_runner.assert_not_null(enemy, "%s instantiates as Node2D" % path)
	if enemy != null:
		add_child(enemy)
	return enemy
