extends Node
## #202 낮 학교 소문 데이터 모듈 — tier 해석/필터/조건/가중 선택/데이터 무결성을 검증한다.

const RUMORS := preload("res://resources/dialogue/day_school_rumors.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


## ProgressionSystem 대역 — tier 분기를 통제하기 위한 스텁.
class _StubProgression:
	var purified := false
	var weapon := false

	func is_friend_purified(_id: StringName) -> bool:
		return purified

	func is_weapon_unlocked(_id: StringName) -> bool:
		return weapon


func test_data_is_valid() -> void:
	var problems: Array[String] = RUMORS.validate()
	_runner.assert_eq(problems.size(), 0, "소문 데이터 무결성 문제 없음: %s" % str(problems))


func test_at_least_eight_rumors() -> void:
	_runner.assert_true(RUMORS.ENTRIES.size() >= 8, "완료조건: 소문 8개 이상 (실제 %d)" % RUMORS.ENTRIES.size())


func test_current_tier_first_visit_when_null() -> void:
	_runner.assert_eq(RUMORS.current_tier(null), RUMORS.TIER_FIRST_VISIT, "progression 없으면 first_visit")


func test_current_tier_branches() -> void:
	var stub := _StubProgression.new()
	_runner.assert_eq(RUMORS.current_tier(stub), RUMORS.TIER_FIRST_VISIT, "정화 전 = first_visit")
	stub.purified = true
	_runner.assert_eq(RUMORS.current_tier(stub), RUMORS.TIER_POST_PURIFY, "정화됨/무기 전 = post_purify")
	stub.weapon = true
	_runner.assert_eq(RUMORS.current_tier(stub), RUMORS.TIER_POST_ENHANCED, "강화배트 해금 = post_enhanced")


func test_people2_has_lines_in_every_tier() -> void:
	# % size 나눗셈 안전: 모든 reachable tier에 ≥1줄
	for tier: StringName in RUMORS.VALID_TIERS:
		var lines: Array = RUMORS.pick_lines(RUMORS.SPEAKER_PEOPLE2, tier)
		_runner.assert_true(lines.size() >= 1, "people2 tier %s 에 대사 ≥1 (실제 %d)" % [str(tier), lines.size()])


func test_people2_first_visit_keeps_original_opening_line() -> void:
	# 회귀: 마이그레이션이 기존 첫 대사를 보존하는지
	var lines: Array = RUMORS.pick_lines(RUMORS.SPEAKER_PEOPLE2, RUMORS.TIER_FIRST_VISIT)
	_runner.assert_eq(String(lines[0].get("text", "")), "낮엔 뛰지 말고, 얘기부터 하자.", "people2 첫 대사 보존")


func test_condition_excluded_without_context() -> void:
	var lines: Array = RUMORS.pick_lines(RUMORS.SPEAKER_PEOPLE4, RUMORS.TIER_FIRST_VISIT, {})
	for entry: Dictionary in lines:
		_runner.assert_true(
			StringName(entry.get("id", &"")) != &"p4_died_cried",
			"컨텍스트 없으면 died 조건 소문 제외"
		)


func test_condition_included_with_matching_context() -> void:
	var lines: Array = RUMORS.pick_lines(RUMORS.SPEAKER_PEOPLE4, RUMORS.TIER_FIRST_VISIT, {"last_run": &"died"})
	var has_died := false
	for entry: Dictionary in lines:
		if StringName(entry.get("id", &"")) == &"p4_died_cried":
			has_died = true
	_runner.assert_true(has_died, "died 컨텍스트면 동적 소문 포함")


func test_pick_lines_never_empty_for_real_people4_tiers() -> void:
	# 조건 미충족이어도 condition 없는 풀로 폴백 → 빈 결과 방지
	for tier: StringName in RUMORS.VALID_TIERS:
		var lines: Array = RUMORS.pick_lines(RUMORS.SPEAKER_PEOPLE4, tier, {"last_run": &"cleared"})
		_runner.assert_true(lines.size() >= 1, "people4 tier %s 폴백으로 비지 않음" % str(tier))


func test_crowd_fragment_empty_pool_returns_empty() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var frag: Dictionary = RUMORS.pick_crowd_fragment(&"nonexistent_tier", rng)
	_runner.assert_true(frag.is_empty(), "빈 풀이면 {} 반환 (가드)")


func test_crowd_fragment_weighted_deterministic_with_seed() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 42
	var first: Dictionary = RUMORS.pick_crowd_fragment(RUMORS.TIER_FIRST_VISIT, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 42
	var second: Dictionary = RUMORS.pick_crowd_fragment(RUMORS.TIER_FIRST_VISIT, rng_b)
	_runner.assert_false(first.is_empty(), "군중 조각이 선택됨")
	_runner.assert_eq(
		StringName(first.get("id", &"")), StringName(second.get("id", &"")),
		"같은 시드 → 결정적 선택 (flaky 방지)"
	)
	_runner.assert_eq(StringName(first.get("speaker", &"")), RUMORS.SPEAKER_PEOPLE4, "군중 조각은 people4")


func test_delivery_derived_from_speaker() -> void:
	_runner.assert_eq(RUMORS.delivery_for(RUMORS.SPEAKER_PEOPLE2), RUMORS.DELIVERY_DIALOGUE, "people2 = dialogue")
	_runner.assert_eq(RUMORS.delivery_for(RUMORS.SPEAKER_PEOPLE3), RUMORS.DELIVERY_AMBIENT, "people3 = ambient")
	_runner.assert_eq(RUMORS.delivery_for(RUMORS.SPEAKER_PEOPLE4), RUMORS.DELIVERY_AMBIENT_CROWD, "people4 = crowd")


func test_people2_meta_points_to_baseball_captain() -> void:
	# 대화 UI 계약: 눈뜬 정적 프레임 = 1
	var meta: Dictionary = RUMORS.speaker_meta(RUMORS.SPEAKER_PEOPLE2)
	_runner.assert_eq(String(meta.get("display_name", "")), "야구부 주장", "people2 표시 이름은 MVP NPC 역할명")
	_runner.assert_eq(int(meta.get("portrait_frame", -1)), 1, "people2 포트레이트 frame 1")
	_runner.assert_eq(
		String(meta.get("portrait", "")), "res://assets/characters/school/baseball_captain.png",
		"people2 포트레이트 경로"
	)
