extends Node
## #52 모바일 터치 입력 — 조이스틱 값/플레이어 facing 순수 함수 단위 테스트.

const JoystickScript := preload("res://scripts/ui/virtual_joystick.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const INGAME_CONTROL_ONBOARDING_SCRIPT_PATH := "res://scripts/ui/ingame_control_onboarding.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_joystick_value_within_radius() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(45.0, 0.0), 90.0, 0.18)
	_runner.assert_true(is_equal_approx(v.x, 0.5), "반경 절반 → 0.5")
	j.free()


func test_joystick_value_clamps_beyond_radius() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(180.0, 0.0), 90.0, 0.18)
	_runner.assert_true(is_equal_approx(v.length(), 1.0), "반경 초과 → 1.0 클램프")
	j.free()


func test_joystick_deadzone_returns_zero() -> void:
	var j = JoystickScript.new()
	var v: Vector2 = j.compute_value(Vector2(5.0, 0.0), 90.0, 0.18)
	_runner.assert_true(v == Vector2.ZERO, "데드존 이하 → ZERO")
	j.free()


func test_ingame_control_onboarding_contract_teaches_mobile_combat_inputs() -> void:
	_runner.assert_true(ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH), "인게임 조작 온보딩 스크립트가 존재한다")
	if not ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH):
		return
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)

	_runner.assert_true(onboarding.has_method("get_visual_contract"), "조작 온보딩은 테스트 가능한 시각 계약을 노출한다")
	if onboarding.has_method("get_visual_contract"):
		var contract: Dictionary = onboarding.call("get_visual_contract")
		_runner.assert_eq(contract.get("flow"), &"first_ingame_controls", "온보딩 flow id는 안정적이다")
		_runner.assert_eq(bool(contract.get("blocks_gameplay", true)), false, "조작 온보딩은 실제 입력을 막지 않는다")
		_runner.assert_eq(bool(contract.get("uses_dim_cutout", false)), true, "대상 외 화면은 dim 처리하고 대상은 cutout으로 남긴다")
		_runner.assert_true(float(contract.get("dim_alpha", 0.0)) >= 0.45, "dim alpha는 주변을 충분히 낮춘다")
		_runner.assert_true(float(contract.get("camera_zoom_target", 1.0)) > 1.0, "첫 조작 안내 중 카메라는 살짝 줌인한다")
		_runner.assert_eq(contract.get("step_ids", []), [&"move", &"attack", &"dash", &"power_attack"], "이동, 기본공격, 대쉬, 강공격 순서로 안내한다")
		_runner.assert_eq(contract.get("step_target_names", []), [
			["Joystick"],
			["AttackButton"],
			["SkillButton"],
			["SkillButton", "AttackButton"],
		], "각 단계는 실제 터치 컨트롤 노드를 타겟으로 삼는다")
	onboarding.queue_free()


func test_ingame_control_onboarding_advances_with_actual_touch_input_state() -> void:
	_runner.assert_true(ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH), "인게임 조작 온보딩 스크립트가 존재한다")
	if not ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH):
		return
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := TouchControlsScene.instantiate()
	var onboarding := script.new() as CanvasLayer
	add_child(touch)
	add_child(onboarding)

	_runner.assert_true(onboarding.has_method("configure"), "조작 온보딩은 터치 컨트롤을 주입받는다")
	_runner.assert_true(onboarding.has_method("start"), "조작 온보딩은 명시적으로 시작할 수 있다")
	_runner.assert_true(onboarding.has_method("advance_from_input"), "조작 온보딩은 실제 입력 상태로 진행된다")
	_runner.assert_true(onboarding.has_method("get_current_step_snapshot"), "조작 온보딩은 현재 단계 snapshot을 노출한다")
	if not onboarding.has_method("configure") or not onboarding.has_method("start") or not onboarding.has_method("advance_from_input") or not onboarding.has_method("get_current_step_snapshot"):
		touch.queue_free()
		onboarding.queue_free()
		return

	onboarding.call("configure", touch, null, null)
	onboarding.call("start")
	_assert_onboarding_step(onboarding, &"move", ["Joystick"])
	onboarding.call("advance_from_input", {"move": Vector2.RIGHT})
	_assert_onboarding_step(onboarding, &"attack", ["AttackButton"])
	onboarding.call("advance_from_input", {"attack_pressed": true})
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])
	onboarding.call("advance_from_input", {"dash_pressed": true})
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])
	onboarding.call("advance_from_input", {"attack_pressed": true, "power_window_active": true})
	_runner.assert_false(bool(onboarding.call("is_active")), "강공격 입력까지 확인하면 온보딩은 종료된다")

	touch.queue_free()
	onboarding.queue_free()


func test_facing_updates_with_move() -> void:
	var p = PlayerScript.new()
	var f: Vector2 = p.update_facing(Vector2.DOWN, Vector2(10.0, 0.0))
	_runner.assert_true(is_equal_approx(f.x, 1.0), "이동 방향으로 facing 갱신")
	p.free()


func test_facing_holds_when_idle() -> void:
	var p = PlayerScript.new()
	var f: Vector2 = p.update_facing(Vector2.UP, Vector2.ZERO)
	_runner.assert_true(f == Vector2.UP, "이동 없으면 facing 유지")
	p.free()


func test_touch_controls_exposes_skill_button() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	_runner.assert_true(touch.has_method("is_skill_pressed"), "touch controls expose skill input")
	_runner.assert_true(touch.has_signal("skill_pressed"), "touch controls expose an immediate skill press signal")
	_runner.assert_true(touch.has_method("get_control_category"), "touch controls expose an input control category")
	if touch.has_method("get_control_category"):
		_runner.assert_eq(touch.get_control_category(), "combat", "touch controls default to combat controls")
	var skill_button := touch.get_node_or_null("SkillButton")
	_runner.assert_not_null(skill_button, "touch controls mount third skill button")
	if not touch.has_method("is_skill_pressed") or skill_button == null:
		return
	skill_button.set("_active_index", 7)
	_runner.assert_true(touch.is_skill_pressed(), "held skill button is reported")
	_runner.assert_true(skill_button.has_method("set_skill_state"), "skill button accepts skill state")
	_runner.assert_true(skill_button.has_method("get_cooldown_ratio"), "skill button exposes cooldown ratio")
	_runner.assert_true(skill_button.has_method("get_charge_slot_snapshot"), "skill button exposes non-text charge slots")
	if not skill_button.has_method("set_skill_state") or not skill_button.has_method("get_cooldown_ratio") or not skill_button.has_method("get_charge_slot_snapshot"):
		return
	skill_button.set_skill_state({
		"uses_remaining": 2,
		"max_uses": 3,
		"cooldown_remaining": 0.5,
		"cooldown": 1.0,
	})
	_runner.assert_true(is_equal_approx(skill_button.get_cooldown_ratio(), 0.5), "skill button exposes cooldown progress")
	var slots: Array = skill_button.get_charge_slot_snapshot()
	_runner.assert_eq(slots.size(), 3, "skill button renders one slot per base dodge charge")
	if slots.size() == 3:
		_runner.assert_eq(slots[0]["state"], &"filled", "first stored dash is filled")
		_runner.assert_eq(slots[1]["state"], &"filled", "second stored dash is filled")
		_runner.assert_eq(slots[2]["state"], &"charging", "spent dash slot shows recharge progress")


func test_touch_controls_emit_immediate_skill_press_on_touch_down() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(skill_button, "touch controls mount skill button")
	_runner.assert_true(touch.has_signal("skill_pressed"), "touch controls relay skill press events")
	if skill_button == null or not touch.has_signal("skill_pressed"):
		return

	var presses := []
	touch.connect("skill_pressed", func() -> void: presses.append(true))

	skill_button.call("_input", _screen_touch(41, skill_button.get_global_rect().get_center(), true))

	_runner.assert_eq(presses.size(), 1, "touch down on the skill button emits an immediate press signal")
	_runner.assert_true(touch.is_skill_pressed(), "skill remains held for polling after the immediate signal")


func test_touch_controls_can_release_combat_inputs_for_modal_open() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var joystick := touch.get_node_or_null("Joystick") as Control
	var attack_button := touch.get_node_or_null("AttackButton") as Control
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(joystick, "touch controls mount joystick")
	_runner.assert_not_null(attack_button, "touch controls mount attack button")
	_runner.assert_not_null(skill_button, "touch controls mount skill button")
	_runner.assert_true(touch.has_method("release_combat_inputs"), "touch controls expose modal-safe input release")
	if joystick == null or attack_button == null or skill_button == null or not touch.has_method("release_combat_inputs"):
		return

	joystick.set("_active_index", 3)
	joystick.set("_value", Vector2.LEFT)
	attack_button.set("_active_index", 4)
	skill_button.set("_active_index", 5)
	_runner.assert_eq(touch.get_move(), Vector2.LEFT, "held joystick starts active")
	_runner.assert_true(touch.is_attack_pressed(), "held attack starts active")
	_runner.assert_true(touch.is_skill_pressed(), "held skill starts active")

	touch.call("release_combat_inputs")

	_runner.assert_eq(touch.get_move(), Vector2.ZERO, "modal release clears held joystick movement")
	_runner.assert_false(touch.is_attack_pressed(), "modal release clears held attack")
	_runner.assert_false(touch.is_skill_pressed(), "modal release clears held skill")


func test_touch_controls_hidden_state_releases_and_masks_all_inputs() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var joystick := touch.get_node_or_null("Joystick") as Control
	var attack_button := touch.get_node_or_null("AttackButton") as Control
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(joystick, "touch controls mount joystick")
	_runner.assert_not_null(attack_button, "touch controls mount attack button")
	_runner.assert_not_null(skill_button, "touch controls mount skill button")
	if joystick == null or attack_button == null or skill_button == null:
		return

	joystick.set("_active_index", 3)
	joystick.set("_value", Vector2.RIGHT)
	attack_button.set("_active_index", 4)
	skill_button.set("_active_index", 5)

	touch.visible = false

	_runner.assert_eq(touch.get_move(), Vector2.ZERO, "hidden touch controls never leak joystick movement")
	_runner.assert_false(touch.is_attack_pressed(), "hidden touch controls never leak held attack")
	_runner.assert_false(touch.is_skill_pressed(), "hidden touch controls never leak held skill")
	_runner.assert_eq(joystick.get("_active_index"), -1, "hiding controls releases the joystick touch index")
	_runner.assert_eq(attack_button.get("_active_index"), -1, "hiding controls releases the attack touch index")
	_runner.assert_eq(skill_button.get("_active_index"), -1, "hiding controls releases the skill touch index")


func test_hidden_touch_controls_ignore_new_touch_events_until_shown() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var joystick := touch.get_node_or_null("Joystick") as Control
	var attack_button := touch.get_node_or_null("AttackButton") as Control
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(joystick, "touch controls mount joystick")
	_runner.assert_not_null(attack_button, "touch controls mount attack button")
	_runner.assert_not_null(skill_button, "touch controls mount skill button")
	if joystick == null or attack_button == null or skill_button == null:
		return

	touch.visible = false
	joystick.call("_input", _screen_touch(9, joystick.get_global_rect().get_center(), true))
	attack_button.call("_input", _screen_touch(10, attack_button.get_global_rect().get_center(), true))
	skill_button.call("_input", _screen_touch(11, skill_button.get_global_rect().get_center(), true))

	_runner.assert_eq(joystick.get("_active_index"), -1, "hidden joystick ignores new touch starts")
	_runner.assert_eq(attack_button.get("_active_index"), -1, "hidden attack button ignores new touch starts")
	_runner.assert_eq(skill_button.get("_active_index"), -1, "hidden skill button ignores new touch starts")

	touch.visible = true

	_runner.assert_eq(touch.get_move(), Vector2.ZERO, "showing controls does not resurrect hidden joystick touches")
	_runner.assert_false(touch.is_attack_pressed(), "showing controls does not resurrect hidden attack touches")
	_runner.assert_false(touch.is_skill_pressed(), "showing controls does not resurrect hidden skill touches")


func test_touch_control_children_release_when_hidden_directly() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var joystick := touch.get_node_or_null("Joystick") as Control
	var attack_button := touch.get_node_or_null("AttackButton") as Control
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(joystick, "touch controls mount joystick")
	_runner.assert_not_null(attack_button, "touch controls mount attack button")
	_runner.assert_not_null(skill_button, "touch controls mount skill button")
	if joystick == null or attack_button == null or skill_button == null:
		return

	joystick.set("_active_index", 3)
	joystick.set("_value", Vector2.LEFT)
	attack_button.set("_active_index", 4)
	skill_button.set("_active_index", 5)

	joystick.visible = false
	attack_button.visible = false
	skill_button.visible = false

	_runner.assert_eq(joystick.get("_active_index"), -1, "hidden joystick releases its touch index")
	_runner.assert_eq(joystick.get("_value"), Vector2.ZERO, "hidden joystick clears movement")
	_runner.assert_eq(attack_button.get("_active_index"), -1, "hidden attack button releases its touch index")
	_runner.assert_eq(skill_button.get("_active_index"), -1, "hidden skill button releases its touch index")


func test_touch_controls_day_dialogue_category_hides_dodge_button() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var attack_button := touch.get_node_or_null("AttackButton") as Control
	var skill_button := touch.get_node_or_null("SkillButton") as Control
	_runner.assert_not_null(attack_button, "touch controls keep a right-side primary action button")
	_runner.assert_not_null(skill_button, "touch controls mount the skill button")
	_runner.assert_true(touch.has_method("set_control_category"), "touch controls can switch input control categories")
	if attack_button == null or skill_button == null or not touch.has_method("set_control_category"):
		return

	skill_button.set("_active_index", 7)
	touch.set_control_category("day_dialogue")

	_runner.assert_eq(touch.get_control_category(), "day_dialogue", "day dialogue category is stored")
	_runner.assert_true(attack_button.visible, "day dialogue keeps the primary right button for talking")
	_runner.assert_false(skill_button.visible, "day dialogue hides the dodge skill button")
	_runner.assert_false(touch.is_skill_pressed(), "hidden dodge button does not report held input")


func test_touch_controls_day_dialogue_category_uses_speech_bubble_action_icon() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var attack_button := touch.get_node_or_null("AttackButton") as Control
	_runner.assert_not_null(attack_button, "touch controls keep a right-side primary action button")
	_runner.assert_true(touch.has_method("set_control_category"), "touch controls can switch input control categories")
	if attack_button == null or not touch.has_method("set_control_category"):
		return
	_runner.assert_true(attack_button.has_method("get_visual_contract"), "primary action button exposes its icon contract")
	if not attack_button.has_method("get_visual_contract"):
		return

	touch.set_control_category("day_dialogue")

	var dialogue_contract: Dictionary = attack_button.call("get_visual_contract")
	_runner.assert_eq(dialogue_contract.get("icon_mode"), "dialogue", "day dialogue uses a talk/message icon on the primary action")
	_runner.assert_eq(dialogue_contract.get("icon_shape"), "speech_bubble", "day dialogue icon is a speech bubble")

	touch.set_control_category("combat")
	var combat_contract: Dictionary = attack_button.call("get_visual_contract")
	_runner.assert_eq(combat_contract.get("icon_mode"), "attack", "combat restores the attack icon")
	_runner.assert_eq(combat_contract.get("icon_path"), "res://assets/ui/icons/combat/damage_1.png", "combat still uses the damage icon")


func test_touch_controls_respect_landscape_phone_safe_area() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	var joystick := touch.get_node("Joystick") as Control
	var attack_button := touch.get_node("AttackButton") as Control
	var skill_button := touch.get_node("SkillButton") as Control
	var touch_insets := MobileSafeArea.touch_insets()

	_runner.assert_eq(joystick.offset_left, touch_insets["left"], "조이스틱은 좌측 가로폰 safe-area 밖으로 나오지 않는다")
	_runner.assert_eq(joystick.offset_bottom, -float(touch_insets["bottom"]), "조이스틱은 홈 인디케이터 위로 올라온다")
	_runner.assert_eq(attack_button.offset_right, -float(touch_insets["right"]), "공격 버튼은 우측 노치/라운드 코너를 피한다")
	_runner.assert_eq(attack_button.offset_bottom, -float(touch_insets["bottom"]), "공격 버튼은 홈 인디케이터 위로 올라온다")
	_runner.assert_eq(skill_button.offset_bottom, -float(touch_insets["bottom"]), "스킬 버튼도 하단 gesture bar를 피한다")


func _assert_onboarding_step(onboarding: CanvasLayer, expected_id: StringName, expected_targets: Array) -> void:
	var snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(snapshot.get("step_id"), expected_id, "현재 온보딩 단계 id가 맞다")
	_runner.assert_eq(snapshot.get("target_names", []), expected_targets, "현재 온보딩 타겟이 맞다")
	_runner.assert_true(String(snapshot.get("title", "")) != "", "현재 온보딩 단계는 제목을 가진다")
	_runner.assert_true(String(snapshot.get("body", "")) != "", "현재 온보딩 단계는 짧은 설명을 가진다")


func _screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event
