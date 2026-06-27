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


func test_intro_plate_assets_are_importable() -> void:
	for path: String in NightIntroCutsceneScript.PLATES:
		_runner.assert_true(ResourceLoader.exists(path), "plate asset exists and is imported: %s" % path)


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
