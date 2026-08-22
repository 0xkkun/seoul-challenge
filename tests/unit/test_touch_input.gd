extends Node
## #52 모바일 터치 입력 — 조이스틱 값/플레이어 facing 순수 함수 단위 테스트.

const JoystickScript := preload("res://scripts/ui/virtual_joystick.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const TouchControlsScene := preload("res://scenes/ui/touch_controls.tscn")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const UiTestHarness := preload("res://tests/support/ui_test_harness.gd")
const INGAME_CONTROL_ONBOARDING_SCRIPT_PATH := "res://scripts/ui/ingame_control_onboarding.gd"

var _runner: Node


class StubPowerAttackPlayer:
	extends Node2D
	signal attack_executed(payload: Dictionary)
	signal dash_started(payload: Dictionary)
	signal power_attack_executed(payload: Dictionary)

	var power_window_remaining := 0.5

	func get_dash_power_attack_remaining() -> float:
		return power_window_remaining

	func is_dodging() -> bool:
		return false

	func emit_power_attack() -> void:
		power_attack_executed.emit({"kind": &"dash_power_attack"})

	func emit_attack() -> void:
		attack_executed.emit({"attack_id": &"melee"})

	func emit_dash() -> void:
		dash_started.emit({"special_id": &"emergency_dodge"})


class StubIntegratedInputPlayer:
	extends StubPowerAttackPlayer

	var move_input := Vector2.ZERO
	var firing := false
	var special_pressed := false

	func read_input_vector() -> Vector2:
		return move_input

	func is_firing() -> bool:
		return firing

	func is_special_pressed() -> bool:
		return special_pressed


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
	var touch := _create_visible_touch_controls()
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)
	onboarding.call("configure", touch, null, null)

	_runner.assert_true(onboarding.has_method("get_visual_contract"), "조작 온보딩은 테스트 가능한 시각 계약을 노출한다")
	if onboarding.has_method("get_visual_contract"):
		var contract: Dictionary = onboarding.call("get_visual_contract")
		_runner.assert_eq(contract.get("flow"), &"first_ingame_controls", "온보딩 flow id는 안정적이다")
		_runner.assert_eq(bool(contract.get("blocks_gameplay", true)), false, "조작 온보딩은 실제 입력을 막지 않는다")
		_runner.assert_eq(bool(contract.get("uses_dim_cutout", false)), true, "대상 외 화면은 dim 처리하고 대상은 cutout으로 남긴다")
		_runner.assert_true(float(contract.get("dim_alpha", 0.0)) >= 0.45, "dim alpha는 주변을 충분히 낮춘다")
		_runner.assert_true(float(contract.get("camera_zoom_target", 1.0)) > 1.0, "첫 조작 안내 중 카메라는 살짝 줌인한다")
		_runner.assert_eq(
			contract.get("step_ids", []),
			[&"move", &"attack", &"dash", &"power_attack", &"minimap", &"exit"],
			"첫 방은 조작 성공, 지도, 실제 탈출 순서로 안내한다"
		)
		_runner.assert_eq(contract.get("step_target_names", []), [
			["Joystick"],
			["AttackButton"],
			["SkillButton"],
			["SkillButton", "AttackButton"],
			["Minimap"],
			[],
		], "각 단계는 실제 터치/지도 컨트롤 노드를 타겟으로 삼는다")
	touch.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_advances_only_from_success_events_and_real_displacement() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)
	onboarding.call("configure", null, null, null)
	onboarding.call("start")

	_runner.assert_true(onboarding.has_method("record_action"), "온보딩은 성공 action API를 노출한다")
	_runner.assert_true(onboarding.has_method("record_player_position"), "온보딩은 실제 위치 누적 API를 노출한다")
	_runner.assert_true(onboarding.has_method("record_room_changed"), "온보딩은 실제 방 전환 완료 API를 노출한다")
	_runner.assert_true(onboarding.has_method("skip_guidance"), "온보딩은 막힘 탈출 API를 노출한다")

	onboarding.call("advance_from_input", {
		"move": Vector2.RIGHT,
		"attack_pressed": true,
		"dash_pressed": true,
		"power_attack_executed": true,
	})
	_assert_onboarding_step(onboarding, &"move", [])
	if not onboarding.has_method("record_action") or not onboarding.has_method("record_player_position") or not onboarding.has_method("record_room_changed"):
		onboarding.queue_free()
		return

	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(95.0, 0.0))
	_assert_onboarding_step(onboarding, &"move", [])
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	_assert_onboarding_step(onboarding, &"attack", [])

	onboarding.call("advance_from_input", {"attack_pressed": true, "dash_pressed": true})
	_assert_onboarding_step(onboarding, &"attack", [])
	_runner.assert_true(bool(onboarding.call("record_action", &"attack_executed")), "실제 공격 성공만 다음 단계로 간다")
	_assert_onboarding_step(onboarding, &"dash", [])
	_runner.assert_false(bool(onboarding.call("record_action", &"attack_executed")), "잘못된 성공 action은 현재 단계를 넘기지 않는다")
	_runner.assert_true(bool(onboarding.call("record_action", &"dash_started")), "실제 대시 성공만 강공격 단계로 간다")
	_runner.assert_true(bool(onboarding.call("record_action", &"power_attack_executed")), "실제 강공격 성공만 지도 단계로 간다")
	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])
	_runner.assert_false(bool(onboarding.call("record_action", &"minimap_expanded", {"expanded": false})), "접힌 지도 상태는 성공이 아니다")
	_runner.assert_true(bool(onboarding.call("record_action", &"minimap_expanded", {"expanded": true})), "실제 지도 확대가 출구 단계를 연다")
	_assert_onboarding_step(onboarding, &"exit", [])
	_runner.assert_false(bool(onboarding.call("record_room_changed", &"start", &"start")), "시작 방 이벤트는 출구 완료가 아니다")
	_runner.assert_true(bool(onboarding.call("record_room_changed", &"combat_1", &"combat")), "실제 다음 방 전환이 온보딩을 완료한다")
	_runner.assert_false(bool(onboarding.call("record_room_changed", &"friend_1", &"friend")), "완료는 다시 emit되지 않는다")
	onboarding.queue_free()


func test_ingame_control_onboarding_reveals_real_skip_escape_and_keeps_compact_legend() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)
	_runner.assert_true(onboarding.has_signal("gate_released"), "온보딩은 출구 gate 해제 신호를 노출한다")
	_runner.assert_true(onboarding.has_signal("completed"), "온보딩은 실제 탈출 완료 신호를 노출한다")
	_runner.assert_true(onboarding.has_signal("skipped"), "온보딩은 건너뛰기 신호를 노출한다")
	if not onboarding.has_signal("gate_released") or not onboarding.has_signal("skipped"):
		onboarding.queue_free()
		return

	onboarding.call("configure", null, null, null)
	onboarding.call("start")
	var skip_button := UiTestHarness.find_by_test_id(onboarding, "onboarding.skip_guidance_button") as Button
	var compact_legend := onboarding.get_node_or_null("Root/CompactLegend") as Control
	_runner.assert_not_null(skip_button, "안내 건너뛰기는 stable test id를 가진 실제 Button이다")
	_runner.assert_not_null(compact_legend, "건너뛴 세션용 compact 조작표가 존재한다")
	if skip_button == null or compact_legend == null:
		onboarding.queue_free()
		return
	_runner.assert_eq(skip_button.get_meta("uat_action", ""), "onboarding.skip_guidance", "건너뛰기 UAT action은 안정적이다")
	_runner.assert_eq(skip_button.mouse_filter, Control.MOUSE_FILTER_STOP, "건너뛰기 버튼은 실제 클릭을 받는다")
	_runner.assert_false(skip_button.visible, "건너뛰기는 시작 직후 숨긴다")
	_runner.assert_false(compact_legend.visible, "compact 조작표는 정상 안내 중 숨긴다")

	onboarding.call("_process", 4.9)
	_runner.assert_false(skip_button.visible, "4.9초에는 건너뛰기를 노출하지 않는다")
	onboarding.call("_process", 0.1)
	_runner.assert_true(skip_button.visible, "5.0초에는 막힘 탈출 버튼을 노출한다")
	var skip_rect := onboarding.call("get_skip_button_reference_rect") as Rect2
	_runner.assert_true(
		MobileSafeArea.meets_landscape_minimum(skip_rect),
		"건너뛰기는 960x540 safe-area 안에 있다: rect=%s margins=%s" % [skip_rect, MobileSafeArea.margins_for_rect(skip_rect)]
	)

	var gate_count := [0]
	var skipped_count := [0]
	onboarding.gate_released.connect(func() -> void: gate_count[0] += 1)
	onboarding.skipped.connect(func() -> void: skipped_count[0] += 1)
	_runner.assert_true(UiTestHarness.press_by_uat_action(onboarding, "onboarding.skip_guidance"), "stable UAT action으로 건너뛰기를 누른다")
	_runner.assert_eq(gate_count[0], 1, "건너뛰기는 gate를 정확히 한 번 연다")
	_runner.assert_eq(skipped_count[0], 1, "건너뛰기는 정확히 한 번 기록된다")
	_runner.assert_false(bool(onboarding.call("is_active")), "건너뛰면 단계 진행은 비활성화된다")
	_runner.assert_false(skip_button.visible, "건너뛴 뒤 버튼을 숨긴다")
	_runner.assert_true(compact_legend.visible, "건너뛴 세션에는 compact 조작표를 남긴다")
	onboarding.call("skip_guidance")
	_runner.assert_eq(gate_count[0], 1, "반복 호출은 gate 신호를 재발행하지 않는다")
	_runner.assert_eq(skipped_count[0], 1, "반복 호출은 skipped를 재발행하지 않는다")
	onboarding.queue_free()


func test_ingame_control_onboarding_desktop_guidance_names_keyboard_inputs_without_touch_targets() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var player := StubIntegratedInputPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", null, null, player)
	onboarding.call("start")
	var snapshot: Dictionary = onboarding.call("get_current_step_snapshot")

	_runner.assert_eq(snapshot.get("input_mode"), &"desktop", "터치 UI가 없으면 데스크톱 안내 모드를 쓴다")
	_runner.assert_eq(snapshot.get("body"), "WASD 또는 방향키로 96px 이동", "첫 안내는 실제 PC 이동 거리와 키를 알려준다")
	_runner.assert_eq(snapshot.get("target_names", []), [], "데스크톱 안내는 존재하지 않는 터치 위젯을 가리키지 않는다")

	player.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_desktop_actions_match_pc_control_scheme() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var player := StubIntegratedInputPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", null, null, player)
	onboarding.call("start")
	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	var attack_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(attack_snapshot.get("body"), "좌클릭으로 가까운 적을 공격", "기본공격 안내는 PC 좌클릭만 알려준다")
	onboarding.call("record_action", &"attack_executed")
	var dash_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(dash_snapshot.get("body"), "SPACE로 짧게 회피", "대쉬 안내는 PC 기본 SPACE를 알려준다")
	onboarding.call("record_action", &"dash_started")
	var power_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")
	_runner.assert_eq(power_snapshot.get("body"), "SPACE 직후 좌클릭으로 강공격", "강공격 안내는 대쉬와 공격의 실제 PC 키를 조합한다")

	player.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_desktop_guidance_centers_hint_without_empty_spotlight() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var player := StubIntegratedInputPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", null, null, player)
	onboarding.call("start")
	var contract: Dictionary = onboarding.call("get_visual_contract")
	var spotlight := onboarding.get_node_or_null("Root/SpotlightFrame") as Control
	var hint_panel := onboarding.get_node_or_null("Root/HintPanel") as Control

	_runner.assert_false(bool(contract.get("uses_dim_cutout", true)), "데스크톱 안내는 존재하지 않는 터치 대상용 cutout을 만들지 않는다")
	_runner.assert_not_null(spotlight, "온보딩은 스포트라이트 노드를 유지한다")
	if spotlight != null:
		_runner.assert_false(spotlight.visible, "데스크톱에서는 빈 스포트라이트를 숨긴다")
	_runner.assert_not_null(hint_panel, "온보딩은 키 안내 패널을 유지한다")
	if hint_panel != null:
		var viewport_center := onboarding.get_viewport().get_visible_rect().get_center()
		_runner.assert_true(hint_panel.get_global_rect().has_point(viewport_center), "데스크톱 키 안내는 화면 중앙에서 바로 읽힌다")

	player.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_hint_children_do_not_capture_gameplay_mouse() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)

	var hint_text := onboarding.get_node_or_null("Root/HintPanel/HintText") as Control
	var title_label := onboarding.get_node_or_null("Root/HintPanel/HintText/TitleLabel") as Control
	var body_label := onboarding.get_node_or_null("Root/HintPanel/HintText/BodyLabel") as Control
	_runner.assert_not_null(hint_text, "온보딩 힌트 컨테이너가 존재한다")
	_runner.assert_not_null(title_label, "온보딩 제목이 존재한다")
	_runner.assert_not_null(body_label, "온보딩 본문이 존재한다")
	for control: Control in [hint_text, title_label, body_label]:
		if control != null:
			_runner.assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s는 gameplay 좌클릭을 가로막지 않는다" % control.name)

	onboarding.queue_free()


func test_ingame_control_onboarding_touch_guidance_survives_temporary_modal_hiding() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := _create_visible_touch_controls()
	var onboarding := script.new() as CanvasLayer
	add_child(onboarding)

	onboarding.call("configure", touch, null, null)
	onboarding.call("start")
	_runner.assert_eq(onboarding.call("get_current_step_snapshot").get("input_mode"), &"touch", "모바일 온보딩은 touch 모드로 시작한다")
	touch.visible = false
	var hidden_snapshot: Dictionary = onboarding.call("get_current_step_snapshot")

	_runner.assert_eq(hidden_snapshot.get("input_mode"), &"touch", "모달이 터치 UI를 잠시 숨겨도 안내 모드는 바뀌지 않는다")
	_runner.assert_eq(hidden_snapshot.get("body"), "왼쪽 스틱으로 96px 이동", "모달 중에도 모바일 조작 문구를 유지한다")
	_runner.assert_eq(hidden_snapshot.get("target_names", []), ["Joystick"], "모달 중에도 현재 터치 단계 계약을 유지한다")

	touch.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_advances_from_player_integrated_input_without_touch_controls() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var player := StubIntegratedInputPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", null, null, player)
	onboarding.call("start")
	onboarding.call("_process", 0.016)
	player.position = Vector2(96.0, 0.0)
	onboarding.call("_process", 0.016)
	_assert_onboarding_step(onboarding, &"attack", [])
	player.emit_attack()
	_assert_onboarding_step(onboarding, &"dash", [])
	player.emit_dash()
	_assert_onboarding_step(onboarding, &"power_attack", [])
	player.emit_power_attack()
	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])
	onboarding.call("record_action", &"minimap_expanded", {"expanded": true})
	_assert_onboarding_step(onboarding, &"exit", [])
	var exit_spotlight := onboarding.get_node("Root/SpotlightFrame") as Control
	_runner.assert_false(exit_spotlight.visible, "대상이 없는 출구 단계는 빈 spotlight 사각형을 만들지 않는다")
	onboarding.call("record_room_changed", &"combat_1", &"combat")

	_runner.assert_false(bool(onboarding.call("is_active")), "플레이어 성공 신호와 실제 방 전환으로 PC 온보딩을 완료한다")

	player.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_uses_success_signals_when_touch_player_lacks_input_polling_methods() -> void:
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := _create_visible_touch_controls()
	var player := StubPowerAttackPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", touch, null, player)
	onboarding.call("start")
	onboarding.call("_process", 0.016)
	player.position = Vector2(96.0, 0.0)
	onboarding.call("_process", 0.016)
	_assert_onboarding_step(onboarding, &"attack", ["AttackButton"])
	player.emit_attack()
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])
	player.emit_dash()
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])
	player.emit_power_attack()
	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])
	onboarding.call("record_action", &"minimap_expanded", {"expanded": true})
	onboarding.call("record_room_changed", &"combat_1", &"combat")

	_runner.assert_false(bool(onboarding.call("is_active")), "입력 polling 메서드가 없는 액터도 성공 신호로 온보딩을 완료한다")

	touch.queue_free()
	player.queue_free()
	onboarding.queue_free()


func test_touch_controls_initial_visibility_requires_touch_capability_and_enabled_setting() -> void:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)

	_runner.assert_true(touch.has_method("resolve_initial_visibility_for_platform"), "터치 컨트롤은 플랫폼별 초기 표시 정책을 명시적으로 노출한다")
	if touch.has_method("resolve_initial_visibility_for_platform"):
		_runner.assert_true(bool(touch.call("resolve_initial_visibility_for_platform", true, true, false, true)), "네이티브 모바일은 터치 컨트롤을 보인다")
		_runner.assert_true(bool(touch.call("resolve_initial_visibility_for_platform", true, false, true, true)), "Android/iOS 웹도 터치 컨트롤을 보인다")
		_runner.assert_false(bool(touch.call("resolve_initial_visibility_for_platform", true, false, false, true)), "터치 이벤트를 에뮬레이션하는 데스크톱은 컨트롤을 숨긴다")
		_runner.assert_false(bool(touch.call("resolve_initial_visibility_for_platform", false, true, false, true)), "터치 이벤트가 불가능하면 모바일 태그만으로 컨트롤을 보이지 않는다")
		_runner.assert_false(bool(touch.call("resolve_initial_visibility_for_platform", true, true, false, false)), "모바일에서도 설정을 끄면 컨트롤을 숨긴다")
	_runner.assert_false(touch.visible, "headless 데스크톱 기준에서는 터치 컨트롤이 기본 비노출이다")

	touch.queue_free()


func test_ingame_control_onboarding_touch_buttons_require_success_events() -> void:
	_runner.assert_true(ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH), "인게임 조작 온보딩 스크립트가 존재한다")
	if not ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH):
		return
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := _create_visible_touch_controls()
	var onboarding := script.new() as CanvasLayer
	var minimap := Control.new()
	minimap.name = "Minimap"
	minimap.position = Vector2(640.0, 24.0)
	minimap.size = Vector2(260.0, 100.0)
	add_child(minimap)
	add_child(onboarding)

	_runner.assert_true(onboarding.has_method("configure"), "조작 온보딩은 터치 컨트롤을 주입받는다")
	_runner.assert_true(onboarding.has_method("start"), "조작 온보딩은 명시적으로 시작할 수 있다")
	_runner.assert_true(onboarding.has_method("advance_from_input"), "조작 온보딩은 실제 입력 상태로 진행된다")
	_runner.assert_true(onboarding.has_method("get_current_step_snapshot"), "조작 온보딩은 현재 단계 snapshot을 노출한다")
	if not onboarding.has_method("configure") or not onboarding.has_method("start") or not onboarding.has_method("advance_from_input") or not onboarding.has_method("get_current_step_snapshot"):
		touch.queue_free()
		onboarding.queue_free()
		return

	onboarding.call("configure", touch, null, null, minimap)
	onboarding.call("start")
	_assert_onboarding_step(onboarding, &"move", ["Joystick"])
	onboarding.call("advance_from_input", {"move": Vector2.RIGHT, "attack_pressed": true, "dash_pressed": true})
	_assert_onboarding_step(onboarding, &"move", ["Joystick"])
	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	_assert_onboarding_step(onboarding, &"attack", ["AttackButton"])
	onboarding.call("advance_from_input", {"attack_pressed": true})
	_assert_onboarding_step(onboarding, &"attack", ["AttackButton"])
	onboarding.call("record_action", &"attack_executed")
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])
	onboarding.call("advance_from_input", {"dash_pressed": true})
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])
	onboarding.call("record_action", &"dash_started")
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])
	onboarding.call("record_action", &"power_attack_executed")
	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])
	_runner.assert_eq(onboarding.call("get_current_step_snapshot").get("target_rect"), minimap.get_global_rect(), "지도 단계는 외부 minimap Control을 직접 가리킨다")
	onboarding.call("record_action", &"minimap_expanded", {"expanded": true})
	_assert_onboarding_step(onboarding, &"exit", [])
	var touch_exit_spotlight := onboarding.get_node("Root/SpotlightFrame") as Control
	_runner.assert_false(touch_exit_spotlight.visible, "터치 출구 단계도 빈 spotlight 사각형을 만들지 않는다")
	onboarding.call("record_room_changed", &"combat_1", &"combat")
	_runner.assert_false(bool(onboarding.call("is_active")), "실제 성공 이벤트와 방 전환까지 확인하면 온보딩이 끝난다")

	touch.queue_free()
	onboarding.queue_free()
	minimap.queue_free()


func test_ingame_control_onboarding_power_attack_waits_for_actual_player_execution() -> void:
	_runner.assert_true(ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH), "인게임 조작 온보딩 스크립트가 존재한다")
	if not ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH):
		return
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := _create_visible_touch_controls()
	var player := StubPowerAttackPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", touch, null, player)
	onboarding.call("start")
	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	player.emit_attack()
	player.emit_dash()
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])

	onboarding.call("advance_from_input", {"attack_pressed": true, "power_window_active": true})
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])
	_runner.assert_true(bool(onboarding.call("is_active")), "버튼 상태만으로는 강공격 온보딩을 완료하지 않는다")

	player.emit_power_attack()

	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])
	_runner.assert_true(bool(onboarding.call("is_active")), "강공격 성공 뒤에도 지도와 출구 증거를 기다린다")

	touch.queue_free()
	player.queue_free()
	onboarding.queue_free()


func test_ingame_control_onboarding_ignores_power_attack_until_dash_success_step_completes() -> void:
	_runner.assert_true(ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH), "인게임 조작 온보딩 스크립트가 존재한다")
	if not ResourceLoader.exists(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH):
		return
	var script := load(INGAME_CONTROL_ONBOARDING_SCRIPT_PATH) as Script
	var touch := _create_visible_touch_controls()
	var player := StubPowerAttackPlayer.new()
	var onboarding := script.new() as CanvasLayer
	add_child(player)
	add_child(onboarding)

	onboarding.call("configure", touch, null, player)
	onboarding.call("start")
	onboarding.call("record_player_position", Vector2.ZERO)
	onboarding.call("record_player_position", Vector2(96.0, 0.0))
	player.emit_attack()
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])

	player.emit_power_attack()
	_assert_onboarding_step(onboarding, &"dash", ["SkillButton"])
	_runner.assert_true(bool(onboarding.call("is_active")), "대시 성공 전에 온 강공격은 순서를 건너뛰지 않는다")
	player.emit_dash()
	_assert_onboarding_step(onboarding, &"power_attack", ["SkillButton", "AttackButton"])
	player.emit_power_attack()

	_assert_onboarding_step(onboarding, &"minimap", ["Minimap"])

	touch.queue_free()
	player.queue_free()
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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()
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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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
	var touch := _create_visible_touch_controls()

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


func _create_visible_touch_controls() -> CanvasLayer:
	var touch := TouchControlsScene.instantiate()
	add_child(touch)
	touch.visible = true
	return touch


func _screen_touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event
