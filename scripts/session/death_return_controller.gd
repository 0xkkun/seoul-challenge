extends Node
## 피격·사망 → 게임오버 플로우 트리거.
## 플레이어 체력이 0 이 되면 런을 종료하고(GameManager.finish_session)
## 세션 결과 UI가 연결되어 있으면 게임오버 요약을 표시한다.
## 영구 재화는 CurrencySystem 이 session_finished 에서 ingame 만 리셋하므로 자동 유지된다.
class_name DeathReturnController

## 사망 결과에 현재 방/보상 같은 세션별 값을 합치기 위한 선택 콜백.
var death_result_builder_callable: Callable

## 사망 결과 UI를 표시하기 위한 선택 콜백. 인자는 최종 result Dictionary 다.
var game_over_callable: Callable

## 게임오버 UI가 없는 독립 테스트/장면의 fallback.
var return_to_hub_callable: Callable

var _run_ended := false


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.session_started.connect(_on_session_started)


func _exit_tree() -> void:
	if not has_node("/root/EventBus"):
		return
	if EventBus.player_health_changed.is_connected(_on_player_health_changed):
		EventBus.player_health_changed.disconnect(_on_player_health_changed)
	if EventBus.session_started.is_connected(_on_session_started):
		EventBus.session_started.disconnect(_on_session_started)


func _on_session_started(_config: Dictionary) -> void:
	_run_ended = false


func _on_player_health_changed(payload: Dictionary) -> void:
	if _run_ended or not GameManager.is_session_active():
		return
	var max_health := int(payload.get("max", 0))
	var current := int(payload.get("current", max_health))
	if max_health > 0 and current <= 0:
		trigger_death_return()


## 사망 처리: 런 종료 + 게임오버 플로우. 런당 1회만 발동한다.
func trigger_death_return() -> void:
	if _run_ended:
		return
	_run_ended = true
	EventBus.emit_player_died({"cause": "health_depleted"})
	var result := _build_death_result()
	if GameManager.is_session_active():
		GameManager.finish_session(result)
	if game_over_callable.is_valid():
		game_over_callable.call(result)
	elif return_to_hub_callable.is_valid():
		return_to_hub_callable.call()
	else:
		SceneTransition.go_to_day_lobby()


func _build_death_result() -> Dictionary:
	var result := {}
	if death_result_builder_callable.is_valid():
		var built: Variant = death_result_builder_callable.call()
		if built is Dictionary:
			result = (built as Dictionary).duplicate(true)
	result["outcome"] = "death"
	result["died"] = true
	return result
