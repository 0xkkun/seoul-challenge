extends Node
## HapticManager 단위 테스트.
## test_mode 로 실제 진동 대신 test_log 에 레벨을 적재하고, _test_now 로 가상 시간을
## 주입해 전역 바닥/카테고리 쿨다운/델타 게이트/이벤트 매핑을 검증한다.

var _runner: Node

const L_LIGHT := 0
const L_MEDIUM := 1
const L_STRONG := 2
const L_DOUBLE := 3
const L_LONG := 4


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	HapticManager.test_mode = true
	HapticManager.test_log.clear()
	HapticManager._enabled = true
	HapticManager._last_any_ms = -100000
	HapticManager._last_cat_ms.clear()
	HapticManager._last_health = -1
	HapticManager._test_now = 0


func after_each() -> void:
	HapticManager.test_mode = false
	HapticManager.test_log.clear()
	HapticManager._test_now = -1
	HapticManager._enabled = bool(Settings.get_value("haptic_enabled", true))


func _at(t: int) -> void:
	HapticManager._test_now = t


# --- Tier1 이벤트 → 레벨 매핑 ---

func test_player_died_maps_to_long() -> void:
	_at(1000)
	EventBus.emit_player_died({})
	_runner.assert_eq(HapticManager.test_log, [L_LONG], "사망은 LONG 진동")


func test_boss_defeated_maps_to_double() -> void:
	_at(1000)
	EventBus.emit_boss_defeated({})
	_runner.assert_eq(HapticManager.test_log, [L_DOUBLE], "보스 처치는 DOUBLE 진동")


func test_room_cleared_and_rescue_map_to_medium() -> void:
	_at(1000)
	EventBus.emit_room_cleared({})
	_at(2000)
	EventBus.emit_student_rescued({})
	_runner.assert_eq(HapticManager.test_log, [L_MEDIUM, L_MEDIUM], "클리어·구출은 MEDIUM")


# --- 델타 게이트: 피격(감소)만 진동, 회복(증가)은 무진동 ---

func test_health_vibrates_only_on_decrease() -> void:
	_at(1000)
	EventBus.emit_player_health_changed({"current": 10, "max": 10}) # 기준선 — 무진동
	_runner.assert_eq(HapticManager.test_log, [], "첫 체력 이벤트는 기준선, 무진동")
	_at(2000)
	EventBus.emit_player_health_changed({"current": 8, "max": 10})  # 피격 — MEDIUM
	_runner.assert_eq(HapticManager.test_log, [L_MEDIUM], "피격(감소)은 MEDIUM")
	_at(3000)
	EventBus.emit_player_health_changed({"current": 9, "max": 10})  # 회복 — 무진동
	_runner.assert_eq(HapticManager.test_log, [L_MEDIUM], "회복(증가)은 무진동")


func test_first_damaged_health_event_vibrates() -> void:
	_at(1000)
	EventBus.emit_player_health_changed({"current": 2, "max": 3})
	_runner.assert_eq(HapticManager.test_log, [L_MEDIUM], "첫 체력 이벤트가 이미 감소 상태면 피격 진동")


func test_currency_change_does_not_vibrate() -> void:
	# currency_changed 는 디자인 리뷰에서 컷(고빈도 + 진행 이벤트와 충돌). 무진동이어야 한다.
	_at(1000)
	EventBus.emit_currency_changed({"amount": 5})
	_runner.assert_eq(HapticManager.test_log, [], "재화 변화는 진동하지 않음")


func test_combat_feedback_melee_hit_maps_to_light_haptic() -> void:
	_at(1000)
	EventBus.emit_combat_feedback({"kind": &"melee_hit", "intensity": 5.0})
	_runner.assert_eq(HapticManager.test_log, [L_LIGHT], "근접 타격 피드백은 화면 흔들림과 함께 LIGHT 진동")


func test_combat_feedback_deflect_maps_to_strong_haptic() -> void:
	_at(1000)
	EventBus.emit_combat_feedback({"kind": &"deflect", "intensity": 5.0})
	_runner.assert_eq(HapticManager.test_log, [L_STRONG], "패링/반사는 STRONG 진동")


# --- 과진동 방지 ---

func test_global_floor_suppresses_rapid_back_to_back() -> void:
	_at(1000)
	HapticManager.on_enemy_hit()                  # 발동
	HapticManager.on_fire()                        # 같은 시각 → 전역 바닥에 막힘
	_runner.assert_eq(HapticManager.test_log.size(), 1, "30ms 내 연속은 전역 바닥에 융합")
	_at(1100)
	HapticManager.on_fire()                        # 바닥 통과 → 발동
	_runner.assert_eq(HapticManager.test_log.size(), 2, "바닥 시간 지나면 발동")


func test_category_cooldown_throttles_enemy_hits() -> void:
	_at(2000)
	HapticManager.on_enemy_hit()                  # 발동
	_at(2040)
	HapticManager.on_enemy_hit()                  # 40<60 쿨다운 → 막힘
	_runner.assert_eq(HapticManager.test_log.size(), 1, "enemy_hit 쿨다운(60ms) 내 억제")
	_at(2070)
	HapticManager.on_enemy_hit()                  # 70>60 → 발동
	_runner.assert_eq(HapticManager.test_log.size(), 2, "쿨다운 지나면 발동")


func test_disabled_suppresses_all() -> void:
	HapticManager._enabled = false
	_at(1000)
	EventBus.emit_player_died({})
	HapticManager.on_deflect()
	_runner.assert_eq(HapticManager.test_log, [], "비활성화 시 전부 무진동")


func test_settings_changed_toggles_enabled() -> void:
	HapticManager._on_settings_changed({"haptic_enabled": false})
	_runner.assert_false(HapticManager._enabled, "settings_changed 로 즉시 비활성화")
	HapticManager._on_settings_changed({"haptic_enabled": true})
	_runner.assert_true(HapticManager._enabled, "settings_changed 로 즉시 활성화")
