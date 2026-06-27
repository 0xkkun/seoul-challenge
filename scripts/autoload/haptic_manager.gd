extends Node
## 햅틱 진동 매니저 (autoload). 임팩트 순간에 손맛을 더한다.
##
## 설계: docs/plans/haptic-feedback.md
## - Tier1: EventBus 시그널 구독(호출부 수정 0).
## - Tier2/3: 전투 손맛·UI 확정은 호출부에서 on_*() 직접 호출.
## - 과진동 방지: 전역 바닥(MIN_GAP_MS) + 카테고리 쿨다운 + 델타 게이트.
## - 플랫폼: 모바일에서만 실제 진동, 그 외 no-op.
## - iOS는 vibrate_handheld 의 길이/세기를 무시(고정 1발)하므로 레벨이 균일하게 느껴짐.
##
## 테스트: test_mode = true 로 두면 실제 진동 대신 test_log 에 레벨을 적재한다.
## (_test_now 로 가상 시간을 주입해 바닥/쿨다운 로직을 검증할 수 있다.)

enum Level { LIGHT, MEDIUM, STRONG, DOUBLE, LONG }

const MIN_GAP_MS := 30

## 실기기 튜닝 대상 — 수치는 전부 여기 한 곳에 격리한다.
const DURATION_MS := {
	Level.LIGHT: 12,
	Level.MEDIUM: 30,
	Level.STRONG: 70,
	Level.DOUBLE: 70,
	Level.LONG: 180,
}
const AMPLITUDE := {
	Level.LIGHT: 0.35,
	Level.MEDIUM: 0.65,
	Level.STRONG: 1.0,
	Level.DOUBLE: 1.0,
	Level.LONG: 1.0,
}
const COOLDOWN_MS := {
	&"enemy_hit": 60,
	&"fire": 50,
}
const DOUBLE_GAP_SEC := 0.07

var test_mode := false
var test_log: Array[int] = []

var _enabled := true
var _mobile := false
var _last_any_ms := -100000
var _last_cat_ms := {}
var _last_health := -1
var _test_now := -1


func _ready() -> void:
	_mobile = _detect_mobile()
	if has_node("/root/Settings"):
		_enabled = bool(Settings.get_value("haptic_enabled", true))
	if has_node("/root/EventBus"):
		EventBus.player_health_changed.connect(_on_player_health_changed)
		EventBus.player_died.connect(_on_player_died)
		EventBus.room_cleared.connect(_on_room_cleared)
		EventBus.boss_defeated.connect(_on_boss_defeated)
		EventBus.friend_purified.connect(_on_friend_purified)
		EventBus.student_rescued.connect(_on_student_rescued)
		EventBus.session_started.connect(_on_session_started)
		EventBus.settings_changed.connect(_on_settings_changed)
		if not EventBus.combat_feedback.is_connected(_on_combat_feedback):
			EventBus.combat_feedback.connect(_on_combat_feedback)


# --- Tier2/3 공개 API (호출부에서 직접 호출) ---

func on_fire() -> void:
	_try(&"fire", Level.LIGHT)


func on_deflect() -> void:
	_try(&"deflect", Level.STRONG)


func on_enemy_hit() -> void:
	_try(&"enemy_hit", Level.LIGHT)


func on_boss_hit() -> void:
	_try(&"boss_hit", Level.MEDIUM)


func on_ui_confirm() -> void:
	_try(&"ui", Level.LIGHT)


# --- Tier1 EventBus 핸들러 ---

func _on_player_health_changed(payload: Dictionary) -> void:
	var cur := int(payload.get("current", -1))
	if _last_health >= 0 and cur < _last_health:
		_try(&"player_hurt", Level.MEDIUM)
	_last_health = cur


func _on_player_died(_payload: Dictionary) -> void:
	_try(&"player_died", Level.LONG)


func _on_room_cleared(_payload: Dictionary) -> void:
	_try(&"room_cleared", Level.MEDIUM)


func _on_boss_defeated(_payload: Dictionary) -> void:
	_try(&"boss_defeated", Level.DOUBLE)


func _on_friend_purified(_payload: Dictionary) -> void:
	_try(&"friend_purified", Level.MEDIUM)


func _on_student_rescued(_payload: Dictionary) -> void:
	_try(&"student_rescued", Level.MEDIUM)


func _on_session_started(_config: Dictionary) -> void:
	_last_health = -1


func _on_settings_changed(settings: Dictionary) -> void:
	_enabled = bool(settings.get("haptic_enabled", true))


func _on_combat_feedback(payload: Dictionary) -> void:
	var kind := StringName(payload.get("kind", &""))
	match kind:
		&"melee_hit":
			on_enemy_hit()
		&"deflect", &"parry", &"dash_parry":
			on_deflect()


# --- 내부 ---

## 게이트(활성/모바일) + 전역 바닥 + 카테고리 쿨다운을 통과하면 진동. 통과 여부 반환.
func _try(category: StringName, level: int) -> bool:
	if not _enabled:
		return false
	if not _mobile and not test_mode:
		return false
	var now := _now()
	if now - _last_any_ms < MIN_GAP_MS:
		return false
	var cd := int(COOLDOWN_MS.get(category, 0))
	if cd > 0 and now - int(_last_cat_ms.get(category, -100000)) < cd:
		return false
	_last_any_ms = now
	_last_cat_ms[category] = now
	_emit(level)
	return true


func _now() -> int:
	if test_mode and _test_now >= 0:
		return _test_now
	return Time.get_ticks_msec()


func _emit(level: int) -> void:
	if test_mode:
		test_log.append(level)
		return
	var dur := int(DURATION_MS[level])
	var amp := float(AMPLITUDE[level])
	Input.vibrate_handheld(dur, amp)
	if level == Level.DOUBLE:
		await get_tree().create_timer(DOUBLE_GAP_SEC).timeout
		Input.vibrate_handheld(dur, amp)


func _detect_mobile() -> bool:
	var touch := has_node("/root/PlatformManager") and PlatformManager.has_touch_input()
	return touch and OS.has_feature("mobile")
