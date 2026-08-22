extends Node

const SPOTLIGHT_SCRIPT_PATH := "res://scripts/ui/purify_onboarding_spotlight.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.free()


func test_purify_onboarding_spotlight_contract_explains_purification() -> void:
	_runner.assert_true(ResourceLoader.exists(SPOTLIGHT_SCRIPT_PATH), "정화 스포트라이트 스크립트가 존재한다")
	if not ResourceLoader.exists(SPOTLIGHT_SCRIPT_PATH):
		return
	var spotlight := (load(SPOTLIGHT_SCRIPT_PATH) as Script).new() as CanvasLayer
	add_child(spotlight)

	_runner.assert_true(spotlight.has_method("get_visual_contract"), "정화 스포트라이트는 테스트 가능한 계약을 노출한다")
	var contract: Dictionary = spotlight.call("get_visual_contract")
	_runner.assert_eq(contract.get("flow"), &"baseball_purify_spotlight", "정화 온보딩 flow id는 안정적이다")
	_runner.assert_eq(bool(contract.get("blocks_gameplay", false)), true, "정화 스포트라이트는 전투를 일시정지하는 안내다")
	_runner.assert_eq(bool(contract.get("uses_dim_cutout", false)), true, "요괴 친구 외 화면을 dim 처리한다")
	_runner.assert_true(float(contract.get("dim_alpha", 1.0)) <= 0.28, "dim은 장면을 읽을 수 있게 낮춘다")
	_runner.assert_eq(contract.get("bracket_style"), &"corners", "정화 대상은 둥근 박스 대신 corner bracket을 쓴다")
	_runner.assert_eq(contract.get("step_ids", []), [&"intro", &"groggy"], "시작 안내와 그로기 안내 두 단계가 있다")
	_runner.assert_eq(contract.get("intro_action", ""), "기절시키기", "첫 안내는 행동어를 분리한다")
	_runner.assert_eq(contract.get("intro_detail", ""), "공격 · 가까이 가면 정화 시작", "첫 안내 detail은 한 줄 chain이다")
	_runner.assert_eq(contract.get("groggy_action", ""), "곁을 지켜 정화", "그로기 안내는 완료 행동을 직접 말한다")
	_runner.assert_eq(contract.get("groggy_detail", ""), "범위를 벗어나면 처음부터", "그로기 안내는 실패 조건을 짧게 말한다")
	_runner.assert_eq(contract.get("continue_placement"), &"bottom_right_chip", "계속 안내는 우하단 chip으로 분리한다")
	_runner.assert_true(bool(contract.get("tap_to_continue", false)), "탭으로 시작/계속한다")


func test_purify_onboarding_spotlight_targets_world_node_and_dismisses_on_tap() -> void:
	var spotlight := (load(SPOTLIGHT_SCRIPT_PATH) as Script).new() as CanvasLayer
	var camera := Camera2D.new()
	var target := Node2D.new()
	target.name = "baseball_captain"
	add_child(camera)
	add_child(target)
	add_child(spotlight)
	camera.global_position = Vector2(100.0, 40.0)
	camera.zoom = Vector2(1.5, 1.5)
	camera.make_current()
	target.global_position = Vector2(132.0, 24.0)

	spotlight.call("configure", camera)
	spotlight.call("show_step", &"intro", "요괴에 씌인 친구를 정화시켜주세요", target)

	var snapshot: Dictionary = spotlight.call("get_snapshot")
	_runner.assert_true(bool(snapshot.get("active", false)), "show_step이 스포트라이트를 활성화한다")
	_runner.assert_eq(snapshot.get("step_id"), &"intro", "현재 단계가 snapshot에 담긴다")
	_runner.assert_eq(snapshot.get("message"), "요괴에 씌인 친구를 정화시켜주세요", "문구가 snapshot에 담긴다")
	_runner.assert_eq(snapshot.get("target_name"), "baseball_captain", "월드 타겟 이름이 snapshot에 담긴다")
	_runner.assert_true((snapshot.get("spotlight_rect", Rect2()) as Rect2).size.x >= 132.0, "스포트라이트는 최소 크기를 유지한다")

	var dismissed := {"seen": false, "step": &""}
	spotlight.dismissed.connect(func(step_id: StringName) -> void:
		dismissed["seen"] = true
		dismissed["step"] = step_id
	)
	_runner.assert_true(bool(spotlight.call("dismiss")), "dismiss가 활성 스포트라이트를 닫는다")
	_runner.assert_true(bool(dismissed["seen"]), "dismiss는 dismissed 시그널을 낸다")
	_runner.assert_eq(dismissed["step"], &"intro", "dismissed 시그널은 닫힌 단계 id를 포함한다")
	_runner.assert_false(bool(spotlight.call("is_active")), "닫힌 뒤 active가 false다")


func test_purify_onboarding_spotlight_uses_desktop_click_copy() -> void:
	var spotlight := (load(SPOTLIGHT_SCRIPT_PATH) as Script).new() as CanvasLayer
	var target := Node2D.new()
	add_child(target)
	add_child(spotlight)

	spotlight.call("show_step", &"intro", "정화 시작", target)
	var hint := spotlight.get_node_or_null("Root/ContinueChip") as Label
	_runner.assert_not_null(hint, "정화 계속 chip이 별도 surface로 존재한다")
	if hint == null:
		return
	_runner.assert_eq(hint.text, "클릭  계속", "데스크톱 정화 시작은 compact click chip을 표시한다")

	spotlight.call("show_step", &"groggy", "정화 계속", target)
	_runner.assert_eq(hint.text, "클릭  계속", "데스크톱 정화 후속 안내도 같은 chip을 쓴다")


func test_purify_onboarding_spotlight_ignores_the_event_frame_that_activated_it() -> void:
	var spotlight := (load(SPOTLIGHT_SCRIPT_PATH) as Script).new() as CanvasLayer
	var target := Node2D.new()
	add_child(target)
	add_child(spotlight)
	spotlight.call("show_step", &"intro", "정화 시작", target)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true

	spotlight.call("_input", mouse)
	_runner.assert_true(bool(spotlight.call("is_active")), "dialogue를 닫은 같은 event frame은 새 spotlight를 dismiss하지 않는다")

	spotlight.set("_shown_process_frame", Engine.get_process_frames() - 1)
	spotlight.call("_input", mouse)
	_runner.assert_false(bool(spotlight.call("is_active")), "다음 frame의 실제 click은 spotlight를 dismiss한다")


func test_purify_onboarding_reduced_motion_starts_in_the_rest_state() -> void:
	Settings.reset_defaults()
	Settings.set_reduced_motion_enabled(true)
	var spotlight := (load(SPOTLIGHT_SCRIPT_PATH) as Script).new() as CanvasLayer
	var target := Node2D.new()
	add_child(target)
	add_child(spotlight)
	spotlight.call("show_step", &"intro", "정화 시작", target)
	var snapshot: Dictionary = spotlight.call("get_snapshot")
	var panel := spotlight.get_node("Root/MessagePanel") as Control

	_runner.assert_true(bool(snapshot.get("reduced_motion", false)), "spotlight reads the reduced-motion setting")
	_runner.assert_eq(snapshot.get("dim_alpha"), 0.14, "reduced motion skips the reveal dim state")
	_runner.assert_eq(panel.modulate, Color.WHITE, "reduced motion renders the final panel opacity immediately")
	_runner.assert_eq(panel.scale, Vector2.ONE, "reduced motion renders the final panel scale immediately")

	Settings.reset_defaults()
