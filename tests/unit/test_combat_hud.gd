extends Node
## #13 전투 HUD 하트 — 체력 변화가 하트 표시에 반영되는지 검증한다.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")

var _runner: Node
# CombatHud 글로벌 클래스 등록(에디터 import) 순서에 의존하지 않도록 타입 주석 없이 둔다.
var _hud


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	_hud = COMBAT_HUD_SCENE.instantiate()
	add_child(_hud)


func after_each() -> void:
	if is_instance_valid(_hud):
		_hud.free()
	_hud = null


func test_set_health_renders_filled_and_empty_hearts() -> void:
	_hud.set_health(3, 3)
	_runner.assert_eq(_hud.get_max_health(), 3, "최대 체력만큼 하트가 생성된다")
	_runner.assert_eq(_hud.get_filled_heart_count(), 3, "가득 찬 체력은 모두 채워진 하트")

	_hud.set_health(1, 3)
	_runner.assert_eq(_hud.get_filled_heart_count(), 1, "체력 감소가 하트에 반영된다")


func test_health_changed_event_updates_hearts() -> void:
	EventBus.emit_player_health_changed({"current": 2, "max": 3})
	_runner.assert_eq(_hud.get_max_health(), 3, "EventBus 페이로드의 최대 체력 반영")
	_runner.assert_eq(_hud.get_current_health(), 2, "EventBus 페이로드의 현재 체력 반영")
	_runner.assert_eq(_hud.get_filled_heart_count(), 2, "피격 시 하트 감소 반영")


func test_health_is_clamped_to_valid_range() -> void:
	_hud.set_health(99, 3)
	_runner.assert_eq(_hud.get_filled_heart_count(), 3, "현재 체력은 최대치로 클램프된다")

	_hud.set_health(-5, 3)
	_runner.assert_eq(_hud.get_current_health(), 0, "현재 체력은 0 미만으로 내려가지 않는다")
	_runner.assert_eq(_hud.get_filled_heart_count(), 0, "체력 0이면 채워진 하트가 없다")


func test_skill_state_renders_uses_and_cooldown() -> void:
	_runner.assert_true(_hud.has_method("set_skill_state"), "HUD exposes skill state setter")
	_runner.assert_true(_hud.has_method("get_skill_text"), "HUD exposes skill text for tests")
	if not _hud.has_method("set_skill_state") or not _hud.has_method("get_skill_text"):
		return
	_hud.set_skill_state({
		"skill_id": &"emergency_dodge",
		"uses_remaining": 2,
		"max_uses": 3,
		"cooldown_remaining": 0.5,
	})

	var text: String = _hud.get_skill_text()
	_runner.assert_true(text.contains("회피"), "HUD names the emergency dodge skill")
	_runner.assert_true(text.contains("2/3"), "HUD renders remaining skill uses")
	_runner.assert_true(text.contains("0.5"), "HUD renders cooldown")


func test_skill_state_event_updates_skill_slot() -> void:
	_runner.assert_true(EventBus.has_method("emit_special_skill_state_changed"), "EventBus exposes skill state wrapper")
	_runner.assert_true(_hud.has_method("get_skill_text"), "HUD exposes skill text for tests")
	if not EventBus.has_method("emit_special_skill_state_changed") or not _hud.has_method("get_skill_text"):
		return

	EventBus.emit_special_skill_state_changed({
		"skill_id": &"emergency_dodge",
		"uses_remaining": 1,
		"max_uses": 3,
		"cooldown_remaining": 0.0,
	})

	_runner.assert_true(_hud.get_skill_text().contains("1/3"), "skill event updates HUD")


func test_currency_state_renders_ingame_balance() -> void:
	_runner.assert_true(_hud.has_method("set_currency_state"), "HUD exposes currency state setter")
	_runner.assert_true(_hud.has_method("get_currency_text"), "HUD exposes currency text for tests")
	if not _hud.has_method("set_currency_state") or not _hud.has_method("get_currency_text"):
		return

	_hud.set_currency_state({"ingame": 7})

	_runner.assert_true(_hud.get_currency_text().contains("엽전"), "HUD labels ingame currency")
	_runner.assert_true(_hud.get_currency_text().contains("7"), "HUD renders ingame balance")


func test_currency_changed_event_updates_currency_slot() -> void:
	_runner.assert_true(EventBus.has_method("emit_currency_changed"), "EventBus exposes currency wrapper")
	_runner.assert_true(_hud.has_method("get_currency_text"), "HUD exposes currency text for tests")
	if not EventBus.has_method("emit_currency_changed") or not _hud.has_method("get_currency_text"):
		return

	EventBus.emit_currency_changed({
		"kind": "ingame",
		"amount": 3,
		"ingame": 3,
		"source": "CurrencySystem",
	})

	_runner.assert_true(_hud.get_currency_text().contains("3"), "currency event updates HUD")
