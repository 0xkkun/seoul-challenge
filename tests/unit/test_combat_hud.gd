extends Node
## #13 전투 HUD 하트 — 체력 변화가 하트 표시에 반영되는지 검증한다.

const COMBAT_HUD_SCENE := preload("res://scenes/ui/combat_hud.tscn")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const REMOVED_BASEBALL_NAME := "낡은" + "야구공"

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


func test_hud_edges_respect_landscape_phone_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	var health_panel := _hud.get_node("Root/HealthPanel") as Control
	var stub_panel := _hud.get_node("Root/StubPanel") as Control

	_runner.assert_eq(health_panel.offset_left, insets["left"], "체력 HUD는 좌측 가로폰 safe-area 안쪽에 배치된다")
	_runner.assert_eq(health_panel.offset_top, insets["top"], "체력 HUD는 상단 safe-area 안쪽에 배치된다")
	_runner.assert_eq(stub_panel.offset_right, -float(insets["right"]), "우측 HUD 텍스트는 노치/라운드 코너를 피한다")
	_runner.assert_eq(stub_panel.offset_top, insets["top"], "우측 HUD 텍스트는 상단 safe-area 안쪽에 배치된다")


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


func test_top_hud_slots_leave_space_for_upgraded_hearts() -> void:
	_hud.set_health(7, 7)

	var health_panel := _hud.get_node("Root/HealthPanel") as Control
	var hearts := _hud.get_node("%Hearts") as HBoxContainer
	var stub_panel := _hud.get_node("Root/StubPanel") as Control
	if not stub_panel.visible:
		_runner.assert_false(stub_panel.visible, "hidden top HUD status slots cannot overlap upgraded hearts")
		return

	var heart_width := 0.0
	for heart: Control in hearts.get_children():
		heart_width += heart.custom_minimum_size.x
	var gap_width := float(maxi(0, hearts.get_child_count() - 1) * hearts.get_theme_constant("separation"))
	var upgraded_hearts_right := health_panel.offset_left + heart_width + gap_width

	_runner.assert_true(
		stub_panel.get_global_rect().position.x >= upgraded_hearts_right + 8.0,
		"top HUD status slots leave breathing room after seven upgraded hearts"
	)


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


func test_weapon_state_renders_player_facing_memory_weapon() -> void:
	_runner.assert_true(_hud.has_method("set_weapon_state"), "HUD exposes weapon state setter")
	_runner.assert_true(_hud.has_method("get_weapon_text"), "HUD exposes weapon text for tests")
	if not _hud.has_method("set_weapon_state") or not _hud.has_method("get_weapon_text"):
		return

	_hud.set_weapon_state(&"bat")
	_runner.assert_eq(_hud.get_weapon_text(), "기억 무기: 금 간 나무 배트", "HUD updates weapon display")

	_hud.set_weapon_state(&"baseball")
	_runner.assert_eq(_hud.get_weapon_text(), "기억 무기: 없음", "HUD does not render removed baseball memory weapon")
	_runner.assert_false(_hud.get_weapon_text().contains(REMOVED_BASEBALL_NAME), "removed baseball memory weapon is not player-facing")


func test_weapon_name_renders_awakened_bat_display_name() -> void:
	_runner.assert_true(_hud.has_method("set_weapon_name"), "HUD can accept player-facing weapon names")
	if not _hud.has_method("set_weapon_name"):
		return

	_hud.call("set_weapon_name", "마지막 시즌의 배트")

	_runner.assert_eq(_hud.get_weapon_text(), "기억 무기: 마지막 시즌의 배트", "HUD shows awakened bat display name")


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


func test_hud_has_no_yeopjeon_currency_slot() -> void:
	var root := _hud.get_node("Root") as Control

	_runner.assert_false(_hud.has_method("set_currency_state"), "HUD no longer exposes ingame currency state")
	_runner.assert_false(_hud.has_method("get_currency_text"), "HUD no longer exposes ingame currency text")
	_runner.assert_false(_hud.has_method("get_currency_icon_path"), "HUD no longer exposes yeopjeon icon path")
	_runner.assert_false(root.has_node("CurrencyPanel"), "HUD removes the yeopjeon currency panel")
	_runner.assert_eq(_hud.get_node_or_null("%CurrencyIcon"), null, "HUD removes the yeopjeon icon node")
	_runner.assert_eq(_hud.get_node_or_null("%CurrencyAmountLabel"), null, "HUD removes the yeopjeon amount label")


func test_top_right_hud_hides_stub_labels_without_currency_panel() -> void:
	var root := _hud.get_node("Root") as Control
	var weapon_slot := _hud.get_node("%WeaponSlot") as Control
	var skill_slot := _hud.get_node("%SkillSlot") as Control

	_runner.assert_false(weapon_slot.visible, "top-right HUD hides the weapon text label")
	_runner.assert_false(skill_slot.visible, "top-right HUD hides the skill text label")
	_runner.assert_false(root.has_node("CurrencyPanel"), "top-right HUD has no unused currency display")
