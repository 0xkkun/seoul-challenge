extends Node
## 영구 메타 업그레이드가 플레이어 스탯에 실제 반영되는지 검증.

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func _make_player() -> Node:
	var p: Node = PlayerScript.new()
	add_child(p) # _ready → 메타 시드 + 스탯 적용
	return p


func test_no_upgrades_leaves_base_stats() -> void:
	var p := _make_player()
	_runner.assert_eq(p.max_health, 5, "기본 체력 5")
	_runner.assert_eq(p.melee_damage, 1, "기본 근접 1")
	_runner.assert_eq(p.bat_damage, 2, "기본 배트 2")
	_runner.assert_eq(p.special_skill_max_uses, 3, "기본 대시 3")


func test_meta_upgrades_apply_on_spawn() -> void:
	SaveManager.set_meta_upgrade_level(&"max_health", 2)
	SaveManager.set_meta_upgrade_level(&"attack_damage", 3)
	SaveManager.set_meta_upgrade_level(&"dodge_charges", 2)
	var p := _make_player()
	_runner.assert_eq(p.max_health, 7, "체력 5+2")
	_runner.assert_eq(p.melee_damage, 1, "근접은 메타 없음 → 기본 1")
	_runner.assert_eq(p.bat_damage, 5, "공격력 레벨3 → 배트 2+3")
	_runner.assert_eq(p.special_skill_max_uses, 5, "대시 3+2")
	_runner.assert_eq(p.get_health(), 7, "스폰 시 체력 풀")
	_runner.assert_eq(p.special_skill_uses_remaining, 5, "스폰 시 대시 풀충전")


func test_session_restart_reapplies_latest_meta() -> void:
	SaveManager.set_meta_upgrade_level(&"max_health", 1)
	var p := _make_player()
	_runner.assert_eq(p.max_health, 6, "최초 5+1")
	# 락커에서 추가 강화 후 다음 런 시작(session_started → reset_run_modifiers(true)) 시뮬레이트
	SaveManager.set_meta_upgrade_level(&"max_health", 3)
	p.reset_run_modifiers(true)
	_runner.assert_eq(p.max_health, 8, "재시작 시 최신 메타 5+3")
	_runner.assert_eq(p.get_health(), 8, "체력 풀 회복")


func test_meta_and_run_item_modifiers_stack() -> void:
	SaveManager.set_meta_upgrade_level(&"attack_damage", 1)
	var p := _make_player()
	p.reset_run_modifiers(true) # 런 시작(메타 적용)
	_runner.assert_eq(p.bat_damage, 3, "메타 공격력 → 배트 2+1")
	# 런 중 강타 부적 아이템(배트 +1) 획득 → 메타와 합산
	p.apply_run_modifier(&"gung_talisman")
	_runner.assert_eq(p.bat_damage, 4, "메타+아이템 = 2+1+1")
