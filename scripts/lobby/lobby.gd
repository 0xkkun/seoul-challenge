extends Control

const BACKGROUND_CROP_ANCHOR := Vector2(0.5, 0.0)

@onready var background: TextureRect = $Background
@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var status_label: Label = %StatusLabel
@onready var _confirm_modal: ConfirmModal = %ConfirmModal
@onready var _settings_ui: SettingsUI = %SettingsUI

var quit_game_callable: Callable

var _start_requested := false


func _ready() -> void:
	SceneTransition.configure_exit_requests()
	AudioManager.play_bgm(AudioManager.LOBBY_BGM_DEFAULT)
	start_button.set_meta("test_id", "lobby.start_button")
	resized.connect(_fit_background_to_viewport)
	_fit_background_to_viewport()
	start_button.set_meta("uat_action", "lobby.start")
	start_button.pressed.connect(_on_start_pressed)
	start_button.focus_mode = Control.FOCUS_NONE
	PixelButtonStyle.attach_press_sfx(start_button)
	settings_button.set_meta("test_id", "lobby.settings_button")
	settings_button.set_meta("uat_action", "lobby.settings")
	settings_button.pressed.connect(_on_settings_pressed)
	settings_button.disabled = false
	settings_button.focus_mode = Control.FOCUS_NONE
	PixelButtonStyle.attach_press_sfx(settings_button)
	status_label.text = ""
	status_label.visible = false


func is_quit_confirm_visible() -> bool:
	return _confirm_modal.is_open()


func get_quit_confirm_message() -> String:
	return _confirm_modal.get_message_text()


func is_settings_open() -> bool:
	return _settings_ui.is_open()


func _on_start_pressed() -> void:
	if _start_requested:
		return
	_start_requested = true
	start_button.disabled = true
	call_deferred("_go_to_day_lobby")


func _go_to_day_lobby() -> void:
	var result := SceneTransition.go_to_day_lobby()
	if result == OK:
		return
	_start_requested = false
	start_button.disabled = false
	push_error("Failed to open day lobby scene: %s" % result)


func _on_settings_pressed() -> void:
	Settings.try_vibrate(18)
	_settings_ui.open()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			if _settings_ui.is_open():
				_settings_ui.close()
				return
			_request_quit_game()
		NOTIFICATION_APPLICATION_PAUSED:
			SceneTransition.save_profile_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if _settings_ui.is_open():
		return
	if _confirm_modal.is_open():
		return
	if event.is_action_pressed(&"ui_cancel") or _is_escape_key(event):
		_request_quit_game()
		get_viewport().set_input_as_handled()


func _request_quit_game() -> void:
	if _confirm_modal.is_open():
		return
	_confirm_modal.open(
		"게임을 종료할까요?",
		Callable(self, "_quit_game"),
		Callable()
	)


func _quit_game() -> void:
	if quit_game_callable.is_valid():
		quit_game_callable.call()
	else:
		SceneTransition.quit_game()


func _is_escape_key(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE


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
