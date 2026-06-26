extends Node
## 피격·사망 → 학교 귀환 트리거.
## 플레이어 체력이 0 이 되면 런을 종료하고(GameManager.finish_session)
## 학교 허브(lobby)로 전환한다(SceneTransition.go_to_lobby).
## 영구 재화는 CurrencySystem 이 session_finished 에서 ingame 만 리셋하므로 자동 유지된다.
class_name DeathReturnController

## 테스트에서 실제 씬 전환을 피하려고 주입 가능한 시드.
## 미설정 시 SceneTransition.go_to_lobby() 를 호출한다.
var return_to_hub_callable: Callable

var _run_ended := false


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.session_started.connect(_on_session_started)


func _on_session_started(_config: Dictionary) -> void:
	_run_ended = false


func _on_player_health_changed(payload: Dictionary) -> void:
	if _run_ended or not GameManager.is_session_active():
		return
	var max_health := int(payload.get("max", 0))
	var current := int(payload.get("current", max_health))
	if max_health > 0 and current <= 0:
		trigger_death_return()


## 사망 처리: 런 종료 + 학교 귀환. 런당 1회만 발동한다.
func trigger_death_return() -> void:
	if _run_ended:
		return
	_run_ended = true
	EventBus.emit_player_died({"cause": "health_depleted"})
	if GameManager.is_session_active():
		GameManager.finish_session({"outcome": "death"})
	if return_to_hub_callable.is_valid():
		return_to_hub_callable.call()
	else:
		SceneTransition.go_to_lobby()
