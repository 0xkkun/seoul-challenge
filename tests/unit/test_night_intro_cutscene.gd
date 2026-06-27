extends Node

const NightIntroCutsceneScript := preload("res://scripts/cutscene/night_intro_cutscene.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


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


func test_second_beat_uses_trailer_transition_sfx() -> void:
	var beat: Dictionary = NightIntroCutsceneScript.BEATS[1]
	var lines: Array = beat["lines"]
	var sfx_id := StringName(beat.get("sfx", &""))
	var sfx_path := AudioManager.get_sfx_stream_path(sfx_id)

	_runner.assert_eq(String(lines[0]["text"]), "나는 매일 밤, 그 아래로 내려간다.", "second beat starts with the nightly descent line")
	_runner.assert_eq(sfx_id, AudioManager.NIGHT_INTRO_TRANSITION, "A-to-B trailer transition uses the trailer SFX")
	_runner.assert_true(AudioManager.has_sfx(sfx_id), "A-to-B trailer transition SFX is registered")
	_runner.assert_true(ResourceLoader.exists(sfx_path), "A-to-B trailer transition SFX resource exists")


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
