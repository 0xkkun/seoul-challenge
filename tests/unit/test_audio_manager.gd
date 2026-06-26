extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	AudioManager.reset()


func after_each() -> void:
	AudioManager.reset()


func test_session_transition_school_bell_variants_are_registered() -> void:
	var sfx_ids := AudioManager.get_session_transition_sfx_ids()

	_runner.assert_eq(sfx_ids.size(), 2, "session transition uses two short school bell variants")
	_runner.assert_true(sfx_ids.has(AudioManager.SCHOOL_BELL_TRANSITION_FRONT), "front school bell variant is available")
	_runner.assert_true(sfx_ids.has(AudioManager.SCHOOL_BELL_TRANSITION_BACK), "back school bell variant is available")
	for sfx_id: StringName in sfx_ids:
		_runner.assert_true(AudioManager.has_sfx(sfx_id), "%s is registered as SFX" % sfx_id)
		_runner.assert_true(ResourceLoader.exists(AudioManager.get_sfx_stream_path(sfx_id)), "%s audio resource exists" % sfx_id)


func test_random_session_transition_school_bell_records_one_variant() -> void:
	var sfx_id := AudioManager.play_random_session_transition_sfx()
	var sfx_ids := AudioManager.get_session_transition_sfx_ids()

	_runner.assert_true(sfx_ids.has(sfx_id), "random transition SFX returns one registered school bell variant")
	_runner.assert_eq(AudioManager.get_played_sfx(), [sfx_id], "random transition SFX records the played variant")


func test_scene_transition_school_bell_helper_uses_transition_variants() -> void:
	SceneTransition._play_session_transition_sfx()
	var played_sfx := AudioManager.get_played_sfx()

	_runner.assert_eq(played_sfx.size(), 1, "scene transition helper plays one transition SFX")
	_runner.assert_true(
		AudioManager.get_session_transition_sfx_ids().has(played_sfx[0]),
		"scene transition helper uses a registered school bell variant"
	)
