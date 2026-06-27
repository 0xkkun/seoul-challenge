extends Node
## #14 피격·사망 → 게임오버 — 체력 0 시 런 종료 + 결과 UI 흐름을 검증한다.

const CONTROLLER_SCRIPT := preload("res://scripts/session/death_return_controller.gd")

var _runner: Node
var _controller
var _died_payloads: Array[Dictionary] = []
var _game_over_results: Array[Dictionary] = []
var _hub_calls := 0


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	CurrencySystem.reset_for_tests()
	GameManager.reset_session()
	_died_payloads.clear()
	_game_over_results.clear()
	_hub_calls = 0
	EventBus.player_died.connect(_record_died)
	_controller = CONTROLLER_SCRIPT.new()
	_controller.death_result_builder_callable = func() -> Dictionary:
		return {
			"rooms_cleared": 2,
			"memory_reward": 2,
		}
	_controller.game_over_callable = func(result: Dictionary) -> void:
		_game_over_results.append(result.duplicate(true))
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


func test_health_depleted_ends_run_and_shows_game_over() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 1, "사망 시 player_died 1회 발신")
	_runner.assert_false(GameManager.is_session_active(), "런 종료로 세션 비활성")
	_runner.assert_eq(GameManager.get_last_result().get("outcome", ""), "death", "사망 결과 기록")
	_runner.assert_eq(GameManager.get_last_result().get("rooms_cleared", 0), 2, "사망 결과는 세션 요약 값을 포함")
	_runner.assert_eq(_game_over_results.size(), 1, "게임오버 UI 표시 1회 요청")
	_runner.assert_eq(_game_over_results[0].get("outcome", ""), "death", "게임오버 UI에 사망 결과 전달")
	_runner.assert_eq(_hub_calls, 0, "사망 즉시 허브로 나가지 않음")


func test_death_return_is_idempotent() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 1, "사망은 런당 1회만 발동")
	_runner.assert_eq(_game_over_results.size(), 1, "게임오버 UI도 1회만")
	_runner.assert_eq(_hub_calls, 0, "게임오버 UI가 있으면 허브 전환 없음")


func test_falls_back_to_hub_when_game_over_flow_is_missing() -> void:
	_controller.game_over_callable = Callable()
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(_game_over_results.size(), 0, "게임오버 콜백이 없으면 UI 요청 없음")
	_runner.assert_eq(_hub_calls, 1, "fallback 은 기존 허브 전환 유지")


func test_permanent_currency_survives_death_without_ingame_reset_path() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_currency_changed({"kind": "permanent", "amount": 5})
	EventBus.emit_currency_changed({"kind": "ingame", "amount": 4})
	EventBus.emit_player_health_changed({"current": 0, "max": 3})

	_runner.assert_eq(CurrencySystem.get_permanent(), 5, "영구 재화는 사망 후에도 유지")
	_runner.assert_false(CurrencySystem.has_method("get_ingame"), "삭제된 인게임 엽전 리셋 경로에 의존하지 않는다")
	_runner.assert_eq(_game_over_results.size(), 1, "재화 정산 후 게임오버 UI 표시")


func test_nonzero_health_does_not_end_run() -> void:
	GameManager.start_session({"source": "test"})
	EventBus.emit_player_health_changed({"current": 1, "max": 3})

	_runner.assert_eq(_died_payloads.size(), 0, "체력이 남아있으면 사망 아님")
	_runner.assert_true(GameManager.is_session_active(), "세션 유지")
	_runner.assert_eq(_game_over_results.size(), 0, "게임오버 UI 표시 없음")
	_runner.assert_eq(_hub_calls, 0, "허브 전환 없음")


func _record_died(payload: Dictionary) -> void:
	_died_payloads.append(payload.duplicate(true))
