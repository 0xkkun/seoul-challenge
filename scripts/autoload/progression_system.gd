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

## 로비 퀘스트 id. 정화 후 로비에서 야구부 주장과 재대화를 완료하면 강화배트가 해금된다 (#243).
const QUEST_BASEBALL_CAPTAIN_LOBBY := &"baseball_captain_lobby"

var _purified_friend_ids: Array[StringName] = []
var _club_stages: Dictionary = {}
var _unlocked_weapons: Dictionary = {}
var _completed_quests: Dictionary = {}


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


func is_quest_completed(quest_id: StringName) -> bool:
	return bool(_completed_quests.get(quest_id, false))


# --- 기록 ---

## 친구 정화 기록 — 야구부 주장이면 STAGE 3 을 기록하고 profile 에 저장한다.
## #243: 강화배트는 더 이상 정화 시점에 해금하지 않는다. 로비 퀘스트 완료(record_quest_completed)에서 해금한다.
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

	if not changed:
		return
	_save()
	_emit_unlock_changed(friend_id, unlocks)


## 로비 퀘스트 완료 기록 — 야구부 주장 로비 퀘스트면 강화배트를 해금한다 (#243). 멱등.
func record_quest_completed(quest_id: StringName) -> void:
	if is_quest_completed(quest_id):
		return
	_completed_quests[quest_id] = true

	var unlocks: Array[StringName] = []
	if quest_id == QUEST_BASEBALL_CAPTAIN_LOBBY:
		_apply_weapon_unlocks([AWAKENED_BAT], unlocks)

	_save()
	# 야구부 주장 라인의 퀘스트이므로 friend_id 로 baseball_captain 을 싣는다(HubDialogueUi 가드 통과용).
	_emit_unlock_changed(&"baseball_captain", unlocks)


## 무기 집합을 해금하고, *실제로 새로 해금된* 무기만 out_unlocks 에 추가한다.
## 이미 해금된 무기는 다시 emit 하지 않아 가짜 중복 보상 팝업을 막는다 (#243).
func _apply_weapon_unlocks(weapons: Array, out_unlocks: Array[StringName]) -> void:
	for weapon: Variant in weapons:
		var weapon_id := StringName(weapon)
		if not is_weapon_unlocked(weapon_id):
			_unlocked_weapons[weapon_id] = true
			out_unlocks.append(weapon_id)


# --- 저장/로드 ---

func reload_profile() -> void:
	_purified_friend_ids = []
	_club_stages = {}
	_unlocked_weapons = {}
	_completed_quests = {}
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
	for quest: Variant in data.get("completed_quests", {}):
		_completed_quests[StringName(quest)] = bool(data["completed_quests"][quest])


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
		"completed_quests": _completed_quests.duplicate(),
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
