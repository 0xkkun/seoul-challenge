class_name DaySchoolRumors
extends RefCounted

## 낮 학교 허브(낮 복도)의 NPC 소문/대사 단일 데이터 소스 (Issue #202).
##
## 한 표(ENTRIES)에 화자/진행도 tier/연결 시스템/전달 방식 메타를 태그하고,
## 셀렉터가 화자·tier·컨텍스트로 필터한다. 씬 스크립트는 이 모듈을 읽기만 한다.
##
## 진행도 tier 모델 (eng-review 재정의):
##   first_visit    : 친구 정화 전
##   post_purify    : 정화됨, 강화배트 전
##   post_enhanced  : 강화배트(awakened_bat) 해금 후 (로비 퀘스트, #243 선행)
## 현재 코드는 정화 시점에 강화배트를 즉시 언락하므로 post_purify는 #243 전까지
## 도달 불가 — current_tier가 자연히 2단계로 graceful degrade한다.
##
## ENTRIES 필드:
##   id          : StringName 고유 id
##   speaker     : &"people2" | &"people3" | &"people4"
##   tier        : &"first_visit" | &"post_purify" | &"post_enhanced"
##   system_link : &"memory_weapon" | &"locker" | &"purify_friend" | &"night_palace"
##   text        : 본문
##   memory      : people2(dialogue) 보조 기억 라인. 그 외 화자는 "".
##   weight      : people4(ambient_crowd) 가중치. 그 외 1.
##   condition   : (선택) E1 동적 소문 게이트. &"" | &"last_run_died" | &"last_run_cleared".
##                 컨텍스트 last_run과 일치할 때만 후보. 없으면 항상 후보.
## delivery는 두지 않는다 — DELIVERY_BY_SPEAKER로 speaker에서 파생한다.

const TIER_FIRST_VISIT := &"first_visit"
const TIER_POST_PURIFY := &"post_purify"
const TIER_POST_ENHANCED := &"post_enhanced"

const FRIEND_BASEBALL_CAPTAIN := &"baseball_captain"
const WEAPON_AWAKENED_BAT := &"awakened_bat"

const DELIVERY_DIALOGUE := &"dialogue"
const DELIVERY_AMBIENT := &"ambient"
const DELIVERY_AMBIENT_CROWD := &"ambient_crowd"

const SPEAKER_PEOPLE2 := &"people2"
const SPEAKER_PEOPLE3 := &"people3"
const SPEAKER_PEOPLE4 := &"people4"

const VALID_TIERS: Array[StringName] = [TIER_FIRST_VISIT, TIER_POST_PURIFY, TIER_POST_ENHANCED]
const VALID_SPEAKERS: Array[StringName] = [SPEAKER_PEOPLE2, SPEAKER_PEOPLE3, SPEAKER_PEOPLE4]
const VALID_CONDITIONS: Array[StringName] = [&"", &"last_run_died", &"last_run_cleared"]

const DELIVERY_BY_SPEAKER := {
	SPEAKER_PEOPLE2: DELIVERY_DIALOGUE,
	SPEAKER_PEOPLE3: DELIVERY_AMBIENT,
	SPEAKER_PEOPLE4: DELIVERY_AMBIENT_CROWD,
}

## 화자 id → 표시 이름/포트레이트 메타. set_dialogue 1번째 인자는 표시 이름이지 id가 아님.
const SPEAKER_META := {
	SPEAKER_PEOPLE2: {
		"display_name": "반 친구",
		"portrait": "res://assets/characters/school/people2.png",
		"portrait_frame": 1,  # frame 1 = 눈뜬 정적 (test_hub_dialogue_ui.gd)
	},
	SPEAKER_PEOPLE3: {"display_name": "지나가던 학생", "portrait": "", "portrait_frame": 0},
	SPEAKER_PEOPLE4: {"display_name": "복도의 웅성거림", "portrait": "", "portrait_frame": 0},
}

const ENTRIES: Array[Dictionary] = [
	# ── people2 (dialogue) — 모든 reachable tier에 ≥1줄 (% size 나눗셈 안전) ──
	{"id": &"p2_first_1", "speaker": SPEAKER_PEOPLE2, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 1, "condition": &"",
	 "text": "낮엔 뛰지 말고, 얘기부터 하자.", "memory": "기억: 창밖으로 밀려드는 낮빛"},
	{"id": &"p2_first_2", "speaker": SPEAKER_PEOPLE2, "tier": TIER_FIRST_VISIT,
	 "system_link": &"locker", "weight": 1, "condition": &"",
	 "text": "복도 끝 교실에 들르면 준비가 끝나.", "memory": "기억: 복도 끝 교실 문손잡이"},
	{"id": &"p2_first_3", "speaker": SPEAKER_PEOPLE2, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 1, "condition": &"",
	 "text": "밤에 나가기 전에 여기서 필요한 얘기를 끝내자.", "memory": "기억: 야자 시작 전의 짧은 정적"},
	{"id": &"p2_purify_1", "speaker": SPEAKER_PEOPLE2, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 1, "condition": &"",
	 "text": "야구부 주장 돌아왔어. 너 기다리더라 — 가서 말 걸어 봐.", "memory": "기억: 운동장에 돌아온 보통의 소음"},
	{"id": &"p2_purify_2", "speaker": SPEAKER_PEOPLE2, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 1, "condition": &"",
	 "text": "걔가 마지막 시즌 배트를 너한테 넘기고 싶대. 받아 둬.", "memory": "기억: 주장이 내밀던 낡은 배트 손잡이"},
	{"id": &"p2_enh_1", "speaker": SPEAKER_PEOPLE2, "tier": TIER_POST_ENHANCED,
	 "system_link": &"memory_weapon", "weight": 1, "condition": &"",
	 "text": "그거 챙겼구나. 손에 익혀 둬, 밤엔 설명 안 해줘.", "memory": "기억: 사물함 안쪽의 차가운 손잡이"},

	# ── people3 (ambient, 근접 라벨) ──
	{"id": &"p3_first_locker", "speaker": SPEAKER_PEOPLE3, "tier": TIER_FIRST_VISIT,
	 "system_link": &"locker", "weight": 1, "condition": &"", "memory": "",
	 "text": "복도 끝 사물함, 밤만 되면 안에서 딱딱 소리 난대."},
	{"id": &"p3_first_window", "speaker": SPEAKER_PEOPLE3, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 1, "condition": &"", "memory": "",
	 "text": "야자 전에 창밖 봤어? 운동장이 이상하게 멀어 보여."},
	{"id": &"p3_purify_calm", "speaker": SPEAKER_PEOPLE3, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 1, "condition": &"", "memory": "",
	 "text": "요즘 복도 끝, 소리 안 난대. 누가 정리했나 봐."},
	{"id": &"p3_enh_locker", "speaker": SPEAKER_PEOPLE3, "tier": TIER_POST_ENHANCED,
	 "system_link": &"memory_weapon", "weight": 1, "condition": &"", "memory": "",
	 "text": "사물함에서 뭘 꺼낸 애가 있다던데… 너야?"},
	# E3 foreshadow (낮은 빈도, 밤 궁 복선)
	{"id": &"p3_fs_gate", "speaker": SPEAKER_PEOPLE3, "tier": TIER_POST_PURIFY,
	 "system_link": &"night_palace", "weight": 1, "condition": &"", "memory": "",
	 "text": "정문이 밤마다 다른 데로 이어진대… 농담이지?"},

	# ── people4 (ambient_crowd, weighted) ──
	{"id": &"p4_first_missing", "speaker": SPEAKER_PEOPLE4, "tier": TIER_FIRST_VISIT,
	 "system_link": &"purify_friend", "weight": 2, "condition": &"", "memory": "",
	 "text": "…누가 또 안 나왔대."},
	{"id": &"p4_first_lockernoise", "speaker": SPEAKER_PEOPLE4, "tier": TIER_FIRST_VISIT,
	 "system_link": &"locker", "weight": 2, "condition": &"", "memory": "",
	 "text": "사물함에서 소리 났다니까, 진짜로."},
	{"id": &"p4_first_palace", "speaker": SPEAKER_PEOPLE4, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 1, "condition": &"", "memory": "",
	 "text": "밤에 운동장이 꼭 궁처럼 보였대."},
	{"id": &"p4_purify_back", "speaker": SPEAKER_PEOPLE4, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 2, "condition": &"", "memory": "",
	 "text": "어, 걔 돌아왔네. 멀쩡하잖아."},
	{"id": &"p4_purify_eyes", "speaker": SPEAKER_PEOPLE4, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 1, "condition": &"", "memory": "",
	 "text": "걔 눈빛 좀 변하지 않았어?"},
	{"id": &"p4_enh_weapon", "speaker": SPEAKER_PEOPLE4, "tier": TIER_POST_ENHANCED,
	 "system_link": &"memory_weapon", "weight": 1, "condition": &"", "memory": "",
	 "text": "누가 사물함에서 방망이 같은 걸 꺼냈대."},
	# E1 동적 소문 (직전 밤런 결과 참조)
	{"id": &"p4_died_cried", "speaker": SPEAKER_PEOPLE4, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 2, "condition": &"last_run_died", "memory": "",
	 "text": "어제 밤에 운동장에서 누가 울었대."},
	{"id": &"p4_cleared_fine", "speaker": SPEAKER_PEOPLE4, "tier": TIER_POST_PURIFY,
	 "system_link": &"purify_friend", "weight": 2, "condition": &"last_run_cleared", "memory": "",
	 "text": "걔 요즘 멀쩡해 보여, 다행이지."},
	# E3 foreshadow
	{"id": &"p4_fs_throne", "speaker": SPEAKER_PEOPLE4, "tier": TIER_FIRST_VISIT,
	 "system_link": &"night_palace", "weight": 1, "condition": &"", "memory": "",
	 "text": "밤엔 운동장 끝에 큰 의자 같은 게 보였대."},
]


## 진행도 플래그로 현재 tier를 해석. 가장 진행된 단계부터 검사.
static func current_tier(progression: Object) -> StringName:
	if progression == null:
		return TIER_FIRST_VISIT
	if progression.is_weapon_unlocked(WEAPON_AWAKENED_BAT):
		return TIER_POST_ENHANCED
	if progression.is_friend_purified(FRIEND_BASEBALL_CAPTAIN):
		return TIER_POST_PURIFY
	return TIER_FIRST_VISIT


static func delivery_for(speaker: StringName) -> StringName:
	return DELIVERY_BY_SPEAKER.get(speaker, DELIVERY_AMBIENT)


static func speaker_meta(speaker: StringName) -> Dictionary:
	return SPEAKER_META.get(speaker, {"display_name": "", "portrait": "", "portrait_frame": 0})


static func _condition_ok(entry: Dictionary, context: Dictionary) -> bool:
	var cond := StringName(entry.get("condition", &""))
	if cond == &"":
		return true
	return StringName(context.get("last_run", &"")) == _condition_last_run(cond)


static func _condition_last_run(cond: StringName) -> StringName:
	match cond:
		&"last_run_died":
			return &"died"
		&"last_run_cleared":
			return &"cleared"
		_:
			return &""


## 화자+tier로 정렬된 엔트리 배열. condition은 context로 평가.
## condition 일치 엔트리가 하나도 없으면 condition 없는(항상 후보) 풀로 폴백.
static func pick_lines(speaker: StringName, tier: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var base: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		if entry.speaker == speaker and entry.tier == tier:
			base.append(entry)
	var matched: Array[Dictionary] = []
	for entry: Dictionary in base:
		if _condition_ok(entry, context):
			matched.append(entry)
	# 폴백: condition 없는 엔트리만 (빈 결과 방지)
	if matched.is_empty():
		for entry: Dictionary in base:
			if StringName(entry.get("condition", &"")) == &"":
				matched.append(entry)
	return matched


## people4 군중: tier 풀에서 weight 가중 무작위 1개. 빈 풀이면 {} 반환.
static func pick_crowd_fragment(tier: StringName, rng: RandomNumberGenerator, context: Dictionary = {}) -> Dictionary:
	var pool := pick_lines(SPEAKER_PEOPLE4, tier, context)
	if pool.is_empty():
		return {}
	var total := 0
	for entry: Dictionary in pool:
		total += maxi(1, int(entry.get("weight", 1)))
	if total <= 0 or rng == null:
		return pool[0]
	var roll := rng.randi_range(1, total)
	var acc := 0
	for entry: Dictionary in pool:
		acc += maxi(1, int(entry.get("weight", 1)))
		if roll <= acc:
			return entry
	return pool[-1]


## 데이터 무결성 검증 (테스트/디버그용). 문제 메시지 배열 반환(빈 배열 = 정상).
static func validate() -> Array[String]:
	var problems: Array[String] = []
	var seen_ids := {}
	var dialogue_tier_counts := {}
	for entry: Dictionary in ENTRIES:
		var id := StringName(entry.get("id", &""))
		if id == &"":
			problems.append("엔트리에 id 없음: %s" % str(entry))
			continue
		if seen_ids.has(id):
			problems.append("중복 id: %s" % str(id))
		seen_ids[id] = true
		var speaker := StringName(entry.get("speaker", &""))
		if not VALID_SPEAKERS.has(speaker):
			problems.append("%s: 잘못된 speaker %s" % [str(id), str(speaker)])
		var tier := StringName(entry.get("tier", &""))
		if not VALID_TIERS.has(tier):
			problems.append("%s: 잘못된 tier %s" % [str(id), str(tier)])
		if not VALID_CONDITIONS.has(StringName(entry.get("condition", &""))):
			problems.append("%s: 잘못된 condition %s" % [str(id), str(entry.get("condition", &""))])
		if String(entry.get("text", "")).strip_edges() == "":
			problems.append("%s: 빈 text" % str(id))
		if int(entry.get("weight", 1)) < 1:
			problems.append("%s: weight < 1" % str(id))
		if speaker == SPEAKER_PEOPLE2:
			dialogue_tier_counts[tier] = int(dialogue_tier_counts.get(tier, 0)) + 1
		else:
			if String(entry.get("memory", "")) != "":
				problems.append("%s: ambient 화자는 memory 비워야 함" % str(id))
	# people2(dialogue)는 모든 tier에 ≥1줄이어야 % size 나눗셈 안전
	for tier: StringName in VALID_TIERS:
		if int(dialogue_tier_counts.get(tier, 0)) < 1:
			problems.append("people2 tier %s에 대사 없음 (나눗셈 위험)" % str(tier))
	return problems
