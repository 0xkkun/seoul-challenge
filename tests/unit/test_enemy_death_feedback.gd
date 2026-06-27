extends Node

const DEATH_FX_SCRIPT_PATH := "res://scripts/combat/enemy_death_fade.gd"
const ChaserScene := preload("res://scenes/enemies/chaser.tscn")
const RangedShooterScene := preload("res://scenes/enemies/ranged_shooter.tscn")
const BossScene := preload("res://scenes/enemies/boss.tscn")
const WolfScene := preload("res://scenes/enemies/wolf.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


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
		_runner.assert_eq(contract.get("draw_style"), &"sprite_opacity_fade", "사망 페이드는 스프라이트 오파시티만 사용한다")
		_runner.assert_true(float(contract.get("lifetime", 0.0)) >= 0.18, "사망 페이드는 눈에 보일 만큼 남는다")
		_runner.assert_true(float(contract.get("lifetime", 1.0)) <= 0.26, "사망 페이드는 전투 흐름을 끌지 않는다")
		_runner.assert_eq(int(contract.get("shard_count", -1)), 0, "사망 페이드는 파편을 만들지 않는다")
		_runner.assert_eq(bool(contract.get("uses_line_art", true)), false, "사망 페이드는 링/선 이펙트를 쓰지 않는다")
		_runner.assert_eq(bool(contract.get("animates_scale", true)), false, "사망 페이드는 크기를 부풀리지 않는다")
	fade.queue_free()


func test_chaser_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(ChaserScene.instantiate(), "chaser")


func test_ranged_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(RangedShooterScene.instantiate(), "ranged")


func test_boss_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(BossScene.instantiate(), "boss")


func test_wolf_death_spawns_detached_fade() -> void:
	_assert_enemy_death_spawns_fade(WolfScene.instantiate(), "wolf")


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
	_runner.assert_true(fade.global_position.is_equal_approx(Vector2(123.0, 77.0)), "%s death fade starts at the death position" % label)
	_runner.assert_true(fade.z_index >= 40, "%s death fade draws above room actors briefly" % label)
	_runner.assert_true(_has_visual_snapshot(fade), "%s death fade keeps a visual snapshot" % label)
	_runner.assert_eq(_count_line_nodes(fade), 0, "%s death fade does not draw rings or shards" % label)
	var before_scale := fade.scale
	var before_alpha := fade.modulate.a
	fade.call("_process", 0.12)
	_runner.assert_true(fade.scale.is_equal_approx(before_scale), "%s death fade keeps scale stable" % label)
	_runner.assert_true(fade.modulate.a < before_alpha, "%s death fade opacity decreases over time" % label)
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


func _has_visual_snapshot(root: Node) -> bool:
	for child in root.get_children():
		if child is CanvasItem and child.name == "VisualSnapshot":
			return true
	return false


func _count_line_nodes(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is Line2D:
			count += 1
		count += _count_line_nodes(child)
	return count
