class_name LockerMaintenance
extends Control

signal return_requested
signal weapon_changed(weapon_id: StringName)
signal map_requested

const DungeonTheme := preload("res://scripts/ui/dungeon_ui_theme.gd")

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
var _loadout_panel: PanelContainer
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
	background.color = DungeonTheme.COLOR_BACKDROP
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
	wall.color = Color(0.031, 0.056, 0.06, 1.0)
	parent.add_child(wall)

	for index: int in range(7):
		var locker := ColorRect.new()
		locker.name = "Locker%d" % index
		locker.anchor_left = 0.08 + float(index) * 0.115
		locker.anchor_top = 0.0
		locker.anchor_right = locker.anchor_left + 0.095
		locker.anchor_bottom = 0.79
		locker.color = Color(0.043, 0.106, 0.112, 0.72)
		parent.add_child(locker)

	var open_locker := ColorRect.new()
	open_locker.name = "OpenLockerGlow"
	open_locker.anchor_left = 0.58
	open_locker.anchor_top = 0.15
	open_locker.anchor_right = 0.75
	open_locker.anchor_bottom = 0.78
	open_locker.color = Color(0.039, 0.24, 0.25, 0.38)
	parent.add_child(open_locker)

	var hallway := ColorRect.new()
	hallway.name = "NightHallwayHint"
	hallway.anchor_left = 0.75
	hallway.anchor_top = 0.0
	hallway.anchor_right = 1.0
	hallway.anchor_bottom = 0.79
	hallway.color = Color(0.041, 0.039, 0.035, 1.0)
	parent.add_child(hallway)

	var exit_glow := ColorRect.new()
	exit_glow.name = "NightExitGlow"
	exit_glow.anchor_left = 0.86
	exit_glow.anchor_top = 0.20
	exit_glow.anchor_right = 0.96
	exit_glow.anchor_bottom = 0.61
	exit_glow.color = Color(0.036, 0.18, 0.27, 0.82)
	parent.add_child(exit_glow)

	var floor_strip := ColorRect.new()
	floor_strip.name = "Floor"
	floor_strip.anchor_left = 0.0
	floor_strip.anchor_top = 0.79
	floor_strip.anchor_right = 1.0
	floor_strip.anchor_bottom = 1.0
	floor_strip.color = Color(0.022, 0.028, 0.038, 1.0)
	parent.add_child(floor_strip)


func _build_title() -> void:
	var title := Label.new()
	title.name = "TitleLabel"
	title.anchor_left = 0.05
	title.anchor_top = 0.045
	title.anchor_right = 0.52
	title.anchor_bottom = 0.13
	title.text = "사물함 정비"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", DungeonTheme.COLOR_GOLD)
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.anchor_left = 0.05
	subtitle.anchor_top = 0.135
	subtitle.anchor_right = 0.72
	subtitle.anchor_bottom = 0.20
	subtitle.text = "밤의 경복궁으로 나가기 전, 들고 갈 기억을 고른다."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", DungeonTheme.COLOR_MUTED_TEXT)
	add_child(subtitle)

	var section := Label.new()
	section.name = "WeaponSectionLabel"
	section.anchor_left = 0.05
	section.anchor_top = 0.245
	section.anchor_right = 0.36
	section.anchor_bottom = 0.31
	section.text = "기억 무기"
	section.add_theme_font_size_override("font_size", 24)
	section.add_theme_color_override("font_color", Color(0.86, 0.80, 0.62, 1.0))
	add_child(section)


func _build_weapon_cards() -> void:
	_baseball_card = _make_weapon_card(
		"BaseballCard",
		"낡은 야구공\n\n원거리 / 빠른 연사\n위력  ■■■□□\n속도  ■■■■□\n\n작은 충격파",
		Rect2(0.05, 0.32, 0.205, 0.36),
		ACTION_SELECT_BASEBALL
	)
	add_child(_baseball_card)

	_bat_card = _make_weapon_card(
		"BatCard",
		"금 간 배트\n\n근거리 / 큰 반동\n위력  ■■■■□\n속도  ■□□□□\n\n적 밀쳐냄",
		Rect2(0.285, 0.32, 0.205, 0.36),
		ACTION_SELECT_BAT
	)
	add_child(_bat_card)

	_student_id_card = _make_weapon_card(
		"StudentIdCard",
		"학생증\n\n보조 슬롯\n준비 중\n\n피해 감소",
		Rect2(0.52, 0.32, 0.205, 0.36),
		""
	)
	_student_id_card.disabled = true
	add_child(_student_id_card)

	_loadout_panel = PanelContainer.new()
	_loadout_panel.name = "LoadoutSummaryPanel"
	_loadout_panel.anchor_left = 0.76
	_loadout_panel.anchor_top = 0.32
	_loadout_panel.anchor_right = 0.94
	_loadout_panel.anchor_bottom = 0.68
	_loadout_panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.panel_style(DungeonTheme.COLOR_PANEL, DungeonTheme.COLOR_GOLD_DIM, 2, 14.0, 12.0)
	)
	add_child(_loadout_panel)

	_weapon_status_label = Label.new()
	_weapon_status_label.name = "WeaponStatusLabel"
	_weapon_status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_status_label.add_theme_font_size_override("font_size", 18)
	_weapon_status_label.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	_weapon_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weapon_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loadout_panel.add_child(_weapon_status_label)


func _build_action_bar() -> void:
	_return_button = _make_action_button("ReturnButton", "복도\n나가기", Rect2(0.06, 0.82, 0.24, 0.13), ACTION_RETURN)
	add_child(_return_button)

	_weapon_button = _make_action_button("WeaponButton", "무기\n전환", Rect2(0.36, 0.82, 0.24, 0.13), ACTION_CYCLE_WEAPON)
	add_child(_weapon_button)

	_map_button = _make_action_button("MapButton", "지도\n경복궁 선택", Rect2(0.66, 0.82, 0.28, 0.13), ACTION_OPEN_MAP)
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
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_font_size_override("font_size", 17)
	card.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	card.add_theme_color_override("font_hover_color", DungeonTheme.COLOR_TEXT)
	card.add_theme_color_override("font_pressed_color", DungeonTheme.COLOR_GOLD)
	card.add_theme_color_override("font_disabled_color", DungeonTheme.COLOR_MUTED_TEXT)
	card.add_theme_stylebox_override("normal", DungeonTheme.slot_style(false))
	card.add_theme_stylebox_override("hover", DungeonTheme.panel_style(DungeonTheme.COLOR_PANEL_RAISED, DungeonTheme.COLOR_CYAN, 3, 12.0, 10.0))
	card.add_theme_stylebox_override("pressed", DungeonTheme.panel_style(DungeonTheme.COLOR_SLOT, DungeonTheme.COLOR_GOLD, 3, 12.0, 10.0))
	card.add_theme_stylebox_override("disabled", DungeonTheme.slot_style(false, true))
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
	button.add_theme_font_size_override("font_size", 21)
	var variant := DungeonTheme.VARIANT_PRIMARY if action == ACTION_OPEN_MAP else DungeonTheme.VARIANT_SECONDARY
	DungeonTheme.apply_button(button, variant, Vector2(0.0, 64.0))
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
	var weapon_name := "낡은 야구공" if _selected_weapon_id == WEAPON_BASEBALL else "금 간 배트"
	_weapon_status_label.text = "선택된 기억\n\n%s\n\n지도에서\n경복궁 선택" % weapon_name


func _make_weapon_state_style(selected: bool) -> StyleBoxFlat:
	return DungeonTheme.slot_style(selected)


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
