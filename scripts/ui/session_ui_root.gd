extends CanvasLayer

signal pause_requested
signal resume_requested
signal finish_requested

@onready var status_label: Label = %StatusLabel
@onready var interaction_label: Label = %InteractionLabel
@onready var summary_label: Label = %SummaryLabel
@onready var pause_button: Button = %PauseButton
@onready var resume_button: Button = %ResumeButton
@onready var finish_button: Button = %FinishButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.set_meta("uat_action", "session.pause")
	resume_button.set_meta("uat_action", "session.resume")
	finish_button.set_meta("uat_action", "session.finish")
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	finish_button.pressed.connect(func() -> void: finish_requested.emit())
	set_status("Ready")
	set_interaction_count(0)
	show_summary({})


func set_status(text: String) -> void:
	status_label.text = text


func set_interaction_count(count: int) -> void:
	interaction_label.text = "Interactions: %d" % count


func show_summary(result: Dictionary) -> void:
	if result.is_empty():
		summary_label.text = "Summary: pending"
	else:
		summary_label.text = "Summary: %s" % str(result)
