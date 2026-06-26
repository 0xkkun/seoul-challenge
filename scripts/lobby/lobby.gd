extends Control

const BACKGROUND_CROP_ANCHOR := Vector2(0.5, 0.0)

@onready var background: TextureRect = $Background
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var status_label: Label = %StatusLabel

var _start_requested := false


func _ready() -> void:
	start_button.set_meta("test_id", "lobby.start_button")
	resized.connect(_fit_background_to_viewport)
	_fit_background_to_viewport()
	start_button.set_meta("uat_action", "lobby.start")
	start_button.pressed.connect(_on_start_pressed)
	settings_button.set_meta("uat_action", "lobby.settings")
	settings_button.pressed.connect(_on_settings_pressed)
	status_label.text = ""
	status_label.visible = false
	start_button.grab_focus()


func _on_start_pressed() -> void:
	if _start_requested:
		return
	_start_requested = true
	start_button.disabled = true
	call_deferred("_go_to_day_lobby")


func _on_settings_pressed() -> void:
	pass


func _go_to_day_lobby() -> void:
	var result := SceneTransition.go_to_day_lobby()
	if result == OK:
		return
	_start_requested = false
	start_button.disabled = false
	push_error("Failed to open day lobby scene: %s" % result)


func get_background_cover_rect(target_size: Vector2, texture_size: Vector2) -> Rect2:
	return _get_background_cover_rect(target_size, texture_size)


func _fit_background_to_viewport() -> void:
	if background == null or background.texture == null:
		return
	var target_size := size
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		target_size = get_viewport_rect().size
	var cover_rect := _get_background_cover_rect(target_size, background.texture.get_size())
	background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	background.position = cover_rect.position
	background.size = cover_rect.size
	background.stretch_mode = TextureRect.STRETCH_SCALE


func _get_background_cover_rect(target_size: Vector2, texture_size: Vector2) -> Rect2:
	if target_size.x <= 0.0 or target_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, target_size)
	var cover_scale := maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
	var cover_size := texture_size * cover_scale
	var overflow := cover_size - target_size
	var offset := Vector2(
		-overflow.x * BACKGROUND_CROP_ANCHOR.x,
		-overflow.y * BACKGROUND_CROP_ANCHOR.y
	)
	return Rect2(offset, cover_size)
