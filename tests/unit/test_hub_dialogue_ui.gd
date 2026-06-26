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


func test_dialogue_content_updates_from_data() -> void:
	_ui.set_dialogue("과학부 선배", "\"이 유리병은 밤마다 혼자 흔들려.\"", "기억: 실험실 싱크대의 물방울")

	_runner.assert_eq(_ui.get_speaker_name(), "과학부 선배", "NPC 이름이 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_dialogue_text(), "\"이 유리병은 밤마다 혼자 흔들려.\"", "대사가 데이터로 갱신된다")
	_runner.assert_eq(_ui.get_memory_text(), "기억: 실험실 싱크대의 물방울", "기억 플레이버 텍스트가 데이터로 갱신된다")


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
