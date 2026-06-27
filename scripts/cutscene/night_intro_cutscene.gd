class_name NightIntroCutscene
extends CanvasLayer
## 밤 인트로 콜드오픈. 첫 밤 진입 직전 1회 재생되는 시네마틱 인트로.
##
## 거의 검은 화면(경복궁 플레이트를 어둡게 깔고) 중앙에 한글 내레이션을
## 인터타이틀처럼 띄우고 탭으로 진행한다. 마지막 비트는 자막이 사라지며
## 경복궁이 가득 드러난 뒤 암전되고, finished 를 방출해 호출부가 밤 세션으로
## 잇는다. 자막 문구는 BEATS 에 모여 있어 따로 교체하기 쉽다.

signal finished

## SceneTransition 페이드 오버레이(레이어 230)보다 아래로 깔아, 세션 전환 페이드가
## 인트로 위를 덮을 수 있게 한다.
const LAYER_INDEX := 120
const PLATE_FADE_SECONDS := 0.9
const SUBTITLE_FADE_SECONDS := 0.5
const PLATE_FADE_OUT_SECONDS := 0.6
## 내레이션 비트에서 플레이트는 어둡게(거의 검정) 깔려 배경 역할만 한다.
const BACKDROP_ALPHA := 0.4
## 마지막 리빌: 자막이 사라지며 플레이트가 풀로 차오르고, 잠시 머문 뒤 암전.
const REVEAL_RISE_SECONDS := 1.1
const REVEAL_HOLD_SECONDS := 1.6

## 플레이트 순서는 확정 스토리보드 기준: B → A → C → D.
const PLATES: Array[String] = [
	"res://assets/backgrounds/night_intro/night_intro_1.png",
	"res://assets/backgrounds/night_intro/night_intro_2.png",
	"res://assets/backgrounds/night_intro/night_intro_3.png",
	"res://assets/backgrounds/night_intro/night_intro_4.png",
]

## 각 비트: 플레이트 + 자막 줄들. 각 줄은 {text, audio?(나레이션 음성)} 형태.
## 음성이 있는 줄은 자막이 뜰 때 해당 클립을 재생하고, 다음 줄로 넘어가면
## 새 클립으로 교체된다.
const BEATS: Array[Dictionary] = [
	{"plate": 0, "lines": [
		{"text": "도시가 잠들면,", "audio": "res://assets/audio/night_intro/vo_beat1_1.wav"},
		{"text": "어둠 속에서 무언가 깨어난다.", "audio": "res://assets/audio/night_intro/vo_beat1_2.wav"},
	]},
	{"plate": 1, "lines": [
		{"text": "나는 매일 밤, 그 아래로 내려간다.", "audio": "res://assets/audio/night_intro/vo_beat2_1.wav"},
		{"text": "아무도 모르는 길을 따라.", "audio": "res://assets/audio/night_intro/vo_beat2_2.wav", "pre": 0.5},
	]},
	{"plate": 2, "sfx": &"night_intro_transition_c", "lines": [
		{"text": "오늘 밤은…", "audio": "res://assets/audio/night_intro/vo_beat3_1.wav", "pre": 0.6},
		{"text": "돌아오지 못할지도 모른다.", "audio": "res://assets/audio/night_intro/vo_beat3_2.wav"},
	]},
	{"plate": 3, "sfx": &"night_intro_transition", "lines": [
		{"text": "그래도 나는 멈추지 않는다.", "audio": "res://assets/audio/night_intro/vo_beat4_1.wav", "pre": 0.8},
		{"text": "밤이 시작된다.", "audio": "res://assets/audio/night_intro/vo_beat4_2.wav"},
	]},
]

var _plate: TextureRect
var _subtitle: Label
var _hint: Label
var _skip_button: Button
var _narration: AudioStreamPlayer
var _advance_ready := false
var _advance_requested := false
var _skip := false
var _finished := false
var _started := false


func _init() -> void:
	layer = LAYER_INDEX


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_ui()


## play() 가 _ready 보다 먼저 불릴 수 있는 경로(즉시 add_child 후 호출 등)에서도
## UI 가 준비되도록 보장한다. 한 번만 빌드된다.
func _ensure_built() -> void:
	if _plate == null:
		_build_ui()


## 비트 개수(테스트/검증용).
func get_beat_count() -> int:
	return BEATS.size()


## 시퀀스가 끝났는지 여부.
func is_finished() -> bool:
	return _finished


## 콜드오픈을 재생한다. 한 번만 시작되며, 끝나면 finished 를 방출한다.
func play() -> void:
	if _started or _finished:
		return
	_ensure_built()
	_started = true
	# 나레이션 동안 로비 배경음을 확 낮춘다(세션 진입 시 stop_bgm 에서 자동 해제).
	if has_node("/root/AudioManager"):
		AudioManager.set_bgm_ducked(true)
	var last_index := BEATS.size() - 1
	for i: int in BEATS.size():
		if _skip:
			break
		var beat: Dictionary = BEATS[i]
		# 전환음 id(C·D)가 있으면 등장 직전에 깐다. 효과음이 먼저 깔리고,
		# 플레이트가 떠오른 뒤(첫 줄 pre 만큼 더 기다린 뒤) 나레이션이 이어진다.
		var sfx_id := StringName(beat.get("sfx", &""))
		if sfx_id != &"":
			_play_transition_sfx(sfx_id)
		await _show_plate(int(beat["plate"]), BACKDROP_ALPHA)
		for line: Dictionary in beat["lines"]:
			if _skip:
				break
			var pre := float(line.get("pre", 0.0))
			if pre > 0.0:
				_set_subtitle("")
				await _hold(pre)
				if _skip:
					break
			_set_subtitle(String(line["text"]))
			_play_line_narration(line)
			# 자막/힌트가 떠오르는 "그 순간"부터 탭을 받기 시작한다(버퍼링).
			# 페이드가 끝난 뒤에야 무장하던 기존 흐름엔 힌트는 보이는데 탭이
			# 먹지 않는 사각지대가 있었다. 무장만 앞당기고, 실제 진행은 여전히
			# 나레이션이 끝난 뒤로 게이트한다(아래 _wait_for_advance).
			_arm_advance()
			await _fade_subtitle_in()
			await _wait_for_advance()
		if _skip:
			break
		if i == last_index:
			await _reveal_finale()
		else:
			await _fade_plate_out()
	_finish()


## 인트로를 즉시 끝낸다(스킵). 재생 중이 아니어도 안전하게 finished 를 방출한다.
func skip() -> void:
	if _finished:
		return
	_skip = true
	_advance_requested = true
	if not _started:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	finished.emit()


func _build_ui() -> void:
	if _plate != null:
		return
	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.0, 0.0, 0.0, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	_plate = TextureRect.new()
	_plate.name = "Plate"
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# 전체 표시(맞춤): 상하 잘림 없이 플레이트 전체를 보여준다. 16:9보다 넓은
	# 가로 단말에서는 좌우에 자연스러운 검은 여백(시네마틱)이 생긴다.
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_plate)

	# 중앙 내레이션: 거의 검은 화면 한가운데에 인터타이틀처럼 띄운다.
	# 배경 플레이트가 어둡게 깔리고 굵은 아웃라인이 있어 별도 스크림은 불필요.
	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.anchor_left = 0.08
	_subtitle.anchor_right = 0.92
	_subtitle.anchor_top = 0.40
	_subtitle.anchor_bottom = 0.60
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 40)
	_subtitle.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_subtitle.add_theme_constant_override("outline_size", 10)
	_subtitle.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	# 진행 힌트: 작게, 우하단 구석. 자막 흐름을 방해하지 않는다.
	_hint = Label.new()
	_hint.name = "AdvanceHint"
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.93
	_hint.anchor_top = 0.92
	_hint.anchor_bottom = 0.975
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text = "탭해서 계속"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86, 0.55))
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_narration = AudioStreamPlayer.new()
	_narration.name = "Narration"
	add_child(_narration)

	# 트레일러 넘기기(스킵) 버튼: 우측 상단 구석. 인트로 내내 떠 있으며 누르면
	# 즉시 finished 로 잇는다. 자식 순서상 맨 위에 두어 입력을 먼저 받는다.
	_skip_button = Button.new()
	_skip_button.name = "SkipButton"
	_skip_button.anchor_left = 0.80
	_skip_button.anchor_right = 0.975
	_skip_button.anchor_top = 0.03
	_skip_button.anchor_bottom = 0.10
	_skip_button.text = "건너뛰기  ⏭"
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90, 0.85))
	_skip_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	_skip_button.add_theme_color_override("font_pressed_color", Color(0.70, 0.72, 0.78, 1.0))
	_skip_button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_skip_button.add_theme_constant_override("outline_size", 3)
	_skip_button.add_theme_stylebox_override("normal", _skip_button_style(0.22))
	_skip_button.add_theme_stylebox_override("hover", _skip_button_style(0.36))
	_skip_button.add_theme_stylebox_override("pressed", _skip_button_style(0.46))
	_skip_button.pressed.connect(skip)
	add_child(_skip_button)


## 스킵 버튼용 반투명 라운드 배경. 알파만 바꿔 normal/hover/pressed 를 구성한다.
func _skip_button_style(bg_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, bg_alpha)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	return style


## 줄에 음성이 있으면 재생한다(다음 줄에서 새 음성이 play() 로 교체됨).
func _play_line_narration(line: Dictionary) -> void:
	if _narration == null or not line.has("audio"):
		return
	var stream := load(String(line["audio"])) as AudioStream
	if stream == null:
		return
	_narration.stream = stream
	_narration.play()


func _show_plate(plate_index: int, target_alpha: float) -> void:
	var path := PLATES[plate_index]
	_plate.texture = load(path)
	_plate.modulate.a = 0.0
	_set_subtitle("")
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_plate, ^"modulate:a", target_alpha, PLATE_FADE_SECONDS)
	await tween.finished


## 시네마틱 전환음. AudioManager(영속 재생)로 틀어 씬 전환 후 밤 세션까지
## 자연스럽게 이어지게 한다. C·D 비트가 서로 다른 클립을 쓴다.
func _play_transition_sfx(sfx_id: StringName) -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(sfx_id)


## 마지막 비트: 자막이 사라지며 경복궁이 가득 드러나고, 잠시 머문 뒤 암전한다.
func _reveal_finale() -> void:
	# 마지막 리빌에서는 스킵 버튼을 거둬 풀 화면 연출을 가리지 않는다.
	if _skip_button != null:
		_skip_button.visible = false
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(_plate, ^"modulate:a", 1.0, REVEAL_RISE_SECONDS)
	rise.tween_property(_subtitle, ^"modulate:a", 0.0, REVEAL_RISE_SECONDS)
	rise.tween_property(_hint, ^"modulate:a", 0.0, REVEAL_RISE_SECONDS)
	await rise.finished
	await _hold(REVEAL_HOLD_SECONDS)
	if _skip:
		return
	var fade_out := create_tween()
	fade_out.tween_property(_plate, ^"modulate:a", 0.0, PLATE_FADE_OUT_SECONDS)
	await fade_out.finished


func _hold(seconds: float) -> void:
	if _skip or get_tree() == null:
		return
	await get_tree().create_timer(seconds).timeout


func _set_subtitle(text: String) -> void:
	_subtitle.text = text
	_subtitle.modulate.a = 0.0


func _fade_subtitle_in() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_subtitle, ^"modulate:a", 1.0, SUBTITLE_FADE_SECONDS)
	tween.tween_property(_hint, ^"modulate:a", 1.0, SUBTITLE_FADE_SECONDS)
	await tween.finished


func _fade_plate_out() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_plate, ^"modulate:a", 0.0, PLATE_FADE_OUT_SECONDS)
	tween.tween_property(_subtitle, ^"modulate:a", 0.0, PLATE_FADE_OUT_SECONDS)
	tween.tween_property(_hint, ^"modulate:a", 0.0, PLATE_FADE_OUT_SECONDS)
	await tween.finished


## 탭 입력을 받기 시작한다(무장). 자막이 떠오르기 직전에 호출해, 페이드 도중
## 누른 탭도 잃지 않고 버퍼링되게 한다. _advance_requested 를 비워 이전 줄의
## 입력이 새 줄로 새지 않게 한다.
func _arm_advance() -> void:
	_advance_requested = false
	_advance_ready = true


## 다음 줄로 넘어가는 조건: 탭이 들어왔고 + 현재 줄의 나레이션이 끝났을 때.
## 빨리 누른 탭은 버퍼링되어 음성이 끝나는 즉시 넘어가므로, 탭으로 음성을
## 끊어 호흡이 빨라지는 일이 없다(한 줄=한 단위로 차분히 진행).
func _wait_for_advance() -> void:
	if _skip:
		return
	while not _skip:
		if _advance_requested and not _is_narration_playing():
			break
		await get_tree().process_frame
	_advance_ready = false


func _is_narration_playing() -> bool:
	return _narration != null and _narration.playing


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		# 가로 모바일: 인트로 중 뒤로/취소는 삼켜서 무시한다(스킵 없음,
		# 로비 종료 팝업이 인트로 위로 뜨는 것 방지).
		get_viewport().set_input_as_handled()
		return
	if _advance_ready and _is_tap(event):
		# 스킵 버튼 위 탭은 삼키지 않는다. _input 은 GUI 보다 먼저 도는데, 여기서
		# 소비해 버리면 버튼의 pressed 가 영영 안 나가 스킵이 막힌다.
		if _is_over_skip_button(event):
			return
		_advance_requested = true
		get_viewport().set_input_as_handled()


## 탭 좌표가 스킵 버튼 영역 안인지. 진행 탭과 스킵 버튼 클릭의 충돌을 막는다.
func _is_over_skip_button(event: InputEvent) -> bool:
	if _skip_button == null or not _skip_button.visible:
		return false
	var mouse := event as InputEventMouseButton
	if mouse == null:
		return false
	return _skip_button.get_global_rect().has_point(mouse.position)


## 마우스/터치 모두 마우스 버튼으로 들어오도록 프로젝트가 에뮬레이트하므로
## 좌클릭(누름)만 보면 데스크톱·모바일 양쪽을 덮는다.
func _is_tap(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
