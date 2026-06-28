extends Node
## 궁 보스 인게임 대사 — 게이팅 로직(PalaceBossIntro)과 전투용 HubDialogueUi 격리 계약을 검증한다.
## 비동기 세션 흐름(pause/스폰 지연)은 기존 스위트에 async 테스트 선례가 없어 수동 검증 대상으로 둔다.

const HUB_DIALOGUE_SCENE := preload("res://scenes/ui/hub_dialogue_ui.tscn")
const PalaceBossIntro := preload("res://resources/dialogue/palace_boss_intro.gd")
const BOSS_TEXTURE := preload("res://resources/dialogue/gyeongbokgung_boss_portrait.tres")

var _runner: Node
var _ui


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()


func after_each() -> void:
	if is_instance_valid(_ui):
		_ui.free()
	_ui = null
	SaveManager.reset_profile()
	ProgressionSystem.reset_for_tests()


# --- 게이팅 로직 (UI 없음, 순수) ---

func test_first_encounter_plays_onboarding_intro() -> void:
	var beats := PalaceBossIntro.collect_beats(false)
	_runner.assert_eq(beats.size(), PalaceBossIntro.INTRO_FIRST.size(), "첫 조우는 온보딩 INTRO_FIRST를 재생한다")
	_runner.assert_eq(String(beats[0]["text"]), "여기까지 걸어 들어온 인간은 오랜만이군.", "첫 줄은 보스 등장 대사다")
	_runner.assert_true(String(beats[2]["text"]).contains("고작 배트 하나로"), "보스 첫 조우는 배트를 얕보는 문구를 사용한다")
	_runner.assert_false(String(beats[2]["text"]).begins_with("그 "), "보스 첫 조우는 어색한 지시어 없이 배트를 언급한다")
	_runner.assert_false(String(beats[2]["text"]).contains("금 간 나무 배트"), "보스 첫 조우는 보상 전 배트 이름으로 회귀하지 않는다")
	_runner.assert_eq(String(beats[beats.size() - 1]["text"]), "좋다. 마지막 문 앞에서 네 힘을 증명해 봐라.", "마지막 줄이 전투 유도라 그 자체로 완결된다")
	_runner.assert_true(PalaceBossIntro.includes_first_intro(false), "첫 조우는 인트로를 포함한다")


func test_repeat_encounter_skips_first_intro() -> void:
	var beats := PalaceBossIntro.collect_beats(true)
	_runner.assert_eq(beats.size(), PalaceBossIntro.BOSS_ENCOUNTER.size(), "재입장은 BOSS_ENCOUNTER만 재생한다")
	_runner.assert_eq(String(beats[0]["text"]), "다시 왔군. 이번엔 도망칠 길도 없다.", "재입장은 보스 대면 대사로 시작한다")
	_runner.assert_false(PalaceBossIntro.includes_first_intro(true), "재입장은 인트로를 포함하지 않는다")


func test_every_beat_is_string_keyed_and_renderable() -> void:
	for beat: Dictionary in PalaceBossIntro.collect_beats(false):
		_runner.assert_true(beat.has("speaker") and beat.has("text") and beat.has("portrait"), "비트는 문자열 키(speaker/text/portrait)를 갖는다")
		_runner.assert_eq(String(beat["speaker"]), "도깨비왕", "궁 보스 대화 화자는 야구부 주장이 아니다")
		_runner.assert_true(beat["portrait"] is Texture2D, "포트레이트는 Texture2D다")
		_runner.assert_true(beat.has("portrait_y") and float(beat["portrait_y"]) < HubDialogueUi.DEFAULT_PORTRAIT_Y, "보스 포트레이트는 대화 바 뒤에 묻히지 않도록 위로 올린다")
		_runner.assert_true(beat.has("portrait_scale"), "보스 포트레이트는 전용 스케일 계약을 갖는다")


func test_boss_portrait_uses_readable_square_crop() -> void:
	var texture := BOSS_TEXTURE as Texture2D
	_runner.assert_eq(texture.get_width(), 112, "보스 포트레이트는 대화창에서 읽히는 상체 크롭 너비를 사용한다")
	_runner.assert_eq(texture.get_height(), 112, "보스 포트레이트는 정사각 크롭이라 HubDialogueUi 프레임 계산에 깨지지 않는다")


func test_flag_constant_matches_save_key() -> void:
	_runner.assert_eq(PalaceBossIntro.FIRST_INTRO_FLAG, &"palace_first_intro_shown", "첫 조우 플래그 키가 고정돼 있다")
	# 게이팅이 실제 SaveManager 플래그와 연동되는지(앱 프로세스 1회).
	_runner.assert_true(PalaceBossIntro.includes_first_intro(SaveManager.get_flag(PalaceBossIntro.FIRST_INTRO_FLAG)), "플래그 미설정 시 첫 조우로 취급한다")
	SaveManager.set_flag(PalaceBossIntro.FIRST_INTRO_FLAG, true)
	_runner.assert_false(PalaceBossIntro.includes_first_intro(SaveManager.get_flag(PalaceBossIntro.FIRST_INTRO_FLAG)), "플래그 설정 후엔 첫 조우가 아니다")


# --- 전투용 HubDialogueUi 격리 (battle_mode) ---

func test_battle_mode_skips_school_auto_content() -> void:
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	_ui.battle_mode = true
	add_child(_ui)
	_runner.assert_false(_ui.is_stage_row_visible(), "battle_mode는 학교 단계 row를 숨긴다")
	_runner.assert_eq(_ui.get_choice_ids().size(), 0, "battle_mode는 야구부 기본 선택지를 채우지 않는다")
	_runner.assert_true(_ui.get_speaker_name().is_empty() or _ui.get_speaker_name() != "야구부 주장" or _ui.get_dialogue_text().is_empty(), "battle_mode는 학교 기본 대사를 자동으로 채우지 않는다")


func test_battle_mode_does_not_subscribe_unlock_changed() -> void:
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	_ui.battle_mode = true
	add_child(_ui)
	var cb := Callable(_ui, "_on_unlock_changed")
	_runner.assert_false(EventBus.unlock_changed.is_connected(cb), "battle_mode는 unlock_changed를 구독하지 않는다(전투 중 해금 팝업 차단)")


func test_school_mode_still_subscribes_unlock_changed() -> void:
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	add_child(_ui)  # battle_mode 미설정 = 학교 모드
	var cb := Callable(_ui, "_on_unlock_changed")
	_runner.assert_true(EventBus.unlock_changed.is_connected(cb), "학교 모드는 기존대로 unlock_changed를 구독한다(회귀 방지)")


func test_battle_dialogue_advances_on_tap_to_continue() -> void:
	_ui = HUB_DIALOGUE_SCENE.instantiate()
	_ui.battle_mode = true
	add_child(_ui)
	var beat := PalaceBossIntro.collect_beats(true)[0]
	var portrait_scale: Vector2 = beat["portrait_scale"]
	_ui.set_dialogue("도깨비왕", String(beat["text"]), "", _ui.PORTRAIT_COLOR, BOSS_TEXTURE, 0, false)
	_ui.set_portrait_layout(portrait_scale, float(beat["portrait_y"]))
	var choices: Array[Dictionary] = [{"id": &"continue", "tap_to_continue": true, "text": _ui.CONTINUE_HINT_TOUCH}]
	_ui.set_choices(choices)
	_runner.assert_eq(_ui.get_portrait_position().y, PalaceBossIntro.BOSS_PORTRAIT_Y, "보스 대화 포트레이트는 전용 y 위치를 적용한다")
	_runner.assert_true(_ui.is_tap_to_continue_active(), "탭하여계속이 활성화돼 시그널이 방출될 수 있다(없으면 소프트락)")
	var seen := {"id": &""}
	_ui.choice_selected.connect(func(cid): seen["id"] = cid)
	_ui.select_choice(&"continue")
	_runner.assert_eq(seen["id"], &"continue", "탭하여계속 선택이 choice_selected를 방출해 다음 비트로 진행한다")
