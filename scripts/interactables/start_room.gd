class_name StartRoom
extends Room

var _tutorial_gate_active := false


func _ready() -> void:
	room_type = &"start"
	super._ready()


func is_cleared() -> bool:
	return not _tutorial_gate_active


func set_tutorial_gate_active(active: bool) -> void:
	if _tutorial_gate_active == active:
		return
	_tutorial_gate_active = active
	if active:
		_cleared = false
		_apply_door_state()
	else:
		mark_cleared()


func is_tutorial_gate_active() -> bool:
	return _tutorial_gate_active
