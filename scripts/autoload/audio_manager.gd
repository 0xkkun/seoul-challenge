extends Node

const LOBBY_BGM_DEFAULT := &"lobby_bgm_default"
const LOBBY_BGM_ALTERNATE := &"lobby_bgm_alternate"
const SCHOOL_HALLWAY_BGM := &"school_hallway_bgm"
const SCHOOL_BELL_TRANSITION_FRONT := &"school_bell_transition_front"
const SCHOOL_BELL_TRANSITION_BACK := &"school_bell_transition_back"
const UI_BUTTON_PRESS := &"ui_button_press"
const BAT_SWING := &"bat_swing"
const SESSION_TRANSITION_SFX_IDS: Array[StringName] = [
	SCHOOL_BELL_TRANSITION_FRONT,
	SCHOOL_BELL_TRANSITION_BACK,
]

const _BGM_STREAM_PATHS := {
	LOBBY_BGM_DEFAULT: "res://assets/audio/bgm/lobby_bgm_default.ogg",
	LOBBY_BGM_ALTERNATE: "res://assets/audio/bgm/lobby_bgm_alternate.ogg",
	SCHOOL_HALLWAY_BGM: "res://assets/audio/bgm/school_hallway_bgm.ogg",
}
# BGM ids that use the fade-out → silent gap → fade-in loop (short lobby loops with an
# audible seam). Others (e.g. SCHOOL_HALLWAY_BGM) keep a seamless engine loop.
const _FADE_LOOP_BGM_IDS: Array[StringName] = [
	LOBBY_BGM_DEFAULT,
	LOBBY_BGM_ALTERNATE,
]
const _SFX_STREAM_PATHS := {
	SCHOOL_BELL_TRANSITION_FRONT: "res://assets/audio/sfx/school_bell_transition_front.wav",
	SCHOOL_BELL_TRANSITION_BACK: "res://assets/audio/sfx/school_bell_transition_back.wav",
	UI_BUTTON_PRESS: "res://assets/audio/sfx/ui_button_press.mp3",
	BAT_SWING: "res://assets/audio/sfx/bat_swing.mp3",
}

const BGM_VOLUME_DB := 0.0
const BGM_SILENT_DB := -40.0
const BGM_FADE_IN_SEC := 1.5
const BGM_FADE_OUT_SEC := 2.0
const BGM_GAP_SEC := 3.0

var _played_sfx: Array[StringName] = []
var _current_bgm: StringName = &""
var _current_bgm_path := ""
var _bgm_player: AudioStreamPlayer
var _bgm_fade_tween: Tween
var _bgm_loop_token := 0
var _bgm_cycle_active := false
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_rng := RandomNumberGenerator.new()


func _ready() -> void:
	_sfx_rng.randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_node("/root/EventBus") and not EventBus.settings_changed.is_connected(_on_settings_changed):
		EventBus.settings_changed.connect(_on_settings_changed)


func play_sfx(id: StringName) -> void:
	if not _is_sfx_enabled():
		return
	_played_sfx.append(id)
	var stream_path := get_sfx_stream_path(id)
	if stream_path == "":
		return
	# Skip real playback when there is no audio output (headless CI/tests). The
	# play is still recorded above; spawning a player here would leak its stream
	# because the dummy audio server never releases in-flight playbacks at exit.
	if DisplayServer.get_name() == "headless":
		return
	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_error("SFX stream is missing: %s" % stream_path)
		return
	var player := AudioStreamPlayer.new()
	player.name = "SfxPlayer"
	player.stream = stream
	player.volume_db = -2.0
	add_child(player)
	_sfx_players.append(player)
	player.finished.connect(_on_sfx_player_finished.bind(player), CONNECT_ONE_SHOT)
	player.play()


func play_random_session_transition_sfx() -> StringName:
	var sfx_index := _sfx_rng.randi_range(0, SESSION_TRANSITION_SFX_IDS.size() - 1)
	var sfx_id: StringName = SESSION_TRANSITION_SFX_IDS[sfx_index]
	play_sfx(sfx_id)
	return sfx_id


func play_bgm(id: StringName) -> void:
	var stream_path := get_bgm_stream_path(id)
	var same_bgm := _current_bgm == id and _current_bgm_path == stream_path
	_current_bgm = id
	_current_bgm_path = stream_path
	if not _is_bgm_enabled():
		_halt_bgm_playback()
		return

	if same_bgm and _bgm_cycle_active:
		return

	if stream_path == "":
		_halt_bgm_playback()
		return

	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_error("BGM stream is missing: %s" % stream_path)
		_halt_bgm_playback()
		return

	var fade_loop := id in _FADE_LOOP_BGM_IDS
	var player := _ensure_bgm_player()
	player.stream = _prepare_bgm_stream(stream, fade_loop)
	_bgm_loop_token += 1
	# Skip real playback in headless (CI/tests): the fade loop would leave a suspended
	# timer/tween at exit. State is still tracked so is_bgm_playing() stays correct,
	# matching play_sfx's headless guard.
	if DisplayServer.get_name() == "headless":
		_bgm_cycle_active = true
		return
	if fade_loop:
		_run_bgm_cycle(player, _bgm_loop_token)
	else:
		# Seamless engine loop (stream loop enabled in _prepare_bgm_stream).
		_bgm_cycle_active = true
		player.volume_db = BGM_VOLUME_DB
		player.play()


# Loops the BGM with a fade-out → silent gap → fade-in instead of a hard seam.
# Manual looping (stream loop disabled) avoids the audible click at the loop point.
func _run_bgm_cycle(player: AudioStreamPlayer, token: int) -> void:
	_bgm_cycle_active = true
	var length := player.stream.get_length()
	while token == _bgm_loop_token:
		player.volume_db = BGM_SILENT_DB
		player.play()
		_fade_bgm(player, BGM_VOLUME_DB, BGM_FADE_IN_SEC)
		await get_tree().create_timer(maxf(0.0, length - BGM_FADE_OUT_SEC)).timeout
		if token != _bgm_loop_token:
			return
		_fade_bgm(player, BGM_SILENT_DB, BGM_FADE_OUT_SEC)
		await get_tree().create_timer(BGM_FADE_OUT_SEC).timeout
		if token != _bgm_loop_token:
			return
		player.stop()
		await get_tree().create_timer(BGM_GAP_SEC).timeout
		if token != _bgm_loop_token:
			return


func _fade_bgm(player: AudioStreamPlayer, target_db: float, duration: float) -> void:
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(player, "volume_db", target_db, duration)


func stop_bgm() -> void:
	_current_bgm = &""
	_current_bgm_path = ""
	_halt_bgm_playback()
	if _bgm_player != null:
		_bgm_player.stream = null


# Stops audible playback and cancels the fade/gap loop, but keeps _current_bgm so a
# later re-enable can resume the same track.
func _halt_bgm_playback() -> void:
	_bgm_loop_token += 1
	_bgm_cycle_active = false
	if _bgm_fade_tween != null and _bgm_fade_tween.is_valid():
		_bgm_fade_tween.kill()
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.volume_db = BGM_VOLUME_DB


func get_current_bgm() -> StringName:
	return _current_bgm


func get_current_bgm_path() -> String:
	return _current_bgm_path


func get_bgm_stream_path(id: StringName) -> String:
	return _BGM_STREAM_PATHS.get(id, "")


func get_sfx_stream_path(id: StringName) -> String:
	return _SFX_STREAM_PATHS.get(id, "")


func has_bgm(id: StringName) -> bool:
	return _BGM_STREAM_PATHS.has(id)


func has_sfx(id: StringName) -> bool:
	return _SFX_STREAM_PATHS.has(id)


func get_session_transition_sfx_ids() -> Array[StringName]:
	return SESSION_TRANSITION_SFX_IDS.duplicate()


func is_bgm_playing() -> bool:
	# Active across the whole fade-out → silent gap → fade-in loop, so the BGM is
	# considered "playing" even during the brief gap between repeats.
	return _bgm_cycle_active or (_bgm_player != null and _bgm_player.playing)


func get_played_sfx() -> Array[StringName]:
	return _played_sfx.duplicate()


func reset() -> void:
	_played_sfx.clear()
	_clear_sfx_players()
	stop_bgm()


func _ensure_bgm_player() -> AudioStreamPlayer:
	if _bgm_player != null:
		return _bgm_player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	add_child(_bgm_player)
	return _bgm_player


func _prepare_bgm_stream(stream: AudioStream, fade_loop: bool) -> AudioStream:
	# BGM is Ogg Vorbis (WAV is reserved for one-shot SFX: a looping AudioStreamWAV
	# stops instantly on Android in Godot 4.6.2, producing a silent BGM).
	# fade_loop tracks (lobby) disable the stream loop so _run_bgm_cycle can do
	# fade-out → silent gap → fade-in; other tracks keep a seamless engine loop.
	var ogg_stream := stream as AudioStreamOggVorbis
	if ogg_stream != null:
		ogg_stream.loop = not fade_loop
	return stream


func _on_sfx_player_finished(player: AudioStreamPlayer) -> void:
	_sfx_players.erase(player)
	player.queue_free()


func _clear_sfx_players() -> void:
	for player: AudioStreamPlayer in _sfx_players.duplicate():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_players.clear()


func _on_settings_changed(settings: Dictionary) -> void:
	if not bool(settings.get(Settings.KEY_BGM_ENABLED, true)):
		_halt_bgm_playback()
		return
	if _current_bgm != &"" and _current_bgm_path != "" and not is_bgm_playing():
		play_bgm(_current_bgm)


func _is_bgm_enabled() -> bool:
	return not has_node("/root/Settings") or Settings.is_bgm_enabled()


func _is_sfx_enabled() -> bool:
	return not has_node("/root/Settings") or Settings.is_sfx_enabled()
