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
