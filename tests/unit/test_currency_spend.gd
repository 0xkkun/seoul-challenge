extends Node
## CurrencySystem.spend_permanent + SaveManager 메타 업그레이드 레벨 영속화 테스트.

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func after_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()


func _seed_permanent(amount: int) -> void:
	EventBus.emit_friend_purified({"permanent_amount": amount})


func test_spend_permanent_deducts_when_affordable() -> void:
	_seed_permanent(10)
	var ok := CurrencySystem.spend_permanent(4, "test")
	_runner.assert_true(ok, "충분하면 true")
	_runner.assert_eq(CurrencySystem.get_permanent(), 6, "4 차감")


func test_spend_permanent_fails_when_insufficient() -> void:
	_seed_permanent(3)
	var ok := CurrencySystem.spend_permanent(4, "test")
	_runner.assert_false(ok, "부족하면 false")
	_runner.assert_eq(CurrencySystem.get_permanent(), 3, "실패 시 차감 없음")


func test_spend_permanent_rejects_non_positive() -> void:
	_seed_permanent(5)
	_runner.assert_false(CurrencySystem.spend_permanent(0, "x"), "0 거부")
	_runner.assert_false(CurrencySystem.spend_permanent(-2, "x"), "음수 거부")
	_runner.assert_eq(CurrencySystem.get_permanent(), 5, "잔액 유지")


func test_meta_upgrade_level_persists_in_profile() -> void:
	_runner.assert_eq(SaveManager.get_meta_upgrade_level(&"max_health"), 0, "기본 레벨 0")
	SaveManager.set_meta_upgrade_level(&"max_health", 2)
	_runner.assert_eq(SaveManager.get_meta_upgrade_level(&"max_health"), 2, "설정 반영")
	# 다른 시스템이 프로필을 로드/저장해도 보존되는지 (영구 재화 저장 경로와 공존)
	_seed_permanent(5)
	_runner.assert_eq(SaveManager.get_meta_upgrade_level(&"max_health"), 2, "재화 저장 후에도 레벨 보존")
