extends Node

@export var touch_controls_path: NodePath

var _touch_controls: Node = null


func _ready() -> void:
	if not touch_controls_path.is_empty():
		_touch_controls = get_node_or_null(touch_controls_path)


func get_move() -> Vector2:
	if _touch_controls != null and _touch_controls.has_method("get_move"):
		return _touch_controls.get_move()
	return Vector2.ZERO


func is_attack_pressed() -> bool:
	return false


func is_dialogue_pressed() -> bool:
	if _touch_controls != null and _touch_controls.has_method("is_attack_pressed"):
		return bool(_touch_controls.is_attack_pressed())
	return false
