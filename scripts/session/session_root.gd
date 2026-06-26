extends Node2D

const POOLED_MARKER_SCENE = preload("res://scenes/interactables/sample_pooled_marker.tscn")

@onready var actor: Node2D = %SampleActor
@onready var interactable_layer: Node = %InteractableLayer
@onready var sample_interactable: Node = %SampleInteractable
@onready var pooled_object_layer: Node = %PooledObjectLayer
@onready var interaction_system: Node = %InteractionSystem
@onready var session_ui_root: CanvasLayer = %SessionUIRoot

var completed_interactions := 0


func _ready() -> void:
	if not GameManager.is_session_active():
		GameManager.start_session({"source": "session_root"})
	PoolManager.register_scene(&"sample_marker", POOLED_MARKER_SCENE, 1, pooled_object_layer)
	interaction_system.configure(actor, interactable_layer)
	sample_interactable.interaction_triggered.connect(_on_interaction_triggered)
	session_ui_root.pause_requested.connect(_on_pause_requested)
	session_ui_root.resume_requested.connect(_on_resume_requested)
	session_ui_root.finish_requested.connect(_on_finish_requested)


func _exit_tree() -> void:
	if has_node("/root/PoolManager"):
		PoolManager.clear_all()
	if has_node("/root/GameManager") and GameManager.is_session_active():
		GameManager.reset_session()


func trigger_sample_interaction() -> int:
	return interaction_system.check_now(0.016)


func spawn_sample_marker() -> Node:
	var marker := PoolManager.acquire(&"sample_marker", pooled_object_layer)
	if marker != null and marker.has_method("activate_at"):
		marker.call("activate_at", actor.global_position + Vector2(24, 0))
	return marker


func finish_session() -> Dictionary:
	var result := {
		"interactions": completed_interactions,
		"active_markers": PoolManager.get_active_count(&"sample_marker"),
	}
	GameManager.finish_session(result)
	session_ui_root.show_summary(result)
	return result


func _on_interaction_triggered(_source: Node, _target: Node) -> void:
	completed_interactions += 1
	session_ui_root.set_status("Interaction complete")
	session_ui_root.set_interaction_count(completed_interactions)
	EventBus.emit_interaction_completed({"count": completed_interactions})
	spawn_sample_marker()


func _on_pause_requested() -> void:
	get_tree().paused = true
	session_ui_root.set_status("Paused")


func _on_resume_requested() -> void:
	get_tree().paused = false
	session_ui_root.set_status("Ready")


func _on_finish_requested() -> void:
	finish_session()
