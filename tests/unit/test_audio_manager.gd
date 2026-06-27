extends Node

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Settings.reset_defaults()
	AudioManager.reset()


func after_each() -> void:
	AudioManager.reset()
	Settings.reset_defaults()


func test_session_transition_school_bell_variants_are_registered() -> void:
	var sfx_ids := AudioManager.get_session_transition_sfx_ids()

	_runner.assert_eq(sfx_ids.size(), 2, "session transition uses two short school bell variants")
	_runner.assert_true(sfx_ids.has(AudioManager.SCHOOL_BELL_TRANSITION_FRONT), "front school bell variant is available")
	_runner.assert_true(sfx_ids.has(AudioManager.SCHOOL_BELL_TRANSITION_BACK), "back school bell variant is available")
	for sfx_id: StringName in sfx_ids:
		_runner.assert_true(AudioManager.has_sfx(sfx_id), "%s is registered as SFX" % sfx_id)
		_runner.assert_true(ResourceLoader.exists(AudioManager.get_sfx_stream_path(sfx_id)), "%s audio resource exists" % sfx_id)


func test_bat_swing_sfx_is_registered() -> void:
	var stream_path := AudioManager.get_sfx_stream_path(&"bat_swing")

	_runner.assert_true(AudioManager.has_sfx(&"bat_swing"), "bat swing SFX is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/sfx/bat_swing.mp3", "bat swing SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "bat swing SFX resource exists")
	var stream := load(stream_path) as AudioStreamMP3
	_runner.assert_not_null(stream, "bat swing SFX loads as MP3")


func test_bat_hit_sfx_is_registered() -> void:
	var stream_path := AudioManager.get_sfx_stream_path(&"bat_hit")

	_runner.assert_true(AudioManager.has_sfx(&"bat_hit"), "bat hit SFX is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/sfx/bat_hit.wav", "bat hit SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "bat hit SFX resource exists")
	var stream := load(stream_path) as AudioStreamWAV
	_runner.assert_not_null(stream, "bat hit SFX loads as WAV")


func test_school_hallway_bgm_is_registered() -> void:
	var stream_path := AudioManager.get_bgm_stream_path(AudioManager.SCHOOL_HALLWAY_BGM)

	_runner.assert_true(AudioManager.has_bgm(AudioManager.SCHOOL_HALLWAY_BGM), "school hallway BGM is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/bgm/school_hallway_bgm.ogg", "school hallway BGM path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "school hallway BGM resource exists")
	var stream := load(stream_path) as AudioStreamOggVorbis
	_runner.assert_not_null(stream, "school hallway BGM loads as OGG Vorbis")
	_runner.assert_true(stream.loop, "school hallway BGM loops as background music")


func test_night_run_suspense_bgm_is_registered_for_gap_loop() -> void:
	var stream_path := AudioManager.get_bgm_stream_path(AudioManager.NIGHT_RUN_SUSPENSE_BGM)

	_runner.assert_true(AudioManager.has_bgm(AudioManager.NIGHT_RUN_SUSPENSE_BGM), "night run suspense BGM is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/bgm/night_run_suspense_bgm.ogg", "night run suspense BGM path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "night run suspense BGM resource exists")
	var source_stream := load(stream_path) as AudioStreamOggVorbis
	_runner.assert_not_null(source_stream, "night run suspense BGM loads as OGG Vorbis")

	AudioManager.play_bgm(AudioManager.NIGHT_RUN_SUSPENSE_BGM)

	var player := AudioManager.get_node_or_null("BgmPlayer") as AudioStreamPlayer
	_runner.assert_not_null(player, "night run suspense BGM prepares a playback stream")
	if player == null:
		return
	var prepared_stream := player.stream as AudioStreamOggVorbis
	_runner.assert_not_null(prepared_stream, "night run suspense BGM keeps the OGG stream type")
	if prepared_stream == null:
		return
	_runner.assert_false(prepared_stream.loop, "night run suspense BGM uses the fade-out/gap/fade-in loop")


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


func test_session_transition_school_bell_stops_lobby_bgm() -> void:
	AudioManager.play_bgm(AudioManager.LOBBY_BGM_DEFAULT)
	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.LOBBY_BGM_DEFAULT, "test starts with lobby BGM selected")

	SceneTransition._play_session_transition_sfx()

	_runner.assert_eq(AudioManager.get_current_bgm(), &"", "session transition clears lobby BGM before the bell")
	_runner.assert_false(AudioManager.is_bgm_playing(), "session transition bell is not masked by lobby BGM")


func test_prepare_bgm_stream_disables_loop_only_for_fade_tracks() -> void:
	var stream := load(AudioManager.get_bgm_stream_path(AudioManager.LOBBY_BGM_DEFAULT)) as AudioStreamOggVorbis
	_runner.assert_true(stream != null, "lobby BGM imports as Ogg Vorbis (loops on Android, unlike a looping WAV)")

	var fade := AudioManager._prepare_bgm_stream(stream, true) as AudioStreamOggVorbis
	_runner.assert_false(fade.loop, "fade-loop tracks disable stream loop so _run_bgm_cycle owns fade-out/gap/fade-in")

	var seamless := AudioManager._prepare_bgm_stream(stream, false) as AudioStreamOggVorbis
	_runner.assert_true(seamless.loop, "non-fade tracks (e.g. school hallway) keep a seamless engine loop")


func test_play_bgm_with_unknown_id_does_not_start_playback() -> void:
	_runner.assert_eq(AudioManager.get_bgm_stream_path(&"does_not_exist"), "", "unknown BGM id resolves to no path")

	AudioManager.play_bgm(&"does_not_exist")

	_runner.assert_false(AudioManager.is_bgm_playing(), "unknown BGM id does not start the fade loop")
	_runner.assert_eq(AudioManager.get_current_bgm_path(), "", "unknown BGM id leaves no active stream path")
