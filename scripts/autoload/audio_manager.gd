extends Node

var _played_sfx: Array[StringName] = []
var _current_bgm: StringName = &""


func play_sfx(id: StringName) -> void:
	_played_sfx.append(id)


func play_bgm(id: StringName) -> void:
	_current_bgm = id


func stop_bgm() -> void:
	_current_bgm = &""


func get_current_bgm() -> StringName:
	return _current_bgm


func get_played_sfx() -> Array[StringName]:
	return _played_sfx.duplicate()


func reset() -> void:
	_played_sfx.clear()
	_current_bgm = &""
