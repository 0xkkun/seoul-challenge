class_name NightMapSelect
extends Control

signal return_requested
signal stage_selected(stage_id: StringName)

const DungeonTheme := preload("res://scripts/ui/dungeon_ui_theme.gd")
const PixelButton := preload("res://scripts/ui/pixel_button_style.gd")
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

const STAGE_GYEONGBOKGUNG := &"gyeongbokgung"
const ACTION_RETURN := "night_map_select.return"
const ACTION_SELECT_GYEONGBOKGUNG := "night_map_select.gyeongbokgung"

@export var scene_transition_enabled := true

var _selected_stage_id := STAGE_GYEONGBOKGUNG
var _is_departure_requested := false
var _depart_button: Button
var _route_label: Label


func _ready() -> void:
	_build_ui()


func get_selected_stage_id() -> StringName:
	return _selected_stage_id


func get_stage_entry_count() -> int:
	return _count_action_entries(self, ACTION_SELECT_GYEONGBOKGUNG)


func get_departure_config() -> Dictionary:
	var config := SceneTransition.get_pending_run_config()
	config["source"] = "night_map_select"
	config["stage_id"] = STAGE_GYEONGBOKGUNG
	config["stage_name"] = "경복궁"
	return config


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = DungeonTheme.COLOR_BACKDROP
	add_child(background)

	var title := Label.new()
	title.name = "TitleLabel"
	title.anchor_left = 0.05
	title.anchor_top = 0.055
	title.anchor_right = 0.48
	title.anchor_bottom = 0.14
	title.text = "야간 지도"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", DungeonTheme.COLOR_GOLD)
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.anchor_left = 0.05
	subtitle.anchor_top = 0.145
	subtitle.anchor_right = 0.74
	subtitle.anchor_bottom = 0.20
	subtitle.text = "정비한 장비로 진입할 밤런 경로를 고른다."
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", DungeonTheme.COLOR_MUTED_TEXT)
	add_child(subtitle)

	var map_panel := PanelContainer.new()
	map_panel.name = "RouteMapPanel"
	map_panel.anchor_left = 0.07
	map_panel.anchor_top = 0.24
	map_panel.anchor_right = 0.64
	map_panel.anchor_bottom = 0.72
	map_panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.panel_style(DungeonTheme.COLOR_PANEL_RAISED, DungeonTheme.COLOR_STEEL_BRIGHT, 2, 22.0, 18.0)
	)
	add_child(map_panel)

	_route_label = Label.new()
	_route_label.name = "MapLabel"
	_route_label.text = "학교 정비실  ─  광화문 봉인문  ─  경복궁\n\n잠김: 창덕궁 · 덕수궁 · 종묘\n\n오늘 밤 갈 수 있는 궁은 경복궁뿐이다."
	_route_label.add_theme_font_size_override("font_size", 24)
	_route_label.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	_route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_route_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_route_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel.add_child(_route_label)

	var info_panel := PanelContainer.new()
	info_panel.name = "DestinationPanel"
	info_panel.anchor_left = 0.68
	info_panel.anchor_top = 0.24
	info_panel.anchor_right = 0.94
	info_panel.anchor_bottom = 0.72
	info_panel.add_theme_stylebox_override(
		"panel",
		DungeonTheme.panel_style(DungeonTheme.COLOR_PANEL, DungeonTheme.COLOR_GOLD, 3, 18.0, 14.0)
	)
	add_child(info_panel)

	var destination := Label.new()
	destination.name = "DestinationLabel"
	destination.text = "선택됨\n밤의 경복궁\n\n시간  야간\n위험도  보통\n장비  기억 무기\n목표  친구 정화와 탈출"
	destination.add_theme_font_size_override("font_size", 22)
	destination.add_theme_color_override("font_color", DungeonTheme.COLOR_TEXT)
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	destination.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(destination)

	var return_rect := MobileSafeArea.bottom_anchored_rect(0.06, 0.24, 0.13)
	var depart_rect := MobileSafeArea.bottom_anchored_rect(0.66, 0.28, 0.13)
	var return_button := _make_action_button("ReturnButton", "정비\n돌아가기", return_rect, ACTION_RETURN)
	add_child(return_button)
	return_button.pressed.connect(_on_return_pressed)

	_depart_button = _make_action_button("GyeongbokgungButton", "밤의 경복궁\n진입", depart_rect, ACTION_SELECT_GYEONGBOKGUNG)
	add_child(_depart_button)
	_depart_button.pressed.connect(_on_gyeongbokgung_pressed)


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
	button.focus_mode = Control.FOCUS_NONE
	var variant := PixelButton.VARIANT_PRIMARY if action == ACTION_SELECT_GYEONGBOKGUNG else PixelButton.VARIANT_SECONDARY
	PixelButton.apply(button, variant, Vector2(0.0, 64.0))
	button.set_meta("test_id", action.replace(".", "_"))
	button.set_meta("uat_action", action)
	return button


func _count_action_entries(node: Node, action: String) -> int:
	var count := 1 if node.get_meta("uat_action", "") == action else 0
	for child: Node in node.get_children():
		count += _count_action_entries(child, action)
	return count


func _on_return_pressed() -> void:
	return_requested.emit()
	if scene_transition_enabled:
		SceneTransition.go_to_locker_maintenance()


func _on_gyeongbokgung_pressed() -> void:
	if _is_departure_requested:
		return
	_is_departure_requested = true
	if _depart_button != null:
		_depart_button.disabled = true
	stage_selected.emit(STAGE_GYEONGBOKGUNG)
	if scene_transition_enabled:
		var result := SceneTransition.start_session(get_departure_config())
		if result == OK:
			SceneTransition.clear_pending_run_config()
		else:
			_is_departure_requested = false
			if _depart_button != null:
				_depart_button.disabled = false
