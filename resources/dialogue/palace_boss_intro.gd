class_name PalaceBossIntro
extends RefCounted
## 궁(경복궁) 보스 조우 인게임 대사 데이터.
## 빙의된 야구부 주장이 플레이어를 못 알아보고 "신입" 취급하는 거친 코치 톤.
## 호칭은 게임 전체 통일어 "야구부 주장".
##
## 순서형 단방향 시퀀스(학교 day_school_rumors 의 가중치 랜덤과 다름).
## collect_beats()/includes_first_intro() 는 UI 없이 게이팅을 유닛 테스트할 수 있게 분리한 순수 로직.

const FIRST_INTRO_FLAG := &"palace_first_intro_shown"
const CAPTAIN := preload("res://assets/characters/school/baseball_captain.png")

## 온보딩 첫 조우 — 앱 프로세스당 1회(SaveManager 메모리 플래그). 앱 재시작 시 다시 노출.
const INTRO_FIRST: Array[Dictionary] = [
	{"speaker": "야구부 주장", "portrait": CAPTAIN, "frame": 1, "text": "하! 새로운 녀석이 들어왔군."},
	{"speaker": "야구부 주장", "portrait": CAPTAIN, "frame": 1, "text": "여긴 우리 구역이야. 함부로 발 들이는 곳이 아니지."},
	{"speaker": "야구부 주장", "portrait": CAPTAIN, "frame": 1, "text": "…그 배트는 뻔하고. 신입 주제에 폼은 아네."},
	{"speaker": "야구부 주장", "portrait": CAPTAIN, "frame": 1, "text": "좋아. 입단 테스트다. 한 타석, 풀스윙으로 들어와."},
]

## 보스 대면 — 매 입장(런)마다. 스킵 없이도 안 질리게 1줄.
const BOSS_ENCOUNTER: Array[Dictionary] = [
	{"speaker": "야구부 주장", "portrait": CAPTAIN, "frame": 1, "text": "타석 들어와. 시간 없어."},
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
