class_name NightIntroCutscene
extends CanvasLayer
## 밤 인트로 콜드오픈. 첫 밤 진입 직전 1회 재생되는 시네마틱 자막 시퀀스.
##
## 플레이트 4장을 검정에서 페이드로 띄우고, 한글 자막을 탭으로 진행한다.
## 마지막 비트가 끝나면 finished 시그널을 방출하고, 호출부가 세션 진입을 이어간다.
## 자막 문구는 BEATS 에 모여 있어 따로 교체하기 쉽다.

signal finished

## SceneTransition 페이드 오버레이(레이어 230)보다 아래로 깔아, 세션 전환 페이드가
## 인트로 위를 덮을 수 있게 한다.
const LAYER_INDEX := 120
const PLATE_FADE_SECONDS := 0.9
const SUBTITLE_FADE_SECONDS := 0.5
const PLATE_FADE_OUT_SECONDS := 0.6
const LETTERBOX_RATIO := 0.12

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
	{"plate": 1, "lines": ["너는 매일 밤, 그 아래로 내려간다.", "위의 누구도, 그곳을 알지 못한 채."]},
	{"plate": 2, "lines": ["오늘 밤은…", "돌아오지 못할지도 몰라."]},
	{"plate": 3, "lines": ["그래도, 너는 멈추지 않는다.", "— 밤이 시작된다."]},
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
	for beat: Dictionary in BEATS:
		if _skip:
			break
		await _show_plate(int(beat["plate"]))
		for line: String in beat["lines"]:
			if _skip:
				break
			_set_subtitle(line)
			await _fade_subtitle_in()
			await _wait_for_advance()
		if _skip:
			break
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
	_plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_plate)

	_add_letterbox_bar("LetterboxTop", 0.0, LETTERBOX_RATIO)
	_add_letterbox_bar("LetterboxBottom", 1.0 - LETTERBOX_RATIO, 1.0)

	_subtitle = Label.new()
	_subtitle.name = "Subtitle"
	_subtitle.anchor_left = 0.08
	_subtitle.anchor_right = 0.92
	_subtitle.anchor_top = 0.80
	_subtitle.anchor_bottom = 0.90
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 26)
	_subtitle.add_theme_color_override("font_color", Color(0.93, 0.94, 0.97))
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_subtitle)

	_hint = Label.new()
	_hint.name = "AdvanceHint"
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 0.93
	_hint.anchor_bottom = 0.98
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.text = "화면을 탭하여 계속  ·  ESC 건너뛰기"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78, 0.6))
	_hint.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _add_letterbox_bar(bar_name: String, anchor_top: float, anchor_bottom: float) -> void:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = anchor_top
	bar.anchor_bottom = anchor_bottom
	bar.color = Color(0.0, 0.0, 0.0, 1.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)


func _show_plate(plate_index: int) -> void:
	var path := PLATES[plate_index]
	_plate.texture = load(path)
	_plate.modulate.a = 0.0
	_set_subtitle("")
	_hint.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_plate, ^"modulate:a", 1.0, PLATE_FADE_SECONDS)
	await tween.finished


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
		skip()
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
