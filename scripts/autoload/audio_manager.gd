extends Node

const LOBBY_BGM_DEFAULT := &"lobby_bgm_default"
const LOBBY_BGM_ALTERNATE := &"lobby_bgm_alternate"
const SCHOOL_BELL_TRANSITION_FRONT := &"school_bell_transition_front"
const SCHOOL_BELL_TRANSITION_BACK := &"school_bell_transition_back"
const SESSION_TRANSITION_SFX_IDS: Array[StringName] = [
	SCHOOL_BELL_TRANSITION_FRONT,
	SCHOOL_BELL_TRANSITION_BACK,
]

const _BGM_STREAM_PATHS := {
	LOBBY_BGM_DEFAULT: "res://assets/audio/bgm/lobby_bgm_default.wav",
	LOBBY_BGM_ALTERNATE: "res://assets/audio/bgm/lobby_bgm_alternate.wav",
}
const _SFX_STREAM_PATHS := {
	SCHOOL_BELL_TRANSITION_FRONT: "res://assets/audio/sfx/school_bell_transition_front.wav",
	SCHOOL_BELL_TRANSITION_BACK: "res://assets/audio/sfx/school_bell_transition_back.wav",
}

var _played_sfx: Array[StringName] = []
var _current_bgm: StringName = &""
var _current_bgm_path := ""
var _bgm_player: AudioStreamPlayer
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
		if _bgm_player != null:
			_bgm_player.stop()
		return

	var player := _ensure_bgm_player()
	if same_bgm and player.playing:
		return

	if stream_path == "":
		player.stop()
		player.stream = null
		return

	var stream := load(stream_path) as AudioStream
	if stream == null:
		push_error("BGM stream is missing: %s" % stream_path)
		player.stop()
		player.stream = null
		return

	player.stream = _prepare_bgm_stream(stream)
	player.play()


func stop_bgm() -> void:
	_current_bgm = &""
	_current_bgm_path = ""
	if _bgm_player != null:
		_bgm_player.stop()
		_bgm_player.stream = null


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
	return _bgm_player != null and _bgm_player.playing


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
	_bgm_player.finished.connect(_on_bgm_player_finished)
	return _bgm_player


func _prepare_bgm_stream(stream: AudioStream) -> AudioStream:
	var wav_stream := stream as AudioStreamWAV
	if wav_stream == null:
		return stream
	var looped_stream := wav_stream.duplicate() as AudioStreamWAV
	looped_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return looped_stream


func _on_sfx_player_finished(player: AudioStreamPlayer) -> void:
	_sfx_players.erase(player)
	player.queue_free()


func _on_bgm_player_finished() -> void:
	if _current_bgm == &"" or _current_bgm_path == "":
		return
	if not _is_bgm_enabled():
		return
	if _bgm_player != null and _bgm_player.stream != null:
		_bgm_player.play()


func _clear_sfx_players() -> void:
	for player: AudioStreamPlayer in _sfx_players.duplicate():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_players.clear()


func _on_settings_changed(settings: Dictionary) -> void:
	if not bool(settings.get(Settings.KEY_BGM_ENABLED, true)):
		if _bgm_player != null:
			_bgm_player.stop()
		return
	if _current_bgm != &"" and _current_bgm_path != "" and not is_bgm_playing():
		play_bgm(_current_bgm)


func _is_bgm_enabled() -> bool:
	return not has_node("/root/Settings") or Settings.is_bgm_enabled()


func _is_sfx_enabled() -> bool:
	return not has_node("/root/Settings") or Settings.is_sfx_enabled()
