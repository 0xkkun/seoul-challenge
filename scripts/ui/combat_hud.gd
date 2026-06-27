extends CanvasLayer
## 전투 HUD — 플레이어 체력을 하트로 표시한다.
## EventBus.player_health_changed({"current": int, "max": int}) 를 구독해 갱신한다.
## 무기/재화 슬롯은 후속 이슈를 위한 placeholder stub 이다.
class_name CombatHud

const HEART_FILLED_COLOR := Color(0.86, 0.22, 0.27)
const HEART_EMPTY_COLOR := Color(0.25, 0.25, 0.28)
const HEART_SIZE := Vector2(22, 22)
const WEAPON_SLOT_STUB_TEXT := "기억 무기: 준비중"
const SKILL_SLOT_STUB_TEXT := "회피: 준비중"
const CURRENCY_SLOT_STUB_TEXT := "엽전: 0"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

@onready var _hearts: HBoxContainer = %Hearts
@onready var _health_panel: HBoxContainer = $Root/HealthPanel
@onready var _stub_panel: HBoxContainer = $Root/StubPanel
@onready var _weapon_slot: Label = %WeaponSlot
@onready var _skill_slot: Label = %SkillSlot
@onready var _currency_slot: Label = %CurrencySlot

var _current_health := 0
var _max_health := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_landscape_safe_area()
	set_weapon_state(_initial_weapon_id())
	_skill_slot.text = SKILL_SLOT_STUB_TEXT
	_currency_slot.text = CURRENCY_SLOT_STUB_TEXT
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.special_skill_state_changed.connect(_on_special_skill_state_changed)
	EventBus.currency_changed.connect(_on_currency_changed)
	if has_node("/root/CurrencySystem"):
		set_currency_state({"ingame": CurrencySystem.get_ingame()})
	_render_hearts()


func _exit_tree() -> void:
	if has_node("/root/EventBus"):
		if EventBus.player_health_changed.is_connected(_on_player_health_changed):
			EventBus.player_health_changed.disconnect(_on_player_health_changed)
		if EventBus.special_skill_state_changed.is_connected(_on_special_skill_state_changed):
			EventBus.special_skill_state_changed.disconnect(_on_special_skill_state_changed)
		if EventBus.currency_changed.is_connected(_on_currency_changed):
			EventBus.currency_changed.disconnect(_on_currency_changed)


## 체력을 직접 지정한다. (전투 미연동 상태에서의 stub/테스트 진입점)
func set_health(current: int, max_health: int) -> void:
	_max_health = maxi(0, max_health)
	_current_health = clampi(current, 0, _max_health)
	_render_hearts()


func get_current_health() -> int:
	return _current_health


func get_max_health() -> int:
	return _max_health


func get_filled_heart_count() -> int:
	var filled := 0
	for heart: ColorRect in _hearts.get_children():
		if heart.color == HEART_FILLED_COLOR:
			filled += 1
	return filled


func set_skill_state(payload: Dictionary) -> void:
	var skill_id: StringName = payload.get("skill_id", &"")
	var max_uses := int(payload.get("max_uses", 0))
	if skill_id == &"" or max_uses <= 0:
		_skill_slot.text = SKILL_SLOT_STUB_TEXT
		return
	var uses_remaining := clampi(int(payload.get("uses_remaining", 0)), 0, max_uses)
	var cooldown_remaining := maxf(0.0, float(payload.get("cooldown_remaining", 0.0)))
	_skill_slot.text = "스킬: %s %d/%d" % [_skill_display_name(skill_id), uses_remaining, max_uses]
	if cooldown_remaining > 0.05:
		_skill_slot.text += " %.1fs" % cooldown_remaining


func get_skill_text() -> String:
	return _skill_slot.text


func set_weapon_state(weapon_id: StringName) -> void:
	_weapon_slot.text = "기억 무기: %s" % _weapon_display_name(weapon_id)


func get_weapon_text() -> String:
	return _weapon_slot.text


func set_currency_state(payload: Dictionary) -> void:
	if not payload.has("ingame"):
		return
	var ingame := maxi(0, int(payload.get("ingame", 0)))
	_currency_slot.text = "엽전: %d" % ingame


func get_currency_text() -> String:
	return _currency_slot.text


func _on_player_health_changed(payload: Dictionary) -> void:
	var current := int(payload.get("current", _current_health))
	var max_health := int(payload.get("max", _max_health))
	set_health(current, max_health)


func _on_special_skill_state_changed(payload: Dictionary) -> void:
	set_skill_state(payload)


func _on_currency_changed(payload: Dictionary) -> void:
	set_currency_state(payload)


func _render_hearts() -> void:
	while _hearts.get_child_count() > _max_health:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.free()
	while _hearts.get_child_count() < _max_health:
		var heart := ColorRect.new()
		heart.custom_minimum_size = HEART_SIZE
		_hearts.add_child(heart)
	for index in _hearts.get_child_count():
		var heart := _hearts.get_child(index) as ColorRect
		heart.color = HEART_FILLED_COLOR if index < _current_health else HEART_EMPTY_COLOR


func _skill_display_name(skill_id: StringName) -> String:
	match skill_id:
		&"emergency_dodge":
			return "회피"
	return String(skill_id)


func _initial_weapon_id() -> StringName:
	if has_node("/root/GameManager"):
		return StringName(GameManager.get_active_config().get(SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID, &""))
	return &""


func _weapon_display_name(weapon_id: StringName) -> String:
	match weapon_id:
		&"baseball":
			return "낡은 야구공"
		&"bat":
			return "금 간 배트"
		_:
			return "미정"


func _apply_landscape_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	MobileSafeArea.apply_edge_offsets(_health_panel, float(insets["left"]), float(insets["top"]), -1.0, -1.0)
	MobileSafeArea.apply_edge_offsets(_stub_panel, -1.0, float(insets["top"]), float(insets["right"]), -1.0)
