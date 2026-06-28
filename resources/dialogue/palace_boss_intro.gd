class_name PalaceBossIntro
extends RefCounted
## 궁(경복궁) 보스 조우 인게임 대사 데이터.
## 야구부 주장 정화 이후 궁 안쪽에서 별도 보스가 플레이어를 막아서는 톤.
##
## 순서형 단방향 시퀀스(학교 day_school_rumors 의 가중치 랜덤과 다름).
## collect_beats()/includes_first_intro() 는 UI 없이 게이팅을 유닛 테스트할 수 있게 분리한 순수 로직.

const FIRST_INTRO_FLAG := &"palace_first_intro_shown"
const BOSS := preload("res://resources/dialogue/gyeongbokgung_boss_portrait.tres")
const BOSS_PORTRAIT_SCALE := Vector2(2.55, 2.55)
const BOSS_PORTRAIT_Y := 66.0

## 온보딩 첫 조우 — 앱 프로세스당 1회(SaveManager 메모리 플래그). 앱 재시작 시 다시 노출.
const INTRO_FIRST: Array[Dictionary] = [
	{"speaker": "도깨비왕", "portrait": BOSS, "portrait_scale": BOSS_PORTRAIT_SCALE, "portrait_y": BOSS_PORTRAIT_Y, "frame": 0, "text": "여기까지 걸어 들어온 인간은 오랜만이군."},
	{"speaker": "도깨비왕", "portrait": BOSS, "portrait_scale": BOSS_PORTRAIT_SCALE, "portrait_y": BOSS_PORTRAIT_Y, "frame": 0, "text": "궁의 밤은 내 것이다. 네가 찾는 아이도, 네 길도."},
	{"speaker": "도깨비왕", "portrait": BOSS, "portrait_scale": BOSS_PORTRAIT_SCALE, "portrait_y": BOSS_PORTRAIT_Y, "frame": 0, "text": "마지막 시즌의 배트 하나로 궁의 문을 열 수 있다고 믿었나."},
	{"speaker": "도깨비왕", "portrait": BOSS, "portrait_scale": BOSS_PORTRAIT_SCALE, "portrait_y": BOSS_PORTRAIT_Y, "frame": 0, "text": "좋다. 마지막 문 앞에서 네 힘을 증명해 봐라."},
]

## 보스 대면 — 매 입장(런)마다. 스킵 없이도 안 질리게 1줄.
const BOSS_ENCOUNTER: Array[Dictionary] = [
	{"speaker": "도깨비왕", "portrait": BOSS, "portrait_scale": BOSS_PORTRAIT_SCALE, "portrait_y": BOSS_PORTRAIT_Y, "frame": 0, "text": "다시 왔군. 이번엔 도망칠 길도 없다."},
]


## 이번 조우에서 재생할 비트 시퀀스(둘 중 하나).
## 첫 조우(first_shown=false) → INTRO_FIRST(마지막 줄이 전투 유도이므로 그 자체로 완결).
## 재입장(first_shown=true) → BOSS_ENCOUNTER 1줄.
## 순수 로직 — UI/노드 의존 없음(유닛 테스트 대상).
static func collect_beats(first_shown: bool) -> Array[Dictionary]:
	if first_shown:
		return BOSS_ENCOUNTER.duplicate()
	return INTRO_FIRST.duplicate()


## 이번 조우가 첫 조우 인트로를 포함하는지(완료 후 플래그 set 여부 판단용).
static func includes_first_intro(first_shown: bool) -> bool:
	return not first_shown
