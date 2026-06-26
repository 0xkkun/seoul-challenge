extends Control

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	start_button.set_meta("test_id", "lobby.start_button")
	start_button.set_meta("uat_action", "lobby.start")
	start_button.pressed.connect(_on_start_pressed)
	settings_button.set_meta("uat_action", "lobby.settings")
	settings_button.pressed.connect(_on_settings_pressed)
	status_label.text = ""
	status_label.visible = false
	start_button.grab_focus()


func _on_start_pressed() -> void:
	SceneTransition.start_session({"source": "lobby"})


func _on_settings_pressed() -> void:
	pass
