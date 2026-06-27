extends Node
## 락커 강화 인터페이스 — 구매 버튼 노출 + 구매 시 재화 차감/레벨 증가.

const LockerMaintenanceScene := preload("res://scenes/ui/locker_maintenance.tscn")
const LockerMaintenanceScript := preload("res://scripts/ui/locker_maintenance.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	SceneTransition.clear_pending_run_config()
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func _seed_permanent(amount: int) -> void:
	EventBus.emit_friend_purified({"permanent_amount": amount})


func _make_screen() -> Node:
	var screen := LockerMaintenanceScene.instantiate()
	screen.set("scene_transition_enabled", false)
	add_child(screen)
	return screen


func test_upgrade_panel_exposes_buy_actions() -> void:
	_seed_permanent(0)
	var screen := _make_screen()
	for id: String in ["max_health", "attack_damage", "dodge_charges"]:
		var action := LockerMaintenanceScript.ACTION_UPGRADE_PREFIX + id
		_runner.assert_not_null(
			UiTestHarness.find_by_uat_action(screen, action),
			"%s 강화 버튼 노출" % id
		)


func test_buying_upgrade_spends_permanent_and_increments_level() -> void:
	_seed_permanent(20)
	var screen := _make_screen()
	var action := LockerMaintenanceScript.ACTION_UPGRADE_PREFIX + "max_health"
	_runner.assert_true(UiTestHarness.press_by_uat_action(screen, action), "체력 강화 누름")
	_runner.assert_eq(SaveManager.get_meta_upgrade_level(&"max_health"), 1, "레벨 1로 증가")
	_runner.assert_eq(CurrencySystem.get_permanent(), 16, "비용 4 차감 (20-4)")


func test_buy_does_nothing_when_insufficient_balance() -> void:
	_seed_permanent(2) # 비용 4보다 적음
	var screen := _make_screen()
	var action := LockerMaintenanceScript.ACTION_UPGRADE_PREFIX + "max_health"
	UiTestHarness.press_by_uat_action(screen, action)
	_runner.assert_eq(SaveManager.get_meta_upgrade_level(&"max_health"), 0, "잔액 부족 시 구매 안 됨")
	_runner.assert_eq(CurrencySystem.get_permanent(), 2, "차감 없음")
