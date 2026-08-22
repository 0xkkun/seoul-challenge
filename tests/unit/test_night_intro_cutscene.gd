extends Node

const NightIntroCutsceneScript := preload("res://scripts/cutscene/night_intro_cutscene.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	AudioManager.reset()


func after_each() -> void:
	AudioManager.reset()


func test_intro_has_four_beats_over_four_plates() -> void:
	_runner.assert_eq(NightIntroCutsceneScript.PLATES.size(), 4, "intro uses four background plates")
	_runner.assert_eq(NightIntroCutsceneScript.BEATS.size(), 4, "intro plays four story beats")
	for beat: Dictionary in NightIntroCutsceneScript.BEATS:
		var plate_index := int(beat["plate"])
		_runner.assert_true(
			plate_index >= 0 and plate_index < NightIntroCutsceneScript.PLATES.size(),
			"each beat points at a valid plate index"
		)
		var lines: Array = beat["lines"]
		_runner.assert_true(lines.size() > 0, "each beat shows at least one subtitle line")
		for line: Dictionary in lines:
			_runner.assert_true(
				String(line.get("text", "")).length() > 0,
				"each line carries non-empty subtitle text"
			)


func test_intro_plate_assets_are_importable() -> void:
	for path: String in NightIntroCutsceneScript.PLATES:
		_runner.assert_true(ResourceLoader.exists(path), "plate asset exists and is imported: %s" % path)


func test_intro_narration_clips_are_importable() -> void:
	var clip_count := 0
	for beat: Dictionary in NightIntroCutsceneScript.BEATS:
		for line: Dictionary in beat["lines"]:
			if line.has("audio"):
				clip_count += 1
				_runner.assert_true(
					ResourceLoader.exists(String(line["audio"])),
					"narration clip exists and is imported: %s" % line["audio"]
				)
	_runner.assert_true(clip_count >= 7, "narration covers the voiced lines")


func test_intro_key_lines_keep_expected_voice_clips() -> void:
	_runner.assert_eq(
		_find_audio_for_line("아무도 모르는 길을 따라."),
		"res://assets/audio/night_intro/vo_beat2_2.wav",
		"길 대사는 교체 대상 클립을 유지한다"
	)
	_runner.assert_eq(
		_find_audio_for_line("돌아오지 못할지도 모른다."),
		"res://assets/audio/night_intro/vo_beat3_2.wav",
		"귀환 불가 대사는 교체 대상 클립을 유지한다"
	)


func test_intro_transition_beats_use_ordered_trailer_sfx() -> void:
	var expected_sfx_ids := [
		AudioManager.NIGHT_INTRO_TRANSITION_AB,
		AudioManager.NIGHT_INTRO_TRANSITION_BC,
		AudioManager.NIGHT_INTRO_TRANSITION_AB,
	]

	_runner.assert_false(NightIntroCutsceneScript.BEATS[0].has("sfx"), "first beat starts cold without a transition SFX")
	for i: int in expected_sfx_ids.size():
		var beat_index := i + 1
		var expected_sfx_id: StringName = expected_sfx_ids[i]
		var beat: Dictionary = NightIntroCutsceneScript.BEATS[beat_index]
		var sfx_id := StringName(beat.get("sfx", &""))
		var sfx_path := AudioManager.get_sfx_stream_path(sfx_id)

		_runner.assert_eq(sfx_id, expected_sfx_id, "intro transition beat %d uses the ordered trailer SFX" % beat_index)
		_runner.assert_true(AudioManager.has_sfx(sfx_id), "intro transition beat %d SFX is registered" % beat_index)
		_runner.assert_true(ResourceLoader.exists(sfx_path), "intro transition beat %d SFX resource exists" % beat_index)
	_runner.assert_eq(NightIntroCutsceneScript.FINALE_SFX, AudioManager.NIGHT_INTRO_TRANSITION_CD, "D가 끝난 뒤 기존 C-D 전환 SFX를 피날레로 재생한다")


func test_intro_transition_sfx_sequence_can_be_played() -> void:
	for i: int in range(1, NightIntroCutsceneScript.BEATS.size()):
		var beat: Dictionary = NightIntroCutsceneScript.BEATS[i]
		var sfx_id := StringName(beat.get("sfx", &""))
		AudioManager.play_sfx(sfx_id)
	AudioManager.play_sfx(NightIntroCutsceneScript.FINALE_SFX)

	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[
			AudioManager.NIGHT_INTRO_TRANSITION_AB,
			AudioManager.NIGHT_INTRO_TRANSITION_BC,
			AudioManager.NIGHT_INTRO_TRANSITION_AB,
			AudioManager.NIGHT_INTRO_TRANSITION_CD,
		],
		"intro plays A-B for D entry, then the original C-D SFX after D ends"
	)


func test_intro_transition_sfx_replaces_previous_bed() -> void:
	var intro := NightIntroCutsceneScript.new()
	add_child(intro)

	intro.call("_play_transition_sfx", AudioManager.NIGHT_INTRO_TRANSITION_AB)
	intro.call("_play_transition_sfx", AudioManager.NIGHT_INTRO_TRANSITION_BC)
	intro.call("_play_transition_sfx", AudioManager.NIGHT_INTRO_TRANSITION_CD)

	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[
			AudioManager.NIGHT_INTRO_TRANSITION_AB,
			AudioManager.NIGHT_INTRO_TRANSITION_BC,
			AudioManager.NIGHT_INTRO_TRANSITION_CD,
		],
		"intro still plays trailer transition SFX in order"
	)
	_runner.assert_eq(
		AudioManager.get_stopped_sfx(),
		[
			AudioManager.NIGHT_INTRO_TRANSITION_AB,
			AudioManager.NIGHT_INTRO_TRANSITION_BC,
		],
		"intro stops the previous trailer transition before playing the next one"
	)
	intro.queue_free()


func test_intro_finale_sfx_stops_before_session_handoff() -> void:
	var intro := NightIntroCutsceneScript.new()
	add_child(intro)

	intro.call("_play_transition_sfx", NightIntroCutsceneScript.FINALE_SFX)
	intro.call("_stop_transition_sfx")

	_runner.assert_eq(AudioManager.get_played_sfx(), [AudioManager.NIGHT_INTRO_TRANSITION_CD], "피날레는 기존 C-D 전환 SFX를 재생한다")
	_runner.assert_eq(AudioManager.get_stopped_sfx(), [AudioManager.NIGHT_INTRO_TRANSITION_CD], "세션 handoff 전 피날레 SFX를 정지해 다음 전환음과 겹치지 않는다")
	intro.queue_free()


func test_intro_skip_stops_active_transition_sfx() -> void:
	var intro := NightIntroCutsceneScript.new()
	add_child(intro)

	intro.call("_play_transition_sfx", AudioManager.NIGHT_INTRO_TRANSITION_AB)
	intro.skip()

	_runner.assert_eq(AudioManager.get_stopped_sfx(), [AudioManager.NIGHT_INTRO_TRANSITION_AB], "skip cuts the active trailer transition SFX")
	_runner.assert_true(intro.is_finished(), "skip still marks the cutscene finished")
	intro.queue_free()


func test_skip_finishes_immediately_before_playing() -> void:
	var intro := NightIntroCutsceneScript.new()
	var finished_count := [0]
	intro.finished.connect(func() -> void:
		finished_count[0] += 1
	)
	intro.skip()
	_runner.assert_true(intro.is_finished(), "skip marks the cutscene finished")
	_runner.assert_eq(finished_count[0], 1, "skip emits finished exactly once")
	intro.skip()
	_runner.assert_eq(finished_count[0], 1, "a second skip does not re-emit finished")
	intro.free()


func test_intro_line_auto_advance_covers_audio_and_web_fallbacks() -> void:
	var should_advance := Callable(NightIntroCutsceneScript, "should_advance_line")
	_runner.assert_true(should_advance.is_valid(), "인트로 줄 자동 진행 정책을 노출한다")
	if not should_advance.is_valid():
		return
	_runner.assert_false(
		bool(should_advance.call(true, true, 1.0, 0.0, true)),
		"음성 재생 중 조기 클릭은 버퍼링하되 즉시 끊지 않는다"
	)
	_runner.assert_true(
		bool(should_advance.call(true, false, 2.0, 0.35, false)),
		"음성 종료 grace 뒤 자동 진행한다"
	)
	_runner.assert_true(
		bool(should_advance.call(false, false, 2.2, 0.0, false)),
		"autoplay 차단 시 읽기 fallback으로 진행한다"
	)
	_runner.assert_true(
		bool(should_advance.call(true, true, 4.0, 0.0, false)),
		"고착 음성도 hard max에서 진행한다"
	)


func test_intro_controls_use_desktop_copy_and_mobile_safe_area() -> void:
	var intro := NightIntroCutsceneScript.new()
	add_child(intro)
	var hint := intro.get_node("AdvanceHint") as Label
	var skip_button := intro.get_node("SkipButton") as Button
	var viewport_size := intro.get_viewport().get_visible_rect().size

	_runner.assert_eq(hint.text, "클릭하여 계속", "데스크톱 인트로는 클릭 안내를 표시한다")
	_runner.assert_true(
		MobileSafeArea.meets_landscape_minimum(skip_button.get_global_rect(), viewport_size),
		"인트로 건너뛰기는 top/right safe-area 안쪽에 있다"
	)
	_runner.assert_true(
		MobileSafeArea.meets_landscape_minimum(hint.get_global_rect(), viewport_size),
		"인트로 계속 안내는 right/bottom safe-area 안쪽에 있다"
	)
	intro.free()


func _find_audio_for_line(text: String) -> String:
	for beat: Dictionary in NightIntroCutsceneScript.BEATS:
		for line: Dictionary in beat["lines"]:
			if String(line.get("text", "")) == text:
				return String(line.get("audio", ""))
	return ""
