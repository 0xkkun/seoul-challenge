extends Node2D

var activated_count := 0
var reset_count := 0


func activate_from_pool() -> void:
	activated_count += 1


func activate_at(target_position: Vector2) -> void:
	global_position = target_position


func reset_for_pool() -> void:
	reset_count += 1
	position = Vector2.ZERO
