extends Control

@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	start_button.set_meta("test_id", "lobby.start_button")
	start_button.set_meta("uat_action", "lobby.start")
	start_button.pressed.connect(_on_start_pressed)
	status_label.text = "Ready"


func _on_start_pressed() -> void:
	status_label.text = "Starting"
	SceneTransition.start_session({"source": "lobby"})
