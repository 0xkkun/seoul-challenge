extends Node2D

@export var move_speed := 96.0

var last_input_vector := Vector2.ZERO


func _process(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	apply_input_vector(input_vector, delta)


func apply_input_vector(input_vector: Vector2, delta: float) -> void:
	last_input_vector = input_vector
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	position += input_vector * move_speed * delta
