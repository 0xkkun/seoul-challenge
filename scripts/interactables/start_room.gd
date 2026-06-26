class_name StartRoom
extends Room


func _ready() -> void:
	room_type = &"start"
	super._ready()


func is_cleared() -> bool:
	return true
