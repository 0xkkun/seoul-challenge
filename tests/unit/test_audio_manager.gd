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


func test_boss_attack_sfx_is_registered() -> void:
	var stream_path := AudioManager.get_sfx_stream_path(&"boss_attack")

	_runner.assert_true(AudioManager.has_sfx(&"boss_attack"), "boss attack SFX is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/sfx/boss_attack.mp3", "boss attack SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "boss attack SFX resource exists")
	var stream := load(stream_path) as AudioStreamMP3
	_runner.assert_not_null(stream, "boss attack SFX loads as MP3")


func test_wolf_attack_sfx_is_registered() -> void:
	var stream_path := AudioManager.get_sfx_stream_path(&"wolf_attack")

	_runner.assert_true(AudioManager.has_sfx(&"wolf_attack"), "wolf attack SFX is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/sfx/wolf_attack.wav", "wolf attack SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "wolf attack SFX resource exists")
	var stream := load(stream_path) as AudioStreamWAV
	_runner.assert_not_null(stream, "wolf attack SFX loads as WAV")


func test_kumiho_fireball_sfx_is_registered() -> void:
	var stream_path := AudioManager.get_sfx_stream_path(&"kumiho_fireball")

	_runner.assert_true(AudioManager.has_sfx(&"kumiho_fireball"), "kumiho fireball SFX is registered")
	_runner.assert_eq(stream_path, "res://assets/audio/sfx/kumiho_fireball.mp3", "kumiho fireball SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(stream_path), "kumiho fireball SFX resource exists")
	var stream := load(stream_path) as AudioStreamMP3
	_runner.assert_not_null(stream, "kumiho fireball SFX loads as MP3")


func test_movement_sfx_are_registered() -> void:
	var footstep_path := AudioManager.get_sfx_stream_path(&"corridor_footstep")
	var gyeongbokgung_footstep_path := AudioManager.get_sfx_stream_path(&"gyeongbokgung_footstep")
	var dash_path := AudioManager.get_sfx_stream_path(&"dash_wind")

	_runner.assert_true(AudioManager.has_sfx(&"corridor_footstep"), "corridor footstep SFX is registered")
	_runner.assert_eq(footstep_path, "res://assets/audio/sfx/corridor_footstep.wav", "school corridor keeps its existing footstep SFX path")
	_runner.assert_true(ResourceLoader.exists(footstep_path), "corridor footstep SFX resource exists")
	_runner.assert_not_null(load(footstep_path) as AudioStreamWAV, "corridor footstep SFX loads as WAV")

	_runner.assert_true(AudioManager.has_sfx(&"gyeongbokgung_footstep"), "Gyeongbokgung footstep SFX is registered")
	_runner.assert_eq(gyeongbokgung_footstep_path, "res://assets/audio/sfx/gyeongbokgung_footstep.mp3", "Gyeongbokgung footstep SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(gyeongbokgung_footstep_path), "Gyeongbokgung footstep SFX resource exists")
	var gyeongbokgung_stream := load(gyeongbokgung_footstep_path) as AudioStreamMP3
	_runner.assert_not_null(gyeongbokgung_stream, "Gyeongbokgung footstep SFX loads as MP3")
	if gyeongbokgung_stream != null:
		_runner.assert_true(gyeongbokgung_stream.get_length() <= 0.35, "Gyeongbokgung footstep SFX is a short single step")

	_runner.assert_true(AudioManager.has_sfx(&"dash_wind"), "dash wind SFX is registered")
	_runner.assert_eq(dash_path, "res://assets/audio/sfx/dash_wind.wav", "dash wind SFX path is stable")
	_runner.assert_true(ResourceLoader.exists(dash_path), "dash wind SFX resource exists")
	_runner.assert_not_null(load(dash_path) as AudioStreamWAV, "dash wind SFX loads as WAV")


func test_school_reward_and_victory_sfx_are_registered() -> void:
	var expected_paths := {
		AudioManager.SCHOOL_SCENE_PAGE_FLIP: "res://assets/audio/sfx/school_scene_page_flip.mp3",
		AudioManager.QUEST_REWARD_LEVEL_UP: "res://assets/audio/sfx/quest_reward_level_up.mp3",
		AudioManager.RUN_VICTORY: "res://assets/audio/sfx/run_victory.mp3",
	}

	for sfx_id: StringName in expected_paths.keys():
		var stream_path := String(expected_paths[sfx_id])
		_runner.assert_true(AudioManager.has_sfx(sfx_id), "%s SFX is registered" % sfx_id)
		_runner.assert_eq(AudioManager.get_sfx_stream_path(sfx_id), stream_path, "%s SFX path is stable" % sfx_id)
		_runner.assert_true(ResourceLoader.exists(stream_path), "%s audio resource exists" % sfx_id)
		_runner.assert_not_null(load(stream_path) as AudioStreamMP3, "%s SFX loads as MP3" % sfx_id)


func test_night_intro_trailer_transition_sfx_are_registered() -> void:
	var expected_paths := {
		AudioManager.NIGHT_INTRO_TRANSITION_AB: "res://assets/audio/sfx/night_intro_transition_ab.mp3",
		AudioManager.NIGHT_INTRO_TRANSITION_BC: "res://assets/audio/sfx/night_intro_transition_bc.mp3",
		AudioManager.NIGHT_INTRO_TRANSITION_CD: "res://assets/audio/sfx/night_intro_transition_cd.mp3",
	}

	for sfx_id: StringName in expected_paths.keys():
		var stream_path := String(expected_paths[sfx_id])
		_runner.assert_true(AudioManager.has_sfx(sfx_id), "%s trailer transition SFX is registered" % sfx_id)
		_runner.assert_eq(AudioManager.get_sfx_stream_path(sfx_id), stream_path, "%s trailer transition SFX path is stable" % sfx_id)
		_runner.assert_true(ResourceLoader.exists(stream_path), "%s trailer transition SFX resource exists" % sfx_id)
		_runner.assert_not_null(load(stream_path) as AudioStreamMP3, "%s trailer transition SFX loads as MP3" % sfx_id)


func test_dash_wind_sfx_has_immediate_audible_attack() -> void:
	var dash_path := AudioManager.get_sfx_stream_path(AudioManager.DASH_WIND)

	var first_peak := _wav_peak_in_first_seconds(dash_path, 0.08)

	_runner.assert_true(
		first_peak >= 6000,
		"dash wind SFX must be audible in the first 80ms so it reads with the button press"
	)


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


func test_scene_transition_school_scene_helper_uses_page_flip() -> void:
	SceneTransition._play_school_scene_transition_sfx()

	_runner.assert_eq(
		AudioManager.get_played_sfx(),
		[AudioManager.SCHOOL_SCENE_PAGE_FLIP],
		"school scene transition helper plays the page flip SFX"
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


func _wav_peak_in_first_seconds(path: String, seconds: float) -> int:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return 0
	var sample_rate := 0
	var data_offset := -1
	var data_size := 0
	var offset := 12
	while offset + 8 <= bytes.size():
		var chunk_id := _ascii4(bytes, offset)
		var chunk_size := _u32_le(bytes, offset + 4)
		var chunk_data := offset + 8
		if chunk_id == "fmt " and chunk_size >= 16:
			sample_rate = _u32_le(bytes, chunk_data + 4)
		elif chunk_id == "data":
			data_offset = chunk_data
			data_size = mini(chunk_size, bytes.size() - data_offset)
			break
		offset = chunk_data + chunk_size + (chunk_size % 2)
	if sample_rate <= 0 or data_offset < 0 or data_size <= 0:
		return 0
	var bytes_per_sample := 2
	var samples_to_scan := mini(int(ceil(seconds * float(sample_rate))), data_size / bytes_per_sample)
	var peak := 0
	for sample_index in range(samples_to_scan):
		var sample_offset := data_offset + sample_index * bytes_per_sample
		var sample := _s16_le(bytes, sample_offset)
		peak = maxi(peak, absi(sample))
	return peak


func _ascii4(bytes: PackedByteArray, offset: int) -> String:
	if offset + 4 > bytes.size():
		return ""
	return String.chr(bytes[offset]) + String.chr(bytes[offset + 1]) + String.chr(bytes[offset + 2]) + String.chr(bytes[offset + 3])


func _u32_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 4 > bytes.size():
		return 0
	return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16) | (bytes[offset + 3] << 24)


func _s16_le(bytes: PackedByteArray, offset: int) -> int:
	if offset + 2 > bytes.size():
		return 0
	var value := bytes[offset] | (bytes[offset + 1] << 8)
	return value - 65536 if value >= 32768 else value
