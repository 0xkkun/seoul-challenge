extends Node
## #56 낮 학교 허브 대화 UI — 가로모드 대화/선택지/해금 팝업 계약을 검증한다.

const HUB_DIALOGUE_SCENE := preload("res://scenes/ui/hub_dialogue_ui.tscn")
const HUB_DIALOGUE_SCRIPT := preload("res://scripts/ui/hub_dialogue_ui.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const PEOPLE2_TEXTURE := preload("res://assets/characters/school/people2.png")

var _runner: Node
# HubDialogueUi 글로벌 클래스 등록(에디터 import) 순서에 의존하지 않도록 타입 주석 없이 둔다.
var _ui


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	add_child(_ui)


func after_each() -> void:
	if is_instance_valid(_ui):
		_ui.free()
	_ui = null
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()


func test_component_uses_landscape_reference_frame() -> void:
	_runner.assert_eq(_ui.get_reference_size(), Vector2(844.0, 390.0), "가로모드 기준 프레임을 노출한다")


func test_unlock_popup_sits_above_dialogue_bar_in_reference_frame() -> void:
	var popup_rect: Rect2 = _ui.get_unlock_popup_reference_rect()
	var dialogue_rect: Rect2 = _ui.get_dialogue_bar_reference_rect()
	var unlock_overlay := _ui.get_node("%UnlockOverlay") as Control
	var dialogue_bar := _ui.get_node("%DialogueBar") as PanelContainer

	_runner.assert_true(
		popup_rect.end.y < dialogue_rect.position.y,
		"해금 팝업은 기준 프레임에서 대화 바 위에 있어야 한다"
	)
	_runner.assert_true(
		unlock_overlay.z_index > dialogue_bar.z_index,
		"해금 팝업 오버레이는 대화 바보다 위에 그려져야 한다"
	)


func test_dialogue_content_updates_from_data() -> void:
	_ui.set_dialogue("과학부 선배", "\"이 유리병은 밤마다 혼자 흔들려.\"", "기억: 실험실 싱크대의 물방울")

	_runner.assert_eq(_ui.get_speaker_name(), "과학부 선배", "NPC 이름이 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_dialogue_text(), "\"이 유리병은 밤마다 혼자 흔들려.\"", "대사가 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_memory_text(), "기억: 실험실 싱크대의 물방울", "기억 플레이버 텍스트가 데이터로 갱신된다")


func test_sprite_portrait_uses_texture_without_panel_background() -> void:
	_ui.set_dialogue("반 친구", "낮엔 뛰지 말고, 얘기부터 하자.", "", HUB_DIALOGUE_SCRIPT.PORTRAIT_COLOR, PEOPLE2_TEXTURE, 1, false)

	var dimmer := _ui.get_node("%DialogueDimmer") as ColorRect
	var panel := _ui.get_node("%PortraitPanel") as ColorRect
	var accent := _ui.get_node("%PortraitAccent") as ColorRect
	var sprite := _ui.get_node("%PortraitSprite") as Sprite2D
	var dialogue_bar := _ui.get_node("%DialogueBar") as PanelContainer
	var frame_before := sprite.frame
	_ui.call("_process", 0.7)

	_runner.assert_true(_ui.is_portrait_sprite_visible(), "스프라이트 초상화를 표시한다")
	_runner.assert_eq(_ui.get_portrait_frame_count(), 8, "people2 시트의 8프레임을 초상화 소스로 사용한다")
	_runner.assert_eq(_ui.get_portrait_texture_path(), "res://assets/characters/school/people2.png", "초상화 텍스처 경로를 노출한다")
	_runner.assert_eq(_ui.get_portrait_frame(), 1, "대화 포커스는 눈을 뜬 프레임으로 고정한다")
	_runner.assert_false(_ui.is_portrait_animating(), "대화 포커스는 프레임을 재생하지 않는다")
	_runner.assert_true(panel.color.a <= 0.01, "스프라이트 초상화는 단색 배경 패널을 비운다")
	_runner.assert_false(accent.visible, "스프라이트 초상화는 기존 하단 accent를 숨긴다")
	_runner.assert_eq(sprite.self_modulate, Color(0.94, 0.92, 0.88, 1), "스프라이트 초상화는 복도 배경과 같은 톤으로 눌러준다")
	_runner.assert_true(sprite.z_index > dimmer.z_index, "스프라이트 초상화는 오버레이보다 앞에 그려진다")
	_runner.assert_true(sprite.z_index < dialogue_bar.z_index, "스프라이트 초상화는 대화 바 뒤에 그려진다")
	_runner.assert_eq(sprite.frame, frame_before, "초상화 스프라이트는 대화 중 정적 프레임을 유지한다")


func test_dialogue_overlay_and_stage_row_visibility_are_configurable() -> void:
	_runner.assert_true(_ui.is_dialogue_overlay_visible(), "일반 대화 UI는 배경을 덮는 오버레이를 제공한다")
	_runner.assert_false(_ui.is_dialogue_overlay_modal(), "오버레이는 선택지 버튼 터치를 가로막지 않는다")
	_runner.assert_true(_ui.is_stage_row_visible(), "기본 허브 대화 UI는 단계 행을 표시한다")

	_ui.set_stage_row_visible(false)
	_runner.assert_false(_ui.is_stage_row_visible(), "씬 목적에 맞지 않는 단계 행은 숨길 수 있다")


func test_nameplate_does_not_overlap_stage_row() -> void:
	var name_label := _ui.get_node("%NameLabel") as Label
	var stage_row := _ui.get_node("%StageRow") as HBoxContainer

	_runner.assert_true(name_label.offset_right <= stage_row.offset_left, "이름표는 스테이지 행 시작 전에서 끝난다")


func test_choice_buttons_keep_mobile_touch_size() -> void:
	var choices: Array[Dictionary] = [
		{"id": &"next", "text": HUB_DIALOGUE_SCRIPT.CONTINUE_HINT_TOUCH, "tap_to_continue": true, "test_id": "dialogue.next_button", "uat_action": "dialogue.next"},
		{"id": &"close", "text": "나가기", "emphasized": true, "test_id": "dialogue.close_button", "uat_action": "dialogue.close"},
	]
	_ui.set_choices(choices)

	var first_button := _ui.get_node("%ChoiceRow").get_child(0) as Button
	var second_button := _ui.get_node("%ChoiceRow").get_child(1) as Button
	_runner.assert_eq(first_button.custom_minimum_size.y, 28.0, "탭 진행 힌트는 두꺼운 버튼처럼 보이지 않는다")
	_runner.assert_eq(first_button.size_flags_horizontal, Control.SIZE_SHRINK_END, "선택 버튼은 행 전체를 채우지 않는다")
	_runner.assert_eq(first_button.mouse_filter, Control.MOUSE_FILTER_IGNORE, "탭 진행 힌트는 화면 탭 진행을 가로막지 않는다")
	_runner.assert_eq(first_button.get_meta("test_id"), "dialogue.next_button", "선택 버튼은 안정적인 test id를 노출한다")
	_runner.assert_eq(second_button.get_meta("uat_action"), "dialogue.close", "선택 버튼은 좌표 대신 액션 id로 누를 수 있다")


func test_tap_to_continue_choice_advances_from_any_dialogue_tap() -> void:
	var selected_ids: Array[StringName] = []
	_ui.choice_selected.connect(func(choice_id: StringName) -> void: selected_ids.append(choice_id))
	_ui.visible = true
	var choices: Array[Dictionary] = [
		{"id": &"next", "text": HUB_DIALOGUE_SCRIPT.CONTINUE_HINT_TOUCH, "tap_to_continue": true},
	]
	_ui.set_choices(choices)

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(24.0, 24.0)
	_ui.call("_input", event)

	_runner.assert_eq(selected_ids, [&"next"], "탭 진행 대화는 버튼 좌표가 아니라 화면 탭으로 진행된다")


func test_dialogue_bar_uses_inset_rule_without_outer_border() -> void:
	var dialogue_bar := _ui.get_node("%DialogueBar") as PanelContainer
	var panel_style := dialogue_bar.get_theme_stylebox("panel") as StyleBoxFlat
	var top_rule := _ui.get_node("%DialogueTopRule") as ColorRect
	var insets := MobileSafeArea.landscape_minimum_insets()

	_runner.assert_not_null(panel_style, "대화 패널 스타일을 제공한다")
	if panel_style != null:
		_runner.assert_eq(panel_style.get_border_width(SIDE_TOP), 0, "대화 패널 상단 바깥 테두리를 쓰지 않는다")
		_runner.assert_eq(panel_style.get_border_width(SIDE_BOTTOM), 0, "대화 패널 하단 바깥 테두리를 쓰지 않는다")
	_runner.assert_eq(dialogue_bar.offset_left, insets["left"], "대화 바는 좌측 가로폰 safe-area 안쪽에서 시작한다")
	_runner.assert_eq(dialogue_bar.offset_right, -float(insets["right"]), "대화 바는 우측 가로폰 safe-area 안쪽에서 끝난다")
	_runner.assert_eq(dialogue_bar.offset_bottom, -float(insets["bottom"]), "대화 바는 홈 인디케이터 위에 뜬다")
	_runner.assert_true(top_rule.size.y >= 0.0, "대화 패널 내부 구분선 노드를 제공한다")


func test_choice_row_is_anchored_to_dialogue_end() -> void:
	var choice_row := _ui.get_node("%ChoiceRow") as HBoxContainer
	var insets := MobileSafeArea.landscape_minimum_insets()

	_runner.assert_eq(choice_row.anchor_left, 1.0, "선택지 행은 우측 기준으로 배치한다")
	_runner.assert_eq(choice_row.anchor_right, 1.0, "선택지 행은 우측 끝에 고정된다")
	_runner.assert_eq(choice_row.offset_right, -float(insets["right"]), "선택지 행은 가로폰 우측 safe-area를 피한다")


func test_stage_row_tracks_completed_current_and_locked_states() -> void:
	_ui.set_stage(2)

	_runner.assert_eq(_ui.get_stage_state(1), HUB_DIALOGUE_SCRIPT.STAGE_STATE_COMPLETED, "이전 단계는 완료 상태")
	_runner.assert_eq(_ui.get_stage_state(2), HUB_DIALOGUE_SCRIPT.STAGE_STATE_CURRENT, "현재 단계는 강조 상태")
	_runner.assert_eq(_ui.get_stage_state(3), HUB_DIALOGUE_SCRIPT.STAGE_STATE_LOCKED, "미래 단계는 잠김 상태")


func test_baseball_unlock_event_updates_stage_and_popup() -> void:
	EventBus.emit_unlock_changed({
		"friend_id": &"baseball_captain",
		"unlocks": [&"baseball_stage_3", &"awakened_bat"],
		"club_stages": {&"baseball": 3},
	})

	_runner.assert_eq(_ui.get_current_stage(), 3, "야구부 정화 후 stage 3으로 갱신")
	_runner.assert_eq(_ui.get_stage_state(3), HUB_DIALOGUE_SCRIPT.STAGE_STATE_CURRENT, "stage 3이 현재 보상 상태")
	_runner.assert_true(_ui.is_unlock_visible(), "각성 배트 해금 팝업을 표시")
	_runner.assert_eq(_ui.get_unlock_items()[0]["name"], "마지막 시즌의 배트", "각성 배트 아이템명을 표시")


func test_stage3_only_unlock_does_not_show_bat_popup() -> void:
	# #243 회귀 가드: 정화 시점 payload(baseball_stage_3 단독, 강화배트 없음)로는 배트 팝업이 뜨면 안 된다.
	# 정화/언락 분리 — 누가 팝업 조건을 stage_3 까지 되돌리면 이 테스트가 잡는다.
	EventBus.emit_unlock_changed({
		"friend_id": &"baseball_captain",
		"unlocks": [&"baseball_stage_3"],
		"club_stages": {&"baseball": 3},
	})

	_runner.assert_eq(_ui.get_current_stage(), 3, "stage 3 으로는 갱신")
	_runner.assert_false(_ui.is_unlock_visible(), "강화배트 없는 payload 로는 배트 팝업을 띄우지 않는다")


func test_choices_are_horizontal_models_and_emit_selected_id() -> void:
	var selected_ids: Array[StringName] = []
	_ui.choice_selected.connect(func(choice_id: StringName) -> void: selected_ids.append(choice_id))
	var choices: Array[Dictionary] = [
		{"id": &"ask", "text": "물어보기"},
		{"id": &"accept", "text": "받기", "emphasized": true},
	]
	_ui.set_choices(choices)

	_runner.assert_eq(_ui.get_choice_ids(), [&"ask", &"accept"], "선택지는 좌우 순서로 유지된다")
	_runner.assert_eq(_ui.get_choice_texts(), ["물어보기", "받기"], "선택지 문구를 데이터로 보관한다")
	_runner.assert_true(_ui.is_choice_emphasized(&"accept"), "받기 선택지를 강조할 수 있다")

	_ui.select_choice(&"accept")
	_runner.assert_eq(selected_ids, [&"accept"], "선택 시 id 신호를 방출한다")


func test_unlock_popup_tracks_reward_items() -> void:
	var items: Array[Dictionary] = [
		{"id": &"memory_fragment", "name": "기억 조각", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BALL_COLOR},
		{"id": &"cracked_bat", "name": "금 간 나무 배트", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BAT_COLOR},
	]

	_ui.show_unlock("새 기억", "2단계 보상", items)

	_runner.assert_true(_ui.is_unlock_visible(), "받기 이후 중앙 해금 팝업을 표시한다")
	_runner.assert_eq(_ui.get_unlock_items().size(), 2, "해금 아이템 두 개를 표시할 수 있다")
	_runner.assert_eq(_ui.get_unlock_items()[0]["name"], "기억 조각", "첫 번째 해금 아이템 이름 보관")
	_runner.assert_eq(_ui.get_unlock_items()[1]["name"], "금 간 나무 배트", "두 번째 해금 아이템 이름 보관")

	_ui.hide_unlock()
	_runner.assert_false(_ui.is_unlock_visible(), "해금 팝업을 숨길 수 있다")


func test_unlock_hidden_only_emits_after_visible_popup_is_hidden() -> void:
	var hidden_count := [0]
	_ui.unlock_hidden.connect(func() -> void: hidden_count[0] += 1)

	_ui.hide_unlock()
	_runner.assert_eq(hidden_count[0], 0, "초기 비표시 상태를 숨겨도 dismiss 신호를 보내지 않는다")

	var items: Array[Dictionary] = [
		{"id": &"memory_fragment", "name": "기억 조각", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BALL_COLOR},
	]
	_ui.show_unlock("새 기억", "2단계 보상", items)
	_ui.hide_unlock()
	_runner.assert_eq(hidden_count[0], 1, "표시된 팝업을 닫을 때만 dismiss 신호를 보낸다")
