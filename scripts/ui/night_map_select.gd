class_name NightMapSelect
extends Control

signal return_requested
signal stage_selected(stage_id: StringName)

const STAGE_GYEONGBOKGUNG := &"gyeongbokgung"
const ACTION_RETURN := "night_map_select.return"
const ACTION_SELECT_GYEONGBOKGUNG := "night_map_select.gyeongbokgung"

@export var scene_transition_enabled := true

var _selected_stage_id := STAGE_GYEONGBOKGUNG
var _is_departure_requested := false
var _depart_button: Button


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
	background.color = Color(0.027451, 0.035294, 0.047059, 1.0)
	add_child(background)

	var title := Label.new()
	title.name = "TitleLabel"
	title.anchor_left = 0.05
	title.anchor_top = 0.06
	title.anchor_right = 0.48
	title.anchor_bottom = 0.15
	title.text = "지도 선택"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.941176, 0.811765, 0.392157, 1.0))
	add_child(title)

	var map_panel := PanelContainer.new()
	map_panel.name = "ExteriorMapPanel"
	map_panel.anchor_left = 0.12
	map_panel.anchor_top = 0.22
	map_panel.anchor_right = 0.70
	map_panel.anchor_bottom = 0.72
	map_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.705882, 0.635294, 0.431373, 1.0), Color(0.321569, 0.266667, 0.172549, 1.0), 3))
	add_child(map_panel)

	var map_label := Label.new()
	map_label.name = "MapLabel"
	map_label.text = "서울 외곽 궁궐 지도\n\n창덕궁          경복궁\n\n      덕수궁          종묘"
	map_label.add_theme_font_size_override("font_size", 27)
	map_label.add_theme_color_override("font_color", Color(0.101961, 0.12549, 0.156863, 1.0))
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_panel.add_child(map_label)

	var info_panel := PanelContainer.new()
	info_panel.name = "DestinationPanel"
	info_panel.anchor_left = 0.73
	info_panel.anchor_top = 0.22
	info_panel.anchor_right = 0.94
	info_panel.anchor_bottom = 0.72
	info_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.039216, 0.062745, 0.086275, 0.96), Color(0.784314, 0.631373, 0.227451, 1.0), 2))
	add_child(info_panel)

	var destination := Label.new()
	destination.name = "DestinationLabel"
	destination.text = "경복궁\n\n출몰 시간  야간\n위험도      보통\n권장 무기  기억 무기"
	destination.add_theme_font_size_override("font_size", 22)
	destination.add_theme_color_override("font_color", Color(0.909804, 0.92549, 0.956863, 1.0))
	destination.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	destination.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info_panel.add_child(destination)

	var return_button := _make_action_button("ReturnButton", "정비로", Rect2(0.06, 0.82, 0.24, 0.13), ACTION_RETURN)
	add_child(return_button)
	return_button.pressed.connect(_on_return_pressed)

	_depart_button = _make_action_button("GyeongbokgungButton", "경복궁으로", Rect2(0.66, 0.82, 0.28, 0.13), ACTION_SELECT_GYEONGBOKGUNG)
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
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color(0.937255, 0.960784, 0.988235, 1.0))
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.047059, 0.070588, 0.098039, 0.96), Color(0.403922, 0.909804, 0.976471, 0.86), 2))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.066667, 0.105882, 0.145098, 1.0), Color(0.403922, 0.909804, 0.976471, 1.0), 3))
	button.set_meta("test_id", action.replace(".", "_"))
	button.set_meta("uat_action", action)
	return button


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
	style.content_margin_left = 16
	style.content_margin_top = 14
	style.content_margin_right = 16
	style.content_margin_bottom = 14
	return style


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
