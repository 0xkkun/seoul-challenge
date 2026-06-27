extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	SaveManager.reset_profile()


func test_flag_defaults_to_false_then_persists_within_session() -> void:
	SaveManager.reset_profile()
	_runner.assert_false(
		SaveManager.get_flag(&"seen_night_intro"),
		"unset flag defaults to false"
	)
	_runner.assert_true(
		SaveManager.get_flag(&"seen_night_intro", true),
		"explicit default is honored when flag is unset"
	)
	SaveManager.set_flag(&"seen_night_intro", true)
	_runner.assert_true(
		SaveManager.get_flag(&"seen_night_intro"),
		"set flag reads back as true"
	)


func test_flags_survive_profile_snapshot_round_trip() -> void:
	SaveManager.reset_profile()
	SaveManager.set_flag(&"seen_night_intro", true)
	SaveManager.save_profile(SaveManager.load_profile())
	_runner.assert_true(
		SaveManager.get_flag(&"seen_night_intro"),
		"flags survive a load/save profile round trip"
	)


func test_reset_profile_clears_flags() -> void:
	SaveManager.set_flag(&"seen_night_intro", true)
	SaveManager.reset_profile()
	_runner.assert_false(
		SaveManager.get_flag(&"seen_night_intro"),
		"reset_profile clears one-time flags"
	)
