extends Node
## #14 피격·사망 → 학교 귀환 — 체력 0 시 런 종료 + 허브 전환 흐름을 검증한다.

const CONTROLLER_SCRIPT := preload("res://scripts/session/death_return_controller.gd")

var _runner: Node
var _controller
var _died_payloads: Array[Dictionary] = []
var _hub_calls := 0


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	GameManager.reset_session()
	_died_payloads.clear()
	_hub_calls = 0
	EventBus.player_died.connect(_record_died)
	_controller = CONTROLLER_SCRIPT.new()
	# 실제 씬 전환 대신 호출 횟수만 기록한다.
	_controller.return_to_hub_callable = func() -> void: _hub_calls += 1
	add_child(_controller)


func after_each() -> void:
	if EventBus.player_died.is_connected(_record_died):
		EventBus.player_died.disconnect(_record_died)
	if is_instance_valid(_controller):
		_controller.free()
	_controller = null
	GameManager.reset_session()
	CurrencySystem.reset_for_tests()
	SaveManager.reset_profile()


func test_health_depleted_ends_run_and_returns_to_hub() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 1, "사망 시 player_died 1회 발신")
	_runner.assert_false(GameManager.is_session_active(), "런 종료로 세션 비활성")
	_runner.assert_eq(GameManager.get_last_result().get("outcome", ""), "death", "사망 결과 기록")
	_runner.assert_eq(_hub_calls, 1, "학교 허브 전환 1회 요청")


func test_death_return_is_idempotent() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 1, "사망은 런당 1회만 발동")
	_runner.assert_eq(_hub_calls, 1, "허브 전환도 1회만")


func test_permanent_currency_survives_death_ingame_resets() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_currency_changed({"kind": "permanent", "amount": 5})
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 4})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(CurrencySystem.get_permanent(), 5, "영구 재화는 사망 후에도 유지")
	_runner.assert_eq(CurrencySystem.get_ingame(), 0, "런 종료 시 인게임 재화 리셋")


func test_nonzero_health_does_not_end_run() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 1, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 0, "체력이 남아있으면 사망 아님")
	_runner.assert_true(GameManager.is_session_active(), "세션 유지")
	_runner.assert_eq(_hub_calls, 0, "허브 전환 없음")


func _record_died(payload: Dictionary) -> void:
	_died_payloads.append(payload.duplicate(true))
