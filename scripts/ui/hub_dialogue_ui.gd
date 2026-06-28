class_name HubDialogueUi
extends CanvasLayer
## 낮 학교 허브 NPC 대화 UI.
## 가로모드 기준 하단 대화 바, 좌측 초상화, 우측하단 선택지, 중앙 해금 팝업을 제공한다.

signal choice_selected(choice_id: StringName)
signal unlock_hidden

## 전투 씬 재사용 모드. true 면 _ready 의 학교 전용 자동 콘텐츠/진행도 구독을 건너뛴다.
## instantiate() 직후, add_child() 전에 설정할 것.
var battle_mode := false

const REFERENCE_SIZE := Vector2(844.0, 390.0)
const DIALOGUE_BAR_HEIGHT := 152.0
const UNLOCK_POPUP_SIZE := Vector2(338.0, 148.0)
const UNLOCK_POPUP_CENTER_OFFSET := Vector2(0.0, -58.0)
const DIALOGUE_LINE_SEPARATION := 7
const DEFAULT_PORTRAIT_SCALE := Vector2(2.55, 2.55)
const DEFAULT_PORTRAIT_Y := 173.0
const CONTINUE_HINT_TOUCH := "탭해서 계속"
const CHOICE_ASK := &"ask"
const CHOICE_ACCEPT := &"accept"
const STAGE_STATE_COMPLETED := "completed"
const STAGE_STATE_CURRENT := "current"
const STAGE_STATE_LOCKED := "locked"
const DEFAULT_STAGE_LABELS: Array[String] = [
	"1단계\n첫 만남",
	"2단계\n훈련 후",
	"3단계\n정화 후",
]

const PANEL_COLOR := Color(0.055, 0.063, 0.086, 0.96)
const PANEL_BORDER_COLOR := Color(0.945, 0.91, 0.78)
const NAMEPLATE_COLOR := Color(0.94, 0.89, 0.75)
const NAMEPLATE_TEXT_COLOR := Color(0.075, 0.08, 0.1)
const MEMORY_TEXT_COLOR := Color(0.73, 0.79, 1.0)
const PORTRAIT_COLOR := Color(0.54, 0.24, 0.27)
const PORTRAIT_ACCENT_COLOR := Color(0.18, 0.24, 0.36)
const COMPLETED_STAGE_COLOR := Color(0.51, 0.69, 0.51)
const CURRENT_STAGE_COLOR := Color(0.83, 0.66, 0.27)
const LOCKED_STAGE_COLOR := Color(0.14, 0.17, 0.23)
const UNLOCK_COLOR := Color(0.94, 0.89, 0.75)
const UNLOCK_BORDER_COLOR := Color(0.84, 0.68, 0.28)
const DEFAULT_BALL_COLOR := Color(0.9, 0.88, 0.8)
const DEFAULT_BAT_COLOR := Color(0.54, 0.55, 0.6)
const BASEBALL_CAPTAIN := &"baseball_captain"
const BASEBALL_STAGE_3 := &"baseball_stage_3"
const AWAKENED_BAT := &"awakened_bat"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")
const FontRoles := preload("res://scripts/ui/ui_font_roles.gd")
const AWAKENED_BAT_ICON: Texture2D = preload("res://assets/ui/icons/seoul_challenge/baseball_bat.png")

# 해금 팝업 등장("따란!") 연출 파라미터.
const UNLOCK_REVEAL_DURATION := 0.36
const UNLOCK_START_SCALE := Vector2(0.82, 0.82)
const UNLOCK_DIM_BASE := 0.28
const UNLOCK_DIM_HERO := 0.72
const UNLOCK_ICON_SIZE := Vector2(32.0, 32.0)
# hero(각성) 보상: 배트가 사각형 슬롯에 들어가고 그 뒤로 골드 글로우가 퍼진다.
const UNLOCK_HERO_SLOT_SIZE := Vector2(150.0, 150.0)
const UNLOCK_HERO_POPUP_HALF := Vector2(170.0, 140.0)
const UNLOCK_HERO_POPUP_CENTER_OFFSET := Vector2(0.0, -26.0)
const UNLOCK_GLOW_SIZE := Vector2(300.0, 300.0)
const UNLOCK_GLOW_COLOR := Color(1.0, 0.84, 0.42, 0.9)
const UNLOCK_SPARKLE_COLOR := Color(1.0, 0.88, 0.5, 1.0)

@onready var _dialogue_dimmer: ColorRect = %DialogueDimmer
@onready var _portrait_panel: ColorRect = %PortraitPanel
@onready var _portrait_accent: ColorRect = %PortraitAccent
@onready var _portrait_sprite: Sprite2D = %PortraitSprite
@onready var _dialogue_bar: PanelContainer = %DialogueBar
@onready var _dialogue_top_rule: ColorRect = %DialogueTopRule
@onready var _name_label: Label = %NameLabel
@onready var _stage_row: HBoxContainer = %StageRow
@onready var _dialogue_label: RichTextLabel = %DialogueLabel
@onready var _memory_label: Label = %MemoryLabel
@onready var _choice_row: HBoxContainer = %ChoiceRow
@onready var _unlock_overlay: Control = %UnlockOverlay
@onready var _unlock_popup: PanelContainer = %UnlockPopup
@onready var _unlock_title_label: Label = %UnlockTitleLabel
@onready var _unlock_subtitle_label: Label = %UnlockSubtitleLabel
@onready var _unlock_item_grid: GridContainer = %UnlockItemGrid
@onready var _unlock_continue_hint: Label = %UnlockContinueHint

var _speaker_name := ""
var _dialogue_text := ""
var _dialogue_markup_text := ""
var _memory_text := ""
var _stage_labels := DEFAULT_STAGE_LABELS.duplicate()
var _current_stage := 1
var _completed_stage := 0
var _stage_states: Array[String] = []
var _choice_models: Array[Dictionary] = []
var _unlock_items: Array[Dictionary] = []
var _portrait_frame_count := 1
var _portrait_elapsed := 0.0
var _portrait_fps := 1.6
var _portrait_animates := false
var _unlock_dimmer: ColorRect
var _unlock_reveal_tween: Tween
var _unlock_glow: TextureRect
var _unlock_sparkles: CPUParticles2D
var _unlock_hero_slot: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue_dimmer.set_meta("test_id", "hub_dialogue.overlay")
	_dialogue_bar.set_meta("test_id", "hub_dialogue.bar")
	_choice_row.set_meta("test_id", "hub_dialogue.choice_row")
	_apply_landscape_safe_area()
	_apply_static_styles()
	_unlock_dimmer = _unlock_overlay.get_node("Dimmer") as ColorRect
	_unlock_overlay.visible = false
	# battle_mode: 전투 씬에서 재사용할 때 학교 전용 부수효과를 격리한다.
	# - 야구부 기본 대사/단계 row/선택지를 자동으로 채우지 않는다(호출부가 set_dialogue 로 채움).
	# - EventBus.unlock_changed 를 구독하지 않는다(전투 중 강화배트 해금 팝업이 끼어들지 않게).
	# instantiate() → battle_mode = true → add_child() 순서로 설정해야 _ready 가 읽는다.
	if battle_mode:
		set_stage_row_visible(false)
		return
	set_dialogue("야구부 주장", "\"몸 조심해. 무리하지 마.\"", "")
	set_stage(2)
	set_choices([
		{"id": CHOICE_ASK, "text": "물어보기", "emphasized": false},
		{"id": CHOICE_ACCEPT, "text": "받기", "emphasized": true},
	])
	_connect_progression_events()
	apply_baseball_progress(false)


func _process(delta: float) -> void:
	if not _portrait_sprite.visible or not _portrait_animates or _portrait_frame_count <= 1:
		return
	_portrait_elapsed += delta
	_portrait_sprite.frame = int(_portrait_elapsed * _portrait_fps) % _portrait_frame_count


func get_reference_size() -> Vector2:
	return REFERENCE_SIZE


func _apply_landscape_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	var bottom := float(insets["bottom"])
	MobileSafeArea.apply_edge_offsets(_dialogue_bar, float(insets["left"]), -1.0, float(insets["right"]), bottom)
	_dialogue_bar.offset_top = -DIALOGUE_BAR_HEIGHT - bottom
	MobileSafeArea.apply_edge_offsets(_portrait_panel, float(insets["left"]), -1.0, -1.0, -1.0)
	# 초상화 스프라이트는 PortraitPanel(clip_contents)의 자식 — 위치는 패널 로컬 기준 중앙.
	_portrait_sprite.position.x = (_portrait_panel.offset_right - _portrait_panel.offset_left) * 0.5
	MobileSafeArea.apply_edge_offsets(_choice_row, -1.0, -1.0, float(insets["right"]), -1.0)


func get_dialogue_bar_reference_rect() -> Rect2:
	return Rect2(Vector2(0.0, REFERENCE_SIZE.y - DIALOGUE_BAR_HEIGHT), Vector2(REFERENCE_SIZE.x, DIALOGUE_BAR_HEIGHT))


func get_unlock_popup_reference_rect() -> Rect2:
	var center := REFERENCE_SIZE * 0.5 + UNLOCK_POPUP_CENTER_OFFSET
	return Rect2(center - UNLOCK_POPUP_SIZE * 0.5, UNLOCK_POPUP_SIZE)


func is_dialogue_overlay_visible() -> bool:
	return _dialogue_dimmer.visible and _dialogue_dimmer.color.a > 0.0


func is_dialogue_overlay_modal() -> bool:
	return _dialogue_dimmer.mouse_filter == Control.MOUSE_FILTER_STOP


func set_dialogue(
	next_speaker_name: String,
	next_dialogue_text: String,
	next_memory_text := "",
	portrait_color := PORTRAIT_COLOR,
	portrait_texture: Texture2D = null,
	portrait_frame_index := 0,
	portrait_animates := false
) -> void:
	_speaker_name = next_speaker_name
	_dialogue_markup_text = next_dialogue_text
	_dialogue_text = _strip_dialogue_markup(next_dialogue_text)
	_memory_text = next_memory_text
	_name_label.text = _speaker_name
	_dialogue_label.text = _dialogue_markup_text
	_memory_label.text = _memory_text
	# 보조 기억 라인은 텍스트가 있을 때만 노출 — 빈 값이면 라벨이 레이아웃 갭을 남기지 않게 숨긴다.
	_memory_label.visible = not _memory_text.strip_edges().is_empty()
	set_dialogue_content_visible(true)
	_configure_portrait(portrait_color, portrait_texture, portrait_frame_index, portrait_animates)


func get_speaker_name() -> String:
	return _speaker_name


func get_dialogue_text() -> String:
	return _dialogue_text


func get_dialogue_markup_text() -> String:
	return _dialogue_markup_text


func get_memory_text() -> String:
	return _memory_text


func set_dialogue_content_visible(should_show: bool) -> void:
	_dialogue_dimmer.visible = should_show
	_portrait_panel.visible = should_show
	_dialogue_bar.visible = should_show


func is_dialogue_content_visible() -> bool:
	return _dialogue_bar.visible


func is_portrait_sprite_visible() -> bool:
	return _portrait_sprite.visible


func get_portrait_frame_count() -> int:
	return _portrait_frame_count


func get_portrait_frame() -> int:
	return _portrait_sprite.frame


func is_portrait_animating() -> bool:
	return _portrait_animates


func get_portrait_texture_path() -> String:
	if _portrait_sprite.texture == null:
		return ""
	return _portrait_sprite.texture.resource_path


func get_portrait_scale() -> Vector2:
	return _portrait_sprite.scale


func get_portrait_position() -> Vector2:
	return _portrait_sprite.position


func set_portrait_layout(scale: Vector2, y_position: float) -> void:
	_portrait_sprite.scale = scale
	_portrait_sprite.position.y = y_position


func set_stage(current_stage: int, completed_stage := -1, next_stage_labels: Array[String] = []) -> void:
	if not next_stage_labels.is_empty():
		_stage_labels = next_stage_labels.duplicate()
	_current_stage = clampi(current_stage, 1, _stage_labels.size())
	_completed_stage = current_stage - 1 if completed_stage < 0 else clampi(completed_stage, 0, _stage_labels.size())
	_render_stages()


func get_current_stage() -> int:
	return _current_stage


func get_stage_state(stage_number: int) -> String:
	var index := stage_number - 1
	if index < 0 or index >= _stage_states.size():
		return ""
	return _stage_states[index]


func get_stage_labels() -> Array[String]:
	return _stage_labels.duplicate()


func set_stage_row_visible(should_show: bool) -> void:
	_stage_row.visible = should_show


func is_stage_row_visible() -> bool:
	return _stage_row.visible


func set_choices(next_choices: Array[Dictionary]) -> void:
	_choice_models.clear()
	for choice: Dictionary in next_choices:
		_choice_models.append(choice.duplicate(true))
	_render_choices()


func get_choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: Dictionary in _choice_models:
		ids.append(StringName(choice.get("id", &"")))
	return ids


func is_tap_to_continue_active() -> bool:
	return _tap_to_continue_choice_id() != &""


func get_choice_texts() -> Array[String]:
	var texts: Array[String] = []
	for choice: Dictionary in _choice_models:
		texts.append(String(choice.get("text", "")))
	return texts


func is_choice_emphasized(choice_id: StringName) -> bool:
	for choice: Dictionary in _choice_models:
		if StringName(choice.get("id", &"")) == choice_id:
			return bool(choice.get("emphasized", false))
	return false


func select_choice(choice_id: StringName) -> void:
	if not get_choice_ids().has(choice_id):
		return
	HapticManager.on_ui_confirm()
	choice_selected.emit(choice_id)


func show_unlock(title: String, subtitle: String, items: Array[Dictionary], hero := false) -> void:
	_unlock_title_label.text = title
	_unlock_subtitle_label.text = subtitle
	_unlock_items.clear()
	_unlock_hero_slot = null
	for item: Dictionary in items:
		_unlock_items.append(item.duplicate(true))
	_render_unlock_items()
	_apply_unlock_chrome(hero)
	_unlock_continue_hint.text = CONTINUE_HINT_TOUCH
	_play_unlock_reveal(hero)


func apply_baseball_progress(show_unlock_popup := false) -> void:
	var is_purified := false
	if has_node("/root/ProgressionSystem"):
		is_purified = ProgressionSystem.is_friend_purified(BASEBALL_CAPTAIN)
	if not is_purified:
		set_stage(2)
		return
	set_stage(3, 3)
	if show_unlock_popup:
		_show_awakened_bat_unlock()


func hide_unlock() -> void:
	var was_visible := _unlock_overlay.visible
	if _unlock_reveal_tween != null and _unlock_reveal_tween.is_valid():
		_unlock_reveal_tween.kill()
	_unlock_overlay.visible = false
	_unlock_popup.scale = Vector2.ONE
	_unlock_popup.modulate.a = 1.0
	_hide_hero_effects()
	if was_visible:
		unlock_hidden.emit()


func is_unlock_visible() -> bool:
	return _unlock_overlay.visible


func get_unlock_items() -> Array[Dictionary]:
	return _unlock_items.duplicate(true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# #243: 강화배트 언락 팝업이 떠 있으면 탭으로 닫는다(hide_unlock → unlock_hidden).
	# 팝업에 닫기 어포던스가 없어 라이브로 띄우면 소프트락 되던 latent UI 를 완성.
	if is_unlock_visible():
		if _is_advance_tap_event(event):
			var unlock_viewport := get_viewport()
			if unlock_viewport != null:
				unlock_viewport.set_input_as_handled()
			hide_unlock()
		return
	if not _is_advance_tap_event(event):
		return

	var choice_id := _tap_to_continue_choice_id()
	if choice_id == &"":
		return

	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	select_choice(choice_id)


func _configure_portrait(
	portrait_color: Color,
	portrait_texture: Texture2D,
	portrait_frame_index: int,
	portrait_animates: bool
) -> void:
	if portrait_texture == null:
		_portrait_sprite.visible = false
		_portrait_sprite.texture = null
		_portrait_sprite.scale = DEFAULT_PORTRAIT_SCALE
		_portrait_sprite.position.y = DEFAULT_PORTRAIT_Y
		_portrait_frame_count = 1
		_portrait_elapsed = 0.0
		_portrait_animates = false
		_portrait_panel.color = portrait_color
		_portrait_accent.visible = true
		_portrait_accent.color = PORTRAIT_ACCENT_COLOR
		return

	_portrait_panel.color = Color.TRANSPARENT
	_portrait_accent.visible = false
	_portrait_sprite.visible = true
	_portrait_sprite.texture = portrait_texture
	_portrait_sprite.scale = DEFAULT_PORTRAIT_SCALE
	_portrait_sprite.position.y = DEFAULT_PORTRAIT_Y
	_portrait_sprite.hframes = _get_square_sheet_hframes(portrait_texture)
	_portrait_sprite.vframes = 1
	_portrait_frame_count = maxi(1, _portrait_sprite.hframes * _portrait_sprite.vframes)
	_portrait_sprite.frame = clampi(portrait_frame_index, 0, _portrait_frame_count - 1)
	_portrait_elapsed = 0.0
	_portrait_animates = portrait_animates


func _get_square_sheet_hframes(texture: Texture2D) -> int:
	var height := texture.get_height()
	if height <= 0:
		return 1
	return maxi(1, int(round(texture.get_width() / float(height))))


func _render_stages() -> void:
	_clear_children(_stage_row)
	_stage_states.clear()
	for index in _stage_labels.size():
		var stage_number := index + 1
		var state := STAGE_STATE_LOCKED
		if stage_number <= _completed_stage:
			state = STAGE_STATE_COMPLETED
		if stage_number == _current_stage:
			state = STAGE_STATE_CURRENT
		_stage_states.append(state)

		var label := Label.new()
		label.text = _stage_labels[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size = Vector2(124.0, 34.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 9)
		FontRoles.apply_pixel(label)
		label.add_theme_color_override("font_color", _stage_text_color(state))
		label.add_theme_stylebox_override("normal", _make_panel_style(_stage_color(state), Color(0.35, 0.39, 0.48), 2))
		_stage_row.add_child(label)


func _render_choices() -> void:
	_clear_children(_choice_row)
	for choice: Dictionary in _choice_models:
		var choice_id := StringName(choice.get("id", &""))
		var test_id := String(choice.get("test_id", "hub_dialogue.choice.%s" % String(choice_id)))
		var action_name := String(choice.get("uat_action", "hub_dialogue.choice.%s" % String(choice_id)))
		var is_tap_continue := bool(choice.get("tap_to_continue", false))
		var button := Button.new()
		button.text = String(choice.get("text", ""))
		button.custom_minimum_size = Vector2(170.0, 28.0) if is_tap_continue else Vector2(112.0, 44.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE if is_tap_continue else Control.MOUSE_FILTER_STOP
		button.set_meta("test_id", test_id)
		button.set_meta("uat_action", action_name)
		button.set_meta("choice_id", choice_id)
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		if is_tap_continue:
			_apply_continue_hint_style(button)
		else:
			_apply_button_style(button, bool(choice.get("emphasized", false)))
			PixelButtonStyle.attach_press_sfx(button)
		_choice_row.add_child(button)


func _render_unlock_items() -> void:
	_clear_children(_unlock_item_grid)
	for item: Dictionary in _unlock_items:
		var item_texture := item.get("texture", null) as Texture2D
		if bool(item.get("hero", false)) and item_texture != null:
			# 각성 보상: 사각형 슬롯(골드 테두리) 안에 배트, 뒤에 글로우. 이름은 팝업 타이틀이 맡는다.
			var slot := PanelContainer.new()
			slot.custom_minimum_size = UNLOCK_HERO_SLOT_SIZE
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.add_theme_stylebox_override("panel", _hero_slot_style())
			var hero_icon := TextureRect.new()
			hero_icon.texture = item_texture
			hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			slot.add_child(hero_icon)
			_unlock_item_grid.add_child(slot)
			_unlock_hero_slot = slot
			continue

		var item_panel := PanelContainer.new()
		item_panel.custom_minimum_size = Vector2(140.0, 56.0)
		item_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(1.0, 0.96, 0.83), Color(0.07, 0.08, 0.1), 2))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		item_panel.add_child(row)

		if item_texture != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = item_texture
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = UNLOCK_ICON_SIZE
			row.add_child(icon_rect)
		else:
			var icon := ColorRect.new()
			icon.custom_minimum_size = Vector2(28.0, 28.0)
			icon.color = item.get("color", DEFAULT_BALL_COLOR)
			row.add_child(icon)

		var label := Label.new()
		label.text = String(item.get("name", ""))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
		label.add_theme_font_size_override("font_size", 12)
		FontRoles.apply_pixel(label)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		_unlock_item_grid.add_child(item_panel)


func _on_choice_pressed(choice_id: StringName) -> void:
	select_choice(choice_id)


func _connect_progression_events() -> void:
	if not has_node("/root/EventBus"):
		return
	var unlock_callback := Callable(self, "_on_unlock_changed")
	if EventBus.has_signal(&"unlock_changed") and not EventBus.unlock_changed.is_connected(unlock_callback):
		EventBus.unlock_changed.connect(unlock_callback)


func _on_unlock_changed(payload: Dictionary) -> void:
	var unlocks: Array = payload.get("unlocks", [])
	if StringName(payload.get("friend_id", &"")) != BASEBALL_CAPTAIN and not unlocks.has(AWAKENED_BAT):
		return
	set_stage(3, 3)
	# #243: 팝업은 강화배트가 *실제로* 해금될 때만 띄운다. 정화 시점의 baseball_stage_3 단독으로는 띄우지 않는다
	# (정화/언락 분리 — 강화배트는 로비 퀘스트 완료에서 해금).
	if unlocks.has(AWAKENED_BAT):
		_show_awakened_bat_unlock()


func _show_awakened_bat_unlock() -> void:
	show_unlock("마지막 시즌의 배트", "적의 탄을 배트로 되받아친다", [
		{
			"id": AWAKENED_BAT,
			"name": "마지막 시즌의 배트",
			"color": DEFAULT_BAT_COLOR,
			"texture": AWAKENED_BAT_ICON,
			"hero": true,
		},
	], true)


func _apply_unlock_chrome(hero: bool) -> void:
	if not hero:
		return
	var title_row := _unlock_title_label.get_parent()
	var stack := title_row.get_parent()
	# 데이브 더 다이버식: 박스 제거 + [큰 아이콘] → [이름] → [설명] → [힌트] 세로 중앙 정렬.
	_unlock_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_unlock_popup.offset_left = -UNLOCK_HERO_POPUP_HALF.x
	_unlock_popup.offset_right = UNLOCK_HERO_POPUP_HALF.x
	_unlock_popup.offset_top = -UNLOCK_HERO_POPUP_HALF.y + UNLOCK_HERO_POPUP_CENTER_OFFSET.y
	_unlock_popup.offset_bottom = UNLOCK_HERO_POPUP_HALF.y + UNLOCK_HERO_POPUP_CENTER_OFFSET.y

	if stack is VBoxContainer:
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 8)
		stack.move_child(_unlock_item_grid, 0)
	_unlock_item_grid.columns = 1
	# GridContainer 는 단일 열을 좌측 정렬하므로, 그리드를 내용폭으로 줄여 중앙에 둔다.
	_unlock_item_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if title_row is HBoxContainer:
		title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_unlock_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_title_label.add_theme_color_override("font_color", DungeonUiTheme.COLOR_GOLD)
	_unlock_title_label.add_theme_font_size_override("font_size", 22)

	# 설명을 이름 아래 별도 행으로 옮겨 중앙 정렬한다.
	if _unlock_subtitle_label.get_parent() == title_row:
		title_row.remove_child(_unlock_subtitle_label)
		stack.add_child(_unlock_subtitle_label)
	stack.move_child(_unlock_subtitle_label, stack.get_children().find(title_row) + 1)
	_unlock_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62))
	_unlock_subtitle_label.add_theme_font_size_override("font_size", 13)

	_unlock_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_continue_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _play_unlock_reveal(hero: bool) -> void:
	if _unlock_reveal_tween != null and _unlock_reveal_tween.is_valid():
		_unlock_reveal_tween.kill()
	_unlock_overlay.visible = true

	# 디머는 0에서 시작해 시선을 모으며 페이드인 — 각성(hero) 보상은 더 깊게 어둡힌다.
	var dim_target := UNLOCK_DIM_HERO if hero else UNLOCK_DIM_BASE
	if _unlock_dimmer != null:
		_unlock_dimmer.color.a = 0.0

	# 팝업은 살짝 작게 시작해 오버슈트하며 튀어나온다("따란!").
	_unlock_popup.pivot_offset = UNLOCK_HERO_POPUP_HALF if hero else UNLOCK_POPUP_SIZE * 0.5
	_unlock_popup.scale = UNLOCK_START_SCALE
	_unlock_popup.modulate.a = 0.0

	if hero:
		_layout_hero_effects()
	else:
		_hide_hero_effects()

	var tween := create_tween()
	tween.set_parallel(true)
	if _unlock_dimmer != null:
		tween.tween_property(_unlock_dimmer, "color:a", dim_target, UNLOCK_REVEAL_DURATION * 0.6)
	tween.tween_property(_unlock_popup, "modulate:a", 1.0, UNLOCK_REVEAL_DURATION * 0.7)
	tween.tween_property(_unlock_popup, "scale", Vector2.ONE, UNLOCK_REVEAL_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hero and _unlock_glow != null:
		tween.tween_property(_unlock_glow, "modulate:a", 1.0, UNLOCK_REVEAL_DURATION * 0.5)
	_unlock_reveal_tween = tween

	if hero:
		_play_hero_punch()
		_play_reveal_feedback()


func _layout_hero_effects() -> void:
	var glow := _ensure_unlock_glow()
	glow.size = UNLOCK_GLOW_SIZE
	glow.visible = true
	glow.modulate.a = 0.0
	_ensure_unlock_sparkles().visible = true
	# 우선 근사 위치로 깔고, 레이아웃 확정 후 실제 배트 아이콘 중심으로 정확히 맞춘다.
	_position_hero_effects(_unlock_overlay.size * 0.5 + UNLOCK_HERO_POPUP_CENTER_OFFSET)
	call_deferred("_align_hero_effects_to_icon")


func _align_hero_effects_to_icon() -> void:
	if _unlock_hero_slot == null or not is_instance_valid(_unlock_hero_slot):
		return
	var slot_center := _unlock_hero_slot.get_global_rect().get_center()
	_position_hero_effects(_unlock_overlay.get_global_transform().affine_inverse() * slot_center)


func _hero_slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	sb.border_color = DungeonUiTheme.COLOR_GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	return sb


func _position_hero_effects(center: Vector2) -> void:
	if _unlock_glow != null:
		_unlock_glow.position = center - UNLOCK_GLOW_SIZE * 0.5
	if _unlock_sparkles != null:
		_unlock_sparkles.position = center


func _hide_hero_effects() -> void:
	if _unlock_glow != null:
		_unlock_glow.visible = false
	if _unlock_sparkles != null:
		_unlock_sparkles.emitting = false
		_unlock_sparkles.visible = false


func _play_hero_punch() -> void:
	if _unlock_hero_slot == null:
		return
	_unlock_hero_slot.pivot_offset = UNLOCK_HERO_SLOT_SIZE * 0.5
	_unlock_hero_slot.scale = Vector2(0.5, 0.5)
	var punch := create_tween()
	punch.tween_property(_unlock_hero_slot, "scale", Vector2.ONE, 0.46) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(0.08)


func _play_reveal_feedback() -> void:
	HapticManager.on_ui_confirm()
	_play_reveal_sfx()
	if _unlock_sparkles != null:
		_unlock_sparkles.restart()
		_unlock_sparkles.emitting = true


func _play_reveal_sfx() -> void:
	# 사용자 제공 예정 '따란!' 효과음. 파일이 추가되면 자동 재생, 없으면 조용히 스킵한다.
	if not has_node("/root/AudioManager"):
		return
	var path := AudioManager.get_sfx_stream_path(AudioManager.AWAKENED_BAT_REVEAL)
	if path == "" or not ResourceLoader.exists(path):
		return
	AudioManager.play_sfx(AudioManager.AWAKENED_BAT_REVEAL)


func _ensure_unlock_glow() -> TextureRect:
	if _unlock_glow != null:
		return _unlock_glow
	var glow := TextureRect.new()
	glow.name = "UnlockGlow"
	glow.texture = _make_radial_texture(UNLOCK_GLOW_COLOR)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	_unlock_overlay.add_child(glow)
	# 디머(0) 바로 위, 팝업 아래로 배치해 글로우가 팝업 뒤에서 번지게 한다.
	_unlock_overlay.move_child(glow, 1)
	_unlock_glow = glow
	return glow


func _ensure_unlock_sparkles() -> CPUParticles2D:
	if _unlock_sparkles != null:
		return _unlock_sparkles
	var particles := CPUParticles2D.new()
	particles.name = "UnlockSparkles"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 22
	particles.lifetime = 0.9
	particles.texture = _make_radial_texture(Color(1.0, 1.0, 1.0, 1.0), 16)
	particles.spread = 180.0
	particles.direction = Vector2(0.0, -1.0)
	particles.gravity = Vector2(0.0, 140.0)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 175.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 1.0
	particles.color = UNLOCK_SPARKLE_COLOR
	# 팝업(z 기본 0) 위에서 튀도록 마지막 자식으로 둔다.
	_unlock_overlay.add_child(particles)
	_unlock_sparkles = particles
	return particles


func _make_radial_texture(center_color: Color, dimension := 192) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, center_color)
	gradient.set_color(1, Color(center_color.r, center_color.g, center_color.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = dimension
	tex.height = dimension
	return tex


func _tap_to_continue_choice_id() -> StringName:
	if _choice_models.size() != 1:
		return &""
	var choice := _choice_models[0]
	if not bool(choice.get("tap_to_continue", false)):
		return &""
	return StringName(choice.get("id", &""))


func _is_advance_tap_event(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	var touch := event as InputEventScreenTouch
	if touch != null:
		return touch.pressed
	return false


func _apply_static_styles() -> void:
	_dialogue_bar.add_theme_stylebox_override("panel", _make_panel_style(PANEL_COLOR, PANEL_COLOR, 0))
	_dialogue_top_rule.color = PANEL_BORDER_COLOR
	_name_label.add_theme_color_override("font_color", NAMEPLATE_TEXT_COLOR)
	_name_label.add_theme_font_size_override("font_size", 16)
	FontRoles.apply_title(_name_label)
	_name_label.add_theme_stylebox_override("normal", _make_panel_style(NAMEPLATE_COLOR, Color(0.07, 0.08, 0.1), 2))
	_dialogue_label.add_theme_color_override("default_color", Color.WHITE)
	_dialogue_label.add_theme_font_size_override("normal_font_size", 18)
	_dialogue_label.add_theme_constant_override("line_separation", DIALOGUE_LINE_SEPARATION)
	FontRoles.apply_body(_dialogue_label)
	_memory_label.add_theme_color_override("font_color", MEMORY_TEXT_COLOR)
	_memory_label.add_theme_font_size_override("font_size", 13)
	FontRoles.apply_body(_memory_label)
	_choice_row.add_theme_constant_override("separation", 8)
	_choice_row.alignment = BoxContainer.ALIGNMENT_END
	_stage_row.add_theme_constant_override("separation", 4)
	_unlock_popup.add_theme_stylebox_override("panel", _make_panel_style(UNLOCK_COLOR, UNLOCK_BORDER_COLOR, 4))
	_unlock_title_label.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	_unlock_title_label.add_theme_font_size_override("font_size", 17)
	FontRoles.apply_title(_unlock_title_label)
	_unlock_subtitle_label.add_theme_color_override("font_color", Color(0.42, 0.29, 0.1))
	_unlock_subtitle_label.add_theme_font_size_override("font_size", 11)
	FontRoles.apply_body(_unlock_subtitle_label)
	FontRoles.apply_pixel(_unlock_continue_hint)


func _apply_button_style(button: Button, emphasized: bool) -> void:
	var fill := NAMEPLATE_COLOR if emphasized else Color(0.18, 0.23, 0.31)
	var text_color := NAMEPLATE_TEXT_COLOR if emphasized else Color(0.95, 0.94, 0.87)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_font_size_override("font_size", 14)
	FontRoles.apply_pixel(button)
	button.add_theme_stylebox_override("normal", _make_panel_style(fill, Color(0.45, 0.5, 0.59), 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill.lightened(0.08), Color(0.64, 0.69, 0.78), 2))
	button.add_theme_stylebox_override("pressed", _make_panel_style(fill.darkened(0.08), Color(0.07, 0.08, 0.1), 2))


func _apply_continue_hint_style(button: Button) -> void:
	button.flat = true
	button.add_theme_color_override("font_color", MEMORY_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", MEMORY_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", MEMORY_TEXT_COLOR)
	button.add_theme_font_size_override("font_size", 13)
	FontRoles.apply_pixel(button)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())


func _stage_color(state: String) -> Color:
	match state:
		STAGE_STATE_COMPLETED:
			return COMPLETED_STAGE_COLOR
		STAGE_STATE_CURRENT:
			return CURRENT_STAGE_COLOR
		_:
			return LOCKED_STAGE_COLOR


func _stage_text_color(state: String) -> Color:
	return NAMEPLATE_TEXT_COLOR if state != STAGE_STATE_LOCKED else Color(0.58, 0.64, 0.73)


func _make_panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	# Square pixel frame with the dialogue UI's tight 8x4 padding. Delegates to the
	# shared DungeonUiTheme builder so popup/panel stylebox construction lives in one
	# place (output is identical to the previous inline StyleBoxFlat).
	return DungeonUiTheme.panel_style(fill, border, border_width, 8.0, 4.0)


func _strip_dialogue_markup(text: String) -> String:
	return text.replace("[b]", "").replace("[/b]", "")


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
