class_name BaseballOnboardingIntro
extends RefCounted
## 첫 야구부 온보딩의 정화 대상 조우 대사 데이터.
## 세션 루트가 friend_1 입장 직후 전투를 잠시 멈추고 순서대로 재생한다.

const YOKAI_CAPTAIN := preload("res://assets/sprites/enemies/yokai_friend/yokai_friend_move.png")

const INTRO_FIRST: Array[Dictionary] = [
	{"speaker": "요괴 야구부 주장", "portrait": YOKAI_CAPTAIN, "frame": 1, "text": "하… 새로 들어온 녀석인가. 타석에 서."},
	{"speaker": "요괴 야구부 주장", "portrait": YOKAI_CAPTAIN, "frame": 3, "text": "그 배트, 아직 네 손에 없지? 그럼 몸으로 먼저 배워."},
	{"speaker": "요괴 야구부 주장", "portrait": YOKAI_CAPTAIN, "frame": 5, "text": "내 스윙을 멈춰. 네가 버티면… 내가 길을 열어 줄게."},
]


static func collect_beats() -> Array[Dictionary]:
	return INTRO_FIRST.duplicate()
