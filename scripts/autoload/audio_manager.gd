extends Node

const LOBBY_BGM_DEFAULT := &"lobby_bgm_default"
const LOBBY_BGM_ALTERNATE := &"lobby_bgm_alternate"

const _BGM_STREAM_PATHS := {
	LOBBY_BGM_DEFAULT: "res://assets/audio/bgm/lobby_bgm_default.wav",
	LOBBY_BGM_ALTERNATE: "res://assets/audio/bgm/lobby_bgm_alternate.wav",
}

var _played_sfx: Array[StringName] = []
var _current_bgm: StringName = &""
var _current_bgm_path := ""
var _bgm_player: AudioStreamPlayer


func play_sfx(id: StringName) -> void:
	_played_sfx.append(id)


func play_bgm(id: StringName) -> void:
	var stream_path := get_bgm_stream_path(id)
	var player := _ensure_bgm_player()
	if _current_bgm == id and _current_bgm_path == stream_path and player.playing:
		return

	_current_bgm = id
	_current_bgm_path = stream_path
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


func has_bgm(id: StringName) -> bool:
	return _BGM_STREAM_PATHS.has(id)


func is_bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing


func get_played_sfx() -> Array[StringName]:
	return _played_sfx.duplicate()


func reset() -> void:
	_played_sfx.clear()
	stop_bgm()


func _ensure_bgm_player() -> AudioStreamPlayer:
	if _bgm_player != null:
		return _bgm_player
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	add_child(_bgm_player)
	return _bgm_player


func _prepare_bgm_stream(stream: AudioStream) -> AudioStream:
	var wav_stream := stream as AudioStreamWAV
	if wav_stream == null:
		return stream
	var looped_stream := wav_stream.duplicate() as AudioStreamWAV
	looped_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return looped_stream
