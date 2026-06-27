extends Node
## #93 야구부 정화 진행도 — friend_purified 를 받아 STAGE/무기 해금을 SaveManager profile 에 저장한다.
## 요기/원한 자원은 MVP 범위 밖. 야구부 하나만 끝까지 완결되게 다룬다.

const PROFILE_KEY := "progression"
const BASEBALL_CLUB := &"baseball"
const AWAKENED_BAT := &"awakened_bat"
const PURIFIED_STAGE := 3

## friend_id -> club_id (MVP: 야구부 주장 하나).
const FRIEND_CLUBS := {
	&"baseball_captain": &"baseball",
}

## club_id -> 정화 시 해금되는 무기들.
const CLUB_AWAKEN_WEAPONS := {
	&"baseball": [&"awakened_bat"],
}

var _purified_friend_ids: Array[StringName] = []
var _club_stages: Dictionary = {}
var _unlocked_weapons: Dictionary = {}


func _ready() -> void:
	reload_profile()
	_connect_event_signals()


# --- 조회 ---

func is_friend_purified(friend_id: StringName) -> bool:
	return _purified_friend_ids.has(friend_id)


func get_club_stage(club_id: StringName) -> int:
	return int(_club_stages.get(club_id, 0))


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return bool(_unlocked_weapons.get(weapon_id, false))


# --- 기록 ---

## 친구 정화 기록 — 야구부 주장이면 STAGE 3 + 각성 배트를 해금하고 profile 에 저장한다.
func record_friend_purified(friend_id: StringName) -> void:
	var unlocks: Array[StringName] = []
	var changed := false

	if not _purified_friend_ids.has(friend_id):
		_purified_friend_ids.append(friend_id)
		changed = true

	if FRIEND_CLUBS.has(friend_id):
		var club: StringName = FRIEND_CLUBS[friend_id]
		if get_club_stage(club) < PURIFIED_STAGE:
			_club_stages[club] = PURIFIED_STAGE
			changed = true
			unlocks.append(StringName("%s_stage_%d" % [String(club), PURIFIED_STAGE]))
		for weapon: StringName in CLUB_AWAKEN_WEAPONS.get(club, []):
			if not is_weapon_unlocked(weapon):
				_unlocked_weapons[weapon] = true
				changed = true
				unlocks.append(weapon)

	if not changed:
		return
	_save()
	_emit_unlock_changed(friend_id, unlocks)


# --- 저장/로드 ---

func reload_profile() -> void:
	_purified_friend_ids = []
	_club_stages = {}
	_unlocked_weapons = {}
	if not has_node("/root/SaveManager"):
		return

	var profile := SaveManager.load_profile()
	var data: Dictionary = profile.get(PROFILE_KEY, {})
	for fid: Variant in data.get("purified_friend_ids", []):
		var sid := StringName(fid)
		if not _purified_friend_ids.has(sid):
			_purified_friend_ids.append(sid)
	for club: Variant in data.get("club_stages", {}):
		_club_stages[StringName(club)] = int(data["club_stages"][club])
	for weapon: Variant in data.get("unlocked_weapons", {}):
		_unlocked_weapons[StringName(weapon)] = bool(data["unlocked_weapons"][weapon])


func reset_for_tests() -> void:
	reload_profile()


func _save() -> void:
	if not has_node("/root/SaveManager"):
		return
	var profile := SaveManager.load_profile()
	profile[PROFILE_KEY] = {
		"purified_friend_ids": _purified_friend_ids.duplicate(),
		"club_stages": _club_stages.duplicate(),
		"unlocked_weapons": _unlocked_weapons.duplicate(),
	}
	SaveManager.save_profile(profile)


# --- EventBus 연결 ---

func _connect_event_signals() -> void:
	if not has_node("/root/EventBus"):
		return
	if EventBus.has_signal(&"friend_purified") and not EventBus.is_connected(&"friend_purified", _on_friend_purified):
		EventBus.connect(&"friend_purified", _on_friend_purified)


func _on_friend_purified(payload: Dictionary) -> void:
	var fid := StringName(payload.get("friend_id", &""))
	if fid == &"":
		return
	record_friend_purified(fid)


func _emit_unlock_changed(friend_id: StringName, unlocks: Array[StringName]) -> void:
	if not has_node("/root/EventBus"):
		return
	EventBus.emit_unlock_changed({
		"friend_id": friend_id,
		"unlocks": unlocks.duplicate(),
		"club_stages": _club_stages.duplicate(),
	})
