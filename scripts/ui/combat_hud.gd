extends CanvasLayer
## 전투 HUD — 플레이어 체력을 하트로 표시한다.
## EventBus.player_health_changed({"current": int, "max": int}) 를 구독해 갱신한다.
## 무기 슬롯은 후속 이슈를 위한 placeholder stub 이다.
class_name CombatHud

const HEART_TEXTURE := preload("res://assets/ui/icons/combat/hp_heart.png")
const HEART_FILLED_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const HEART_EMPTY_MODULATE := Color(0.35, 0.35, 0.38, 0.55)
const HEART_SIZE := Vector2(28, 28)
const WEAPON_SLOT_STUB_TEXT := "기억 무기: 준비 중"
const SKILL_SLOT_STUB_TEXT := "회피: 준비 중"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

@onready var _hearts: HBoxContainer = %Hearts
@onready var _health_panel: HBoxContainer = $Root/HealthPanel
@onready var _stub_panel: HBoxContainer = $Root/StubPanel
@onready var _weapon_slot: Label = %WeaponSlot
@onready var _skill_slot: Label = %SkillSlot

var _current_health := 0
var _max_health := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_landscape_safe_area()
	set_weapon_state(_initial_weapon_id())
	_skill_slot.text = SKILL_SLOT_STUB_TEXT
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.special_skill_state_changed.connect(_on_special_skill_state_changed)
	_render_hearts()


func _exit_tree() -> void:
	if has_node("/root/EventBus"):
		if EventBus.player_health_changed.is_connected(_on_player_health_changed):
			EventBus.player_health_changed.disconnect(_on_player_health_changed)
		if EventBus.special_skill_state_changed.is_connected(_on_special_skill_state_changed):
			EventBus.special_skill_state_changed.disconnect(_on_special_skill_state_changed)


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
	for heart in _hearts.get_children():
		if bool(heart.get_meta(&"filled", false)):
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
	set_weapon_name(_weapon_display_name(weapon_id))


func set_weapon_name(display_name: String) -> void:
	var weapon_name := display_name.strip_edges()
	_weapon_slot.text = "기억 무기: %s" % (weapon_name if weapon_name != "" else "없음")


func get_weapon_text() -> String:
	return _weapon_slot.text


func _on_player_health_changed(payload: Dictionary) -> void:
	var current := int(payload.get("current", _current_health))
	var max_health := int(payload.get("max", _max_health))
	set_health(current, max_health)


func _on_special_skill_state_changed(payload: Dictionary) -> void:
	set_skill_state(payload)


func _render_hearts() -> void:
	while _hearts.get_child_count() > _max_health:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.free()
	while _hearts.get_child_count() < _max_health:
		var heart := TextureRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.texture = HEART_TEXTURE
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts.add_child(heart)
	for index in _hearts.get_child_count():
		var heart := _hearts.get_child(index) as TextureRect
		var filled := index < _current_health
		heart.set_meta(&"filled", filled)
		heart.modulate = HEART_FILLED_MODULATE if filled else HEART_EMPTY_MODULATE


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
		&"bat":
			return "금 간 나무 배트"
		_:
			return "없음"


func _apply_landscape_safe_area() -> void:
	var insets := MobileSafeArea.landscape_minimum_insets()
	MobileSafeArea.apply_edge_offsets(_health_panel, float(insets["left"]), float(insets["top"]), -1.0, -1.0)
	MobileSafeArea.apply_edge_offsets(_stub_panel, -1.0, float(insets["top"]), float(insets["right"]), -1.0)
