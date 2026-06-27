extends Node

const LOBBY_BGM_DEFAULT := &"lobby_bgm_default"
const LOBBY_BGM_ALTERNATE := &"lobby_bgm_alternate"
const SCHOOL_HALLWAY_BGM := &"school_hallway_bgm"
const NIGHT_RUN_SUSPENSE_BGM := &"night_run_suspense_bgm"
const SCHOOL_BELL_TRANSITION_FRONT := &"school_bell_transition_front"
const SCHOOL_BELL_TRANSITION_BACK := &"school_bell_transition_back"
const SCHOOL_SCENE_PAGE_FLIP := &"school_scene_page_flip"
const QUEST_REWARD_LEVEL_UP := &"quest_reward_level_up"
const RUN_VICTORY := &"run_victory"
const UI_BUTTON_PRESS := &"ui_button_press"
const BAT_SWING := &"bat_swing"
const BAT_HIT := &"bat_hit"
const BOSS_ATTACK := &"boss_attack"
const WOLF_ATTACK := &"wolf_attack"
const KUMIHO_FIREBALL := &"kumiho_fireball"
const CORRIDOR_FOOTSTEP := &"corridor_footstep"
const GYEONGBOKGUNG_FOOTSTEP := &"gyeongbokgung_footstep"
const DASH_WIND := &"dash_wind"
const NIGHT_INTRO_TRANSITION_AB := &"night_intro_transition_ab"
const NIGHT_INTRO_TRANSITION_BC := &"night_intro_transition_bc"
const NIGHT_INTRO_TRANSITION_CD := &"night_intro_transition_cd"
const NIGHT_INTRO_TRANSITION := &"night_intro_transition"
const NIGHT_INTRO_TRANSITION_C := &"night_intro_transition_c"
const SESSION_TRANSITION_SFX_IDS: Array[StringName] = [
	SCHOOL_BELL_TRANSITION_FRONT,
	SCHOOL_BELL_TRANSITION_BACK,
]

const _BGM_STREAM_PATHS := {
	LOBBY_BGM_DEFAULT: "res://assets/audio/bgm/lobby_bgm_default.ogg",
	LOBBY_BGM_ALTERNATE: "res://assets/audio/bgm/lobby_bgm_alternate.ogg",
	SCHOOL_HALLWAY_BGM: "res://assets/audio/bgm/school_hallway_bgm.ogg",
	NIGHT_RUN_SUSPENSE_BGM: "res://assets/audio/bgm/night_run_suspense_bgm.ogg",
}
# BGM ids that use the fade-out → silent gap → fade-in loop so repeat listens
# breathe instead of hard-looping. Others (e.g. SCHOOL_HALLWAY_BGM) keep a seamless engine loop.
const _FADE_LOOP_BGM_IDS: Array[StringName] = [
	LOBBY_BGM_DEFAULT,
	LOBBY_BGM_ALTERNATE,
	NIGHT_RUN_SUSPENSE_BGM,
]
const _SFX_STREAM_PATHS := {
	SCHOOL_BELL_TRANSITION_FRONT: "res://assets/audio/sfx/school_bell_transition_front.wav",
	SCHOOL_BELL_TRANSITION_BACK: "res://assets/audio/sfx/school_bell_transition_back.wav",
	SCHOOL_SCENE_PAGE_FLIP: "res://assets/audio/sfx/school_scene_page_flip.mp3",
	QUEST_REWARD_LEVEL_UP: "res://assets/audio/sfx/quest_reward_level_up.mp3",
	RUN_VICTORY: "res://assets/audio/sfx/run_victory.mp3",
	UI_BUTTON_PRESS: "res://assets/audio/sfx/ui_button_press.mp3",
	BAT_SWING: "res://assets/audio/sfx/bat_swing.mp3",
	BAT_HIT: "res://assets/audio/sfx/bat_hit.wav",
	BOSS_ATTACK: "res://assets/audio/sfx/boss_attack.mp3",
	WOLF_ATTACK: "res://assets/audio/sfx/wolf_attack.wav",
	KUMIHO_FIREBALL: "res://assets/audio/sfx/kumiho_fireball.mp3",
	CORRIDOR_FOOTSTEP: "res://assets/audio/sfx/corridor_footstep.wav",
	GYEONGBOKGUNG_FOOTSTEP: "res://assets/audio/sfx/gyeongbokgung_footstep.mp3",
	DASH_WIND: "res://assets/audio/sfx/dash_wind.wav",
	NIGHT_INTRO_TRANSITION_AB: "res://assets/audio/sfx/night_intro_transition_ab.mp3",
	NIGHT_INTRO_TRANSITION_BC: "res://assets/audio/sfx/night_intro_transition_bc.mp3",
	NIGHT_INTRO_TRANSITION_CD: "res://assets/audio/sfx/night_intro_transition_cd.mp3",
	NIGHT_INTRO_TRANSITION: "res://assets/audio/sfx/night_intro_transition.mp3",
	NIGHT_INTRO_TRANSITION_C: "res://assets/audio/sfx/night_intro_transition_c.mp3",
}

const BGM_VOLUME_DB := 0.0
const BGM_SILENT_DB := -40.0
const BGM_FADE_IN_SEC := 1.5
const BGM_FADE_OUT_SEC := 2.0
const BGM_GAP_SEC := 3.0
## 나레이션/연출 위에서 배경음을 확 낮출 때 적용하는 오프셋(덕킹).
const BGM_DUCK_DB := -20.0

var _played_sfx: Array[StringName] = []
var _stopped_sfx: Array[StringName] = []
var _current_bgm: StringName = &""
var _current_bgm_path := ""
var _bgm_player: AudioStreamPlayer
var _bgm_fade_tween: Tween
var _bgm_loop_token := 0
var _bgm_cycle_active := false
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_rng := RandomNumberGenerator.new()
var _bgm_ducked := false


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
	player.set_meta("sfx_id", id)
	add_child(player)
	_sfx_players.append(player)
	player.finished.connect(_on_sfx_player_finished.bind(player), CONNECT_ONE_SHOT)
	player.play()


func stop_sfx(id: StringName) -> void:
	if id == &"":
		return
	_stopped_sfx.append(id)
	for player: AudioStreamPlayer in _sfx_players.duplicate():
		if not is_instance_valid(player):
			_sfx_players.erase(player)
			continue
		if StringName(player.get_meta("sfx_id", &"")) == id:
			_stop_sfx_player(player)


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
		player.volume_db = _bgm_active_db()
		player.play()


# Loops the BGM with a fade-out → silent gap → fade-in instead of a hard seam.
# Manual looping (stream loop disabled) avoids the audible click at the loop point.
func _run_bgm_cycle(player: AudioStreamPlayer, token: int) -> void:
	_bgm_cycle_active = true
	var length := player.stream.get_length()
	while token == _bgm_loop_token:
		player.volume_db = BGM_SILENT_DB
		player.play()
		_fade_bgm(player, _bgm_active_db(), BGM_FADE_IN_SEC)
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


## 덕킹 여부에 따른 현재 BGM 목표 볼륨(루프 페이드 타깃에 사용).
func _bgm_active_db() -> float:
	return BGM_VOLUME_DB + (BGM_DUCK_DB if _bgm_ducked else 0.0)


## 배경음을 확 낮춘다/되돌린다(나레이션·연출용). 루프 페이드 타깃에도 반영되며,
## stop_bgm() 시 자동 해제된다.
func set_bgm_ducked(ducked: bool, duration: float = 0.25) -> void:
	if _bgm_ducked == ducked:
		return
	_bgm_ducked = ducked
	if _bgm_player != null and _bgm_cycle_active and DisplayServer.get_name() != "headless":
		_fade_bgm(_bgm_player, _bgm_active_db(), duration)


func stop_bgm() -> void:
	_current_bgm = &""
	_current_bgm_path = ""
	_bgm_ducked = false
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


func get_stopped_sfx() -> Array[StringName]:
	return _stopped_sfx.duplicate()


func reset() -> void:
	_played_sfx.clear()
	_stopped_sfx.clear()
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
		_stop_sfx_player(player)
	_sfx_players.clear()


func _stop_sfx_player(player: AudioStreamPlayer) -> void:
	_sfx_players.erase(player)
	if not is_instance_valid(player):
		return
	player.stop()
	player.queue_free()


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
