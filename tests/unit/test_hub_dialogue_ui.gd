extends Node
## #56 낮 학교 허브 대화 UI — 가로모드 대화/선택지/해금 팝업 계약을 검증한다.

const HUB_DIALOGUE_SCENE := preload("res://scenes/ui/hub_dialogue_ui.tscn")
const HUB_DIALOGUE_SCRIPT := preload("res://scripts/ui/hub_dialogue_ui.gd")

var _runner: Node
# HubDialogueUi 글로벌 클래스 등록(에디터 import) 순서에 의존하지 않도록 타입 주석 없이 둔다.
var _ui


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	add_child(_ui)


func after_each() -> void:
	if is_instance_valid(_ui):
		_ui.free()
	_ui = null


func test_component_uses_landscape_reference_frame() -> void:
	_runner.assert_eq(_ui.get_reference_size(), Vector2(844.0, 390.0), "가로모드 기준 프레임을 노출한다")


func test_unlock_popup_sits_above_dialogue_bar_in_reference_frame() -> void:
	var popup_rect: Rect2 = _ui.get_unlock_popup_reference_rect()
	var dialogue_rect: Rect2 = _ui.get_dialogue_bar_reference_rect()

	_runner.assert_true(
		popup_rect.end.y < dialogue_rect.position.y,
		"해금 팝업은 기준 프레임에서 대화 바 위에 있어야 한다"
	)


func test_dialogue_content_updates_from_data() -> void:
	_ui.set_dialogue("과학부 선배", "\"이 유리병은 밤마다 혼자 흔들려.\"", "기억: 실험실 싱크대의 물방울")

	_runner.assert_eq(_ui.get_speaker_name(), "과학부 선배", "NPC 이름이 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_dialogue_text(), "\"이 유리병은 밤마다 혼자 흔들려.\"", "대사가 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_memory_text(), "기억: 실험실 싱크대의 물방울", "기억 플레이버 텍스트가 데이터로 갱신된다")


func test_dialogue_overlay_and_stage_row_visibility_are_configurable() -> void:
	_runner.assert_true(_ui.is_dialogue_overlay_visible(), "일반 대화 UI는 배경을 덮는 오버레이를 제공한다")
	_runner.assert_false(_ui.is_dialogue_overlay_modal(), "오버레이는 선택지 버튼 터치를 가로막지 않는다")
	_runner.assert_true(_ui.is_stage_row_visible(), "기본 허브 대화 UI는 단계 행을 표시한다")

	_ui.set_stage_row_visible(false)
	_runner.assert_false(_ui.is_stage_row_visible(), "씬 목적에 맞지 않는 단계 행은 숨길 수 있다")


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

	_runner.assert_not_null(panel_style, "대화 패널 스타일을 제공한다")
	if panel_style != null:
		_runner.assert_eq(panel_style.get_border_width(SIDE_TOP), 0, "대화 패널 상단 바깥 테두리를 쓰지 않는다")
		_runner.assert_eq(panel_style.get_border_width(SIDE_BOTTOM), 0, "대화 패널 하단 바깥 테두리를 쓰지 않는다")
	_runner.assert_true(top_rule.size.y >= 0.0, "대화 패널 내부 구분선 노드를 제공한다")


func test_choice_row_is_anchored_to_dialogue_end() -> void:
	var choice_row := _ui.get_node("%ChoiceRow") as HBoxContainer

	_runner.assert_eq(choice_row.anchor_left, 1.0, "선택지 행은 우측 기준으로 배치한다")
	_runner.assert_eq(choice_row.anchor_right, 1.0, "선택지 행은 우측 끝에 고정된다")
	_runner.assert_true(choice_row.offset_right < 0.0, "선택지 행은 화면 끝에서 안쪽 여백만 둔다")


func test_stage_row_tracks_completed_current_and_locked_states() -> void:
	_ui.set_stage(2)

	_runner.assert_eq(_ui.get_stage_state(1), HUB_DIALOGUE_SCRIPT.STAGE_STATE_COMPLETED, "이전 단계는 완료 상태")
	_runner.assert_eq(_ui.get_stage_state(2), HUB_DIALOGUE_SCRIPT.STAGE_STATE_CURRENT, "현재 단계는 강조 상태")
	_runner.assert_eq(_ui.get_stage_state(3), HUB_DIALOGUE_SCRIPT.STAGE_STATE_LOCKED, "미래 단계는 잠김 상태")


func test_choices_are_horizontal_models_and_emit_selected_id() -> void:
	var selected_ids: Array[StringName] = []
	_ui.choice_selected.connect(func(choice_id: StringName) -> void: selected_ids.append(choice_id))
	var choices: Array[Dictionary] = [
		{"id": &"ask", "text": "물어본다"},
		{"id": &"accept", "text": "받는다", "emphasized": true},
	]
	_ui.set_choices(choices)

	_runner.assert_eq(_ui.get_choice_ids(), [&"ask", &"accept"], "선택지는 좌우 순서로 유지된다")
	_runner.assert_eq(_ui.get_choice_texts(), ["물어본다", "받는다"], "선택지 문구를 데이터로 보관한다")
	_runner.assert_true(_ui.is_choice_emphasized(&"accept"), "받는다 선택지를 강조할 수 있다")

	_ui.select_choice(&"accept")
	_runner.assert_eq(selected_ids, [&"accept"], "선택 시 id 신호를 방출한다")


func test_unlock_popup_tracks_reward_items() -> void:
	var items: Array[Dictionary] = [
		{"id": &"old_baseball", "name": "낡은 야구공", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BALL_COLOR},
		{"id": &"cracked_bat", "name": "금 간 알루미늄 배트", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BAT_COLOR},
	]

	_ui.show_unlock("아이템을 얻었다", "STAGE 2 보상", items)

	_runner.assert_true(_ui.is_unlock_visible(), "받는다 이후 중앙 해금 팝업을 표시한다")
	_runner.assert_eq(_ui.get_unlock_items().size(), 2, "해금 아이템 두 개를 표시할 수 있다")
	_runner.assert_eq(_ui.get_unlock_items()[0]["name"], "낡은 야구공", "첫 번째 해금 아이템 이름 보관")
	_runner.assert_eq(_ui.get_unlock_items()[1]["name"], "금 간 알루미늄 배트", "두 번째 해금 아이템 이름 보관")

	_ui.hide_unlock()
	_runner.assert_false(_ui.is_unlock_visible(), "해금 팝업을 숨길 수 있다")


func test_unlock_hidden_only_emits_after_visible_popup_is_hidden() -> void:
	var hidden_count := [0]
	_ui.unlock_hidden.connect(func() -> void: hidden_count[0] += 1)

	_ui.hide_unlock()
	_runner.assert_eq(hidden_count[0], 0, "초기 비표시 상태를 숨겨도 dismiss 신호를 보내지 않는다")

	var items: Array[Dictionary] = [
		{"id": &"old_baseball", "name": "낡은 야구공", "color": HUB_DIALOGUE_SCRIPT.DEFAULT_BALL_COLOR},
	]
	_ui.show_unlock("아이템을 얻었다", "STAGE 2 보상", items)
	_ui.hide_unlock()
	_runner.assert_eq(hidden_count[0], 1, "표시된 팝업을 닫을 때만 dismiss 신호를 보낸다")
