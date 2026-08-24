class_name InputPromptStrip
extends HBoxContainer

const MOUSE_LEFT := preload("res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png")
const MOUSE_RIGHT := preload("res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png")
const MOUSE_LEFT_PATH := "res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_left.png"
const MOUSE_RIGHT_PATH := "res://assets/ui/input_prompts/kenney_pixel_1bit/mouse_right.png"
const ICON_SIZE := Vector2(48.0, 48.0)
const KEY_SIZE := Vector2(28.0, 28.0)
const SHIFT_SIZE := Vector2(68.0, 34.0)
const DESKTOP_MODE := &"desktop"
const OnboardingVisualTokens := preload("res://scripts/ui/onboarding_visual_tokens.gd")
const UiFontRoles := preload("res://scripts/ui/ui_font_roles.gd")

var _actions: Array[StringName] = []
var _texture_paths: Array[String] = []
var _keycaps: Array[String] = []


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(actions: Array, input_mode: StringName) -> void:
	_clear_contents()
	if input_mode != DESKTOP_MODE:
		visible = false
		return
	for action: Variant in actions:
		var action_id := StringName(action)
		if _is_supported(action_id):
			_actions.append(action_id)
	visible = not _actions.is_empty()
	if not visible:
		return
	for index: int in range(_actions.size()):
		if index > 0:
			_add_arrow()
		_add_action(_actions[index])


func get_snapshot() -> Dictionary:
	return {
		"actions": _actions.duplicate(),
		"texture_paths": _texture_paths.duplicate(),
		"keycaps": _keycaps.duplicate(),
		"visible_copy": " ".join(_keycaps),
		"texture_filter": CanvasItem.TEXTURE_FILTER_NEAREST,
		"visible": visible,
	}


func _clear_contents() -> void:
	_actions.clear()
	_texture_paths.clear()
	_keycaps.clear()
	for child: Node in get_children():
		remove_child(child)
		child.free()


func _is_supported(action: StringName) -> bool:
	return action in [&"move", &"primary_click", &"aim_hold", &"attack", &"dash"]


func _add_action(action: StringName) -> void:
	match action:
		&"move":
			_add_wasd_cluster()
		&"primary_click", &"attack":
			_add_texture(MOUSE_LEFT, MOUSE_LEFT_PATH)
		&"aim_hold":
			_add_texture(MOUSE_RIGHT, MOUSE_RIGHT_PATH)
		&"dash":
			_add_keycap("SHIFT", SHIFT_SIZE)


func _add_texture(texture: Texture2D, path: String) -> void:
	var icon := TextureRect.new()
	icon.name = "InputIcon%d" % _texture_paths.size()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = OnboardingVisualTokens.PAPER_TEXT
	add_child(icon)
	_texture_paths.append(path)


func _add_keycap(text: String, minimum_size: Vector2 = KEY_SIZE) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%sKey" % text
	panel.custom_minimum_size = minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", OnboardingVisualTokens.key_chip_style(&"info"))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", OnboardingVisualTokens.PAPER_TEXT)
	UiFontRoles.apply_pixel(label)
	panel.add_child(label)
	add_child(panel)
	_keycaps.append(text)
	return panel


func _add_wasd_cluster() -> void:
	var cluster := GridContainer.new()
	cluster.name = "WASDCluster"
	cluster.columns = 3
	cluster.add_theme_constant_override("h_separation", 2)
	cluster.add_theme_constant_override("v_separation", 2)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for text: String in ["", "W", "", "A", "S", "D"]:
		if text == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = KEY_SIZE
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cluster.add_child(spacer)
		else:
			var key := _create_keycap(text, KEY_SIZE)
			cluster.add_child(key)
	add_child(cluster)
	_keycaps.append("WASD")


func _create_keycap(text: String, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "%sKey" % text
	panel.custom_minimum_size = minimum_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", OnboardingVisualTokens.key_chip_style(&"info"))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", OnboardingVisualTokens.PAPER_TEXT)
	UiFontRoles.apply_pixel(label)
	panel.add_child(label)
	return panel


func _add_arrow() -> void:
	var arrow := Label.new()
	arrow.name = "SequenceArrow"
	arrow.text = "→"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size", 22)
	arrow.add_theme_color_override("font_color", OnboardingVisualTokens.GOLD_INFO)
	UiFontRoles.apply_title(arrow)
	add_child(arrow)
