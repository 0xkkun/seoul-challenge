extends Node

const PROFILE_META_UPGRADES_KEY := "meta_upgrades"

var _profile: Dictionary = {
	"created": true,
	"session_results": [],
	"meta_upgrades": {},
}


func load_profile() -> Dictionary:
	return _profile.duplicate(true)


## 메타 업그레이드 레벨 조회(없으면 0).
func get_meta_upgrade_level(id: StringName) -> int:
	var ups: Dictionary = _profile.get(PROFILE_META_UPGRADES_KEY, {})
	return int(ups.get(id, 0))


## 모든 메타 업그레이드 레벨({id: level}) 복제 반환.
func get_meta_upgrades() -> Dictionary:
	return (_profile.get(PROFILE_META_UPGRADES_KEY, {}) as Dictionary).duplicate(true)


## 메타 업그레이드 레벨 설정(0 미만 클램프).
func set_meta_upgrade_level(id: StringName, level: int) -> void:
	if not _profile.has(PROFILE_META_UPGRADES_KEY):
		_profile[PROFILE_META_UPGRADES_KEY] = {}
	_profile[PROFILE_META_UPGRADES_KEY][id] = maxi(0, level)


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
		"meta_upgrades": {},
	}
