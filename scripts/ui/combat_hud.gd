extends CanvasLayer
## 전투 HUD — 플레이어 체력을 하트로 표시한다.
## EventBus.player_health_changed({"current": int, "max": int}) 를 구독해 갱신한다.
## 무기/재화 슬롯은 후속 이슈를 위한 placeholder stub 이다.
class_name CombatHud

const HEART_FILLED_COLOR := Color(0.86, 0.22, 0.27)
const HEART_EMPTY_COLOR := Color(0.25, 0.25, 0.28)
const HEART_SIZE := Vector2(22, 22)
const WEAPON_SLOT_STUB_TEXT := "무기: -"
const CURRENCY_SLOT_STUB_TEXT := "0"

@onready var _hearts: HBoxContainer = %Hearts
@onready var _weapon_slot: Label = %WeaponSlot
@onready var _currency_slot: Label = %CurrencySlot

var _current_health := 0
var _max_health := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_weapon_slot.text = WEAPON_SLOT_STUB_TEXT
	_currency_slot.text = CURRENCY_SLOT_STUB_TEXT
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_render_hearts()


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


func _on_player_health_changed(payload: Dictionary) -> void:
	var current := int(payload.get("current", _current_health))
	var max_health := int(payload.get("max", _max_health))
	set_health(current, max_health)


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
