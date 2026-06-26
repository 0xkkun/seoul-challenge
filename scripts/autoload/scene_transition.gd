extends Node

const LOBBY_SCENE := "res://scenes/lobby/lobby.tscn"
const SESSION_SCENE := "res://scenes/session/session_root.tscn"

var last_requested_scene := ""


func go_to_lobby() -> Error:
	last_requested_scene = LOBBY_SCENE
	return _change_scene(LOBBY_SCENE)


func start_session(config: Dictionary = {}) -> Error:
	last_requested_scene = SESSION_SCENE
	if has_node("/root/GameManager"):
		GameManager.start_session(config)
	return _change_scene(SESSION_SCENE)


func get_lobby_scene_path() -> String:
	return LOBBY_SCENE


func get_session_scene_path() -> String:
	return SESSION_SCENE


func _change_scene(scene_path: String) -> Error:
	if get_tree() == null:
		return ERR_UNCONFIGURED
	return get_tree().change_scene_to_file(scene_path)
