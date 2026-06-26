extends Node

var _profile: Dictionary = {
	"created": true,
	"session_results": [],
}


func load_profile() -> Dictionary:
	return _profile.duplicate(true)


func save_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	if not _profile.has("session_results"):
		_profile["session_results"] = []


func save_session_result(result: Dictionary) -> void:
	if not _profile.has("session_results"):
		_profile["session_results"] = []
	_profile["session_results"].append(result.duplicate(true))


func reset_profile() -> void:
	_profile = {
		"created": true,
		"session_results": [],
	}
