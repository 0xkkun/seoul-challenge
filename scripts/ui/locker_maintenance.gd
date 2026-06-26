class_name LockerMaintenance
extends Control

signal return_requested
signal weapon_changed(weapon_id: StringName)
signal map_requested

const WEAPON_BASEBALL := &"baseball"
const WEAPON_BAT := &"bat"
const WEAPON_STUDENT_ID := &"student_id"

const ACTION_RETURN := "locker_maintenance.return"
const ACTION_SELECT_BASEBALL := "locker_maintenance.weapon.baseball"
const ACTION_SELECT_BAT := "locker_maintenance.weapon.bat"
const ACTION_CYCLE_WEAPON := "locker_maintenance.weapon.cycle"
const ACTION_OPEN_MAP := "locker_maintenance.map"

@export var scene_transition_enabled := true

var _selected_weapon_id := WEAPON_BASEBALL
var _weapon_status_label: Label
var _baseball_card: Button
var _bat_card: Button
var _student_id_card: Button
var _weapon_button: Button
var _map_button: Button
var _return_button: Button


func _ready() -> void:
	_build_ui()
	select_weapon(_get_initial_weapon_id())


func get_selected_weapon_id() -> StringName:
	return _selected_weapon_id


func get_map_entry_count() -> int:
	return _count_action_entries(self, ACTION_OPEN_MAP)


func select_weapon(weapon_id: StringName) -> void:
	if weapon_id != WEAPON_BASEBALL and weapon_id != WEAPON_BAT:
		return
	if _selected_weapon_id == weapon_id and _weapon_status_label != null:
		_apply_weapon_card_state()
		return
	_selected_weapon_id = weapon_id
	_apply_weapon_card_state()
	weapon_changed.emit(_selected_weapon_id)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.031373, 0.05098, 0.062745, 1.0)
	add_child(background)

	_build_locker_wall(background)
	_build_title()
	_build_weapon_cards()
	_build_action_bar()


func _build_locker_wall(parent: Control) -> void:
	var wall := ColorRect.new()
	wall.name = "LockerWall"
	wall.anchor_left = 0.0
	wall.anchor_top = 0.0
	wall.anchor_right = 1.0
	wall.anchor_bottom = 1.0
	wall.color = Color(0.039216, 0.086275, 0.094118, 1.0)
	parent.add_child(wall)

	for index: int in range(7):
		var locker := ColorRect.new()
		locker.name = "Locker%d" % index
		locker.anchor_left = 0.08 + float(index) * 0.115
		locker.anchor_top = 0.0
		locker.anchor_right = locker.anchor_left + 0.095
		locker.anchor_bottom = 0.79
		locker.color = Color(0.058824, 0.172549, 0.180392, 1.0)
		parent.add_child(locker)

	var open_locker := ColorRect.new()
	open_locker.name = "OpenLockerGlow"
	open_locker.anchor_left = 0.58
	open_locker.anchor_top = 0.15
	open_locker.anchor_right = 0.75
	open_locker.anchor_bottom = 0.78
	open_locker.color = Color(0.023529, 0.407843, 0.423529, 0.45)
	parent.add_child(open_locker)

	var hallway := ColorRect.new()
	hallway.name = "NightHallwayHint"
	hallway.anchor_left = 0.75
	hallway.anchor_top = 0.0
	hallway.anchor_right = 1.0
	hallway.anchor_bottom = 0.79
	hallway.color = Color(0.060784, 0.054902, 0.047059, 1.0)
	parent.add_child(hallway)

	var exit_glow := ColorRect.new()
	exit_glow.name = "NightExitGlow"
	exit_glow.anchor_left = 0.86
	exit_glow.anchor_top = 0.20
	exit_glow.anchor_right = 0.96
	exit_glow.anchor_bottom = 0.61
	exit_glow.color = Color(0.05098, 0.231373, 0.352941, 0.88)
	parent.add_child(exit_glow)

	var floor := ColorRect.new()
	floor.name = "Floor"
	floor.anchor_left = 0.0
	floor.anchor_top = 0.79
	floor.anchor_right = 1.0
	floor.anchor_bottom = 1.0
	floor.color = Color(0.031373, 0.039216, 0.05098, 1.0)
	parent.add_child(floor)


func _build_title() -> void:
	var title := Label.new()
	title.name = "TitleLabel"
	title.anchor_left = 0.04
	title.anchor_top = 0.04
	title.anchor_right = 0.52
	title.anchor_bottom = 0.16
	title.text = "사물함 정비"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.941176, 0.811765, 0.392157, 1.0))
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.anchor_left = 0.04
	subtitle.anchor_top = 0.16
	subtitle.anchor_right = 0.70
	subtitle.anchor_bottom = 0.23
	subtitle.text = "밤의 경복궁으로 나가기 전, 기억을 무기로 다듬는다."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.780392, 0.807843, 0.858824, 1.0))
	add_child(subtitle)

	var section := Label.new()
	section.name = "WeaponSectionLabel"
	section.anchor_left = 0.05
	section.anchor_top = 0.29
	section.anchor_right = 0.36
	section.anchor_bottom = 0.36
	section.text = "기억 무기"
	section.add_theme_font_size_override("font_size", 24)
	section.add_theme_color_override("font_color", Color(0.858824, 0.784314, 0.596078, 1.0))
	add_child(section)


func _build_weapon_cards() -> void:
	_baseball_card = _make_weapon_card(
		"BaseballCard",
		"낡은 야구공\n\n위력  ■■■□□\n속도  ■■■■□\n사거리 ■■□□□\n\n작은 충격파 생성",
		Rect2(0.04, 0.38, 0.18, 0.37),
		ACTION_SELECT_BASEBALL
	)
	add_child(_baseball_card)

	_bat_card = _make_weapon_card(
		"BatCard",
		"금 간 배트\n\n위력  ■■■■□\n속도  ■□□□□\n사거리 ■□□□□\n\n적을 밀쳐냄",
		Rect2(0.24, 0.40, 0.18, 0.34),
		ACTION_SELECT_BAT
	)
	add_child(_bat_card)

	_student_id_card = _make_weapon_card(
		"StudentIdCard",
		"학생증\n\n보조 아이템\n효과 지속  ■■■□□\n\n피해 감소",
		Rect2(0.44, 0.42, 0.16, 0.30),
		""
	)
	_student_id_card.disabled = true
	add_child(_student_id_card)

	_weapon_status_label = Label.new()
	_weapon_status_label.name = "WeaponStatusLabel"
	_weapon_status_label.anchor_left = 0.62
	_weapon_status_label.anchor_top = 0.56
	_weapon_status_label.anchor_right = 0.82
	_weapon_status_label.anchor_bottom = 0.67
	_weapon_status_label.add_theme_font_size_override("font_size", 18)
	_weapon_status_label.add_theme_color_override("font_color", Color(0.776471, 0.956863, 0.976471, 1.0))
	_weapon_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_weapon_status_label)


func _build_action_bar() -> void:
	_return_button = _make_action_button("ReturnButton", "복도\n뒤로 돌아가기", Rect2(0.06, 0.82, 0.24, 0.13), ACTION_RETURN)
	add_child(_return_button)

	_weapon_button = _make_action_button("WeaponButton", "무기\n무기 변경", Rect2(0.36, 0.82, 0.28, 0.13), ACTION_CYCLE_WEAPON)
	add_child(_weapon_button)

	_map_button = _make_action_button("MapButton", "지도\n지도 보기", Rect2(0.72, 0.82, 0.22, 0.13), ACTION_OPEN_MAP)
	add_child(_map_button)

	_return_button.pressed.connect(_on_return_pressed)
	_weapon_button.pressed.connect(_on_cycle_weapon_pressed)
	_map_button.pressed.connect(_on_map_pressed)


func _make_weapon_card(node_name: String, text: String, relative_rect: Rect2, action: String) -> Button:
	var card := Button.new()
	card.name = node_name
	card.unique_name_in_owner = true
	card.anchor_left = relative_rect.position.x
	card.anchor_top = relative_rect.position.y
	card.anchor_right = relative_rect.position.x + relative_rect.size.x
	card.anchor_bottom = relative_rect.position.y + relative_rect.size.y
	card.text = text
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_theme_font_size_override("font_size", 17)
	card.add_theme_color_override("font_color", Color(0.909804, 0.92549, 0.956863, 1.0))
	card.add_theme_stylebox_override("normal", _make_panel_style(Color(0.039216, 0.062745, 0.086275, 0.96), Color(0.286275, 0.337255, 0.407843, 1.0), 2))
	card.add_theme_stylebox_override("hover", _make_panel_style(Color(0.058824, 0.094118, 0.129412, 0.98), Color(0.403922, 0.909804, 0.976471, 0.82), 2))
	card.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.027451, 0.043137, 0.058824, 1.0), Color(0.403922, 0.909804, 0.976471, 1.0), 2))
	card.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.027451, 0.035294, 0.047059, 0.82), Color(0.180392, 0.207843, 0.25098, 1.0), 2))
	if action != "":
		_set_button_meta(card, action.replace(".", "_"), action)
		card.pressed.connect(select_weapon.bind(WEAPON_BASEBALL if action == ACTION_SELECT_BASEBALL else WEAPON_BAT))
	return card


func _make_action_button(node_name: String, text: String, relative_rect: Rect2, action: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.unique_name_in_owner = true
	button.anchor_left = relative_rect.position.x
	button.anchor_top = relative_rect.position.y
	button.anchor_right = relative_rect.position.x + relative_rect.size.x
	button.anchor_bottom = relative_rect.position.y + relative_rect.size.y
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.937255, 0.960784, 0.988235, 1.0))
	var border_color := Color(0.403922, 0.909804, 0.976471, 0.86) if action == ACTION_OPEN_MAP else Color(0.784314, 0.631373, 0.227451, 0.86)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.047059, 0.070588, 0.098039, 0.96), border_color, 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.066667, 0.105882, 0.145098, 1.0), border_color, 3))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.027451, 0.043137, 0.058824, 1.0), border_color, 3))
	_set_button_meta(button, action.replace(".", "_"), action)
	return button


func _set_button_meta(button: Button, test_id_suffix: String, action: String) -> void:
	button.set_meta("test_id", "locker_maintenance.%s" % test_id_suffix)
	button.set_meta("uat_action", action)


func _apply_weapon_card_state() -> void:
	if _baseball_card == null or _bat_card == null or _weapon_status_label == null:
		return
	_baseball_card.add_theme_stylebox_override(
		"normal",
		_make_weapon_state_style(_selected_weapon_id == WEAPON_BASEBALL)
	)
	_bat_card.add_theme_stylebox_override(
		"normal",
		_make_weapon_state_style(_selected_weapon_id == WEAPON_BAT)
	)
	_weapon_status_label.text = "선택 중: %s" % ("낡은 야구공" if _selected_weapon_id == WEAPON_BASEBALL else "금 간 배트")


func _make_weapon_state_style(selected: bool) -> StyleBoxFlat:
	var border := Color(0.941176, 0.737255, 0.25098, 1.0) if selected else Color(0.286275, 0.337255, 0.407843, 1.0)
	var width := 4 if selected else 2
	return _make_panel_style(Color(0.039216, 0.062745, 0.086275, 0.96), border, width)


func _make_panel_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


func _count_action_entries(node: Node, action: String) -> int:
	var count := 1 if node.get_meta("uat_action", "") == action else 0
	for child: Node in node.get_children():
		count += _count_action_entries(child, action)
	return count


func _on_return_pressed() -> void:
	SceneTransition.clear_pending_run_config()
	return_requested.emit()
	if scene_transition_enabled:
		SceneTransition.go_to_day_lobby()


func _on_cycle_weapon_pressed() -> void:
	select_weapon(WEAPON_BAT if _selected_weapon_id == WEAPON_BASEBALL else WEAPON_BASEBALL)


func _on_map_pressed() -> void:
	_save_pending_loadout()
	map_requested.emit()
	if scene_transition_enabled:
		SceneTransition.go_to_night_map_select()


func _get_initial_weapon_id() -> StringName:
	var pending_config := SceneTransition.get_pending_run_config()
	return StringName(pending_config.get(SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID, WEAPON_BASEBALL))


func _save_pending_loadout() -> void:
	SceneTransition.merge_pending_run_config({
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: _selected_weapon_id,
	})
