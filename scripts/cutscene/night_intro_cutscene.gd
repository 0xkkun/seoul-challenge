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

## 각 비트: 어떤 플레이트 위에 어떤 자막 줄들을 순서대로 보여줄지.
const BEATS: Array[Dictionary] = [
	{"plate": 0, "lines": ["도시가 잠들면,", "깨어나는 것이 있다."]},
	{"plate": 1, "lines": ["나는 매일 밤, 그 아래로 내려간다.", "지상의 아무도 모르는 곳으로."]},
	{"plate": 2, "lines": ["오늘 밤은…", "돌아오지 못할지도 몰라."]},
	{"plate": 3, "lines": ["그래도, 나는 멈추지 않는다.", "밤이 시작된다."]},
]

var _plate: TextureRect
var _subtitle: Label
var _hint: Label
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
	var last_index := BEATS.size() - 1
	for i: int in BEATS.size():
		if _skip:
			break
		var beat: Dictionary = BEATS[i]
		await _show_plate(int(beat["plate"]), BACKDROP_ALPHA)
		for line: String in beat["lines"]:
			if _skip:
				break
			_set_subtitle(line)
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
	_hint.text = "탭하여 계속 ▸"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86, 0.55))
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _show_plate(plate_index: int, target_alpha: float) -> void:
	var path := PLATES[plate_index]
	_plate.texture = load(path)
	_plate.modulate.a = 0.0
	_set_subtitle("")
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_plate, ^"modulate:a", target_alpha, PLATE_FADE_SECONDS)
	await tween.finished


## 마지막 비트: 자막이 사라지며 경복궁이 가득 드러나고, 잠시 머문 뒤 암전한다.
func _reveal_finale() -> void:
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


func _wait_for_advance() -> void:
	if _skip:
		return
	_advance_ready = true
	_advance_requested = false
	while not _advance_requested and not _skip:
		await get_tree().process_frame
	_advance_ready = false


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		# 가로 모바일: 인트로 중 뒤로/취소는 삼켜서 무시한다(스킵 없음,
		# 로비 종료 팝업이 인트로 위로 뜨는 것 방지).
		get_viewport().set_input_as_handled()
		return
	if _advance_ready and _is_tap(event):
		_advance_requested = true
		get_viewport().set_input_as_handled()


## 마우스/터치 모두 마우스 버튼으로 들어오도록 프로젝트가 에뮬레이트하므로
## 좌클릭(누름)만 보면 데스크톱·모바일 양쪽을 덮는다.
func _is_tap(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
