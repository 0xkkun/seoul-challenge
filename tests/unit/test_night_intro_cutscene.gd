extends Node

const NightIntroCutsceneScript := preload("res://scripts/cutscene/night_intro_cutscene.gd")

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


func test_intro_transition_beats_use_ordered_trailer_sfx() -> void:
	var expected_sfx_ids := [
		AudioManager.NIGHT_INTRO_TRANSITION_AB,
		AudioManager.NIGHT_INTRO_TRANSITION_BC,
		AudioManager.NIGHT_INTRO_TRANSITION_CD,
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


func test_intro_transition_sfx_sequence_can_be_played() -> void:
	for i: int in range(1, NightIntroCutsceneScript.BEATS.size()):
		var beat: Dictionary = NightIntroCutsceneScript.BEATS[i]
		var sfx_id := StringName(beat.get("sfx", &""))
		AudioManager.play_sfx(sfx_id)

	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[
			AudioManager.NIGHT_INTRO_TRANSITION_AB,
			AudioManager.NIGHT_INTRO_TRANSITION_BC,
			AudioManager.NIGHT_INTRO_TRANSITION_CD,
		],
		"intro plays trailer transition SFX in A-B, B-C, C-D order"
	)


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
