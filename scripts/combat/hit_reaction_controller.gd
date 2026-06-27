extends Node
## #136 공용 피격 반응 컨트롤러.
##
## 액터의 실제 체력 계산은 각 액터가 유지하고, 이 컨트롤러는 피격 직후
## 짧은 플래시와 무적 중 깜빡임, 원래 modulate 복구만 담당한다.

const DEFAULT_FLASH_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const DEFAULT_DIM_ALPHA := 0.45
const DEFAULT_BLINK_INTERVAL := 0.08
const DEFAULT_FLASH_DURATION := 0.10

@export var flash_color := DEFAULT_FLASH_COLOR
@export var dim_alpha := DEFAULT_DIM_ALPHA
@export var blink_interval := DEFAULT_BLINK_INTERVAL
@export var flash_duration := DEFAULT_FLASH_DURATION

var _visual: CanvasItem = null
var _base_modulate := Color.WHITE
var _remaining := 0.0
var _flash_remaining := 0.0


func bind_visual(visual: CanvasItem) -> void:
	_visual = visual
	if _visual != null:
		_base_modulate = _visual.modulate


func trigger(duration: float, visual: CanvasItem = null) -> void:
	if visual != null:
		bind_visual(visual)
	if _visual != null and not is_active():
		_base_modulate = _visual.modulate
	_remaining = maxf(0.0, duration)
	_flash_remaining = minf(flash_duration, _remaining)
	_apply_visual()


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if _remaining <= 0.0:
		_restore_visual()
		return
	_remaining = maxf(0.0, _remaining - delta)
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	_apply_visual()


func clear() -> void:
	_remaining = 0.0
	_flash_remaining = 0.0
	_restore_visual()


func is_active() -> bool:
	return _remaining > 0.0


func get_remaining() -> float:
	return _remaining


func blink_alpha(remaining: float, interval: float = DEFAULT_BLINK_INTERVAL, alpha_when_dim: float = DEFAULT_DIM_ALPHA) -> float:
	if remaining <= 0.0:
		return 1.0
	var safe_interval := maxf(0.001, interval)
	var phase := int(floor(remaining / safe_interval))
	return clampf(alpha_when_dim, 0.0, 1.0) if phase % 2 == 0 else 1.0


func _apply_visual() -> void:
	if _visual == null:
		return
	if _remaining <= 0.0:
		_restore_visual()
		return
	var next := _base_modulate
	if _flash_remaining > 0.0:
		next = Color(
			_base_modulate.r * flash_color.r,
			_base_modulate.g * flash_color.g,
			_base_modulate.b * flash_color.b,
			_base_modulate.a
		)
	else:
		next.a = _base_modulate.a * blink_alpha(_remaining, blink_interval, dim_alpha)
	_visual.modulate = next


func _restore_visual() -> void:
	if _visual != null:
		_visual.modulate = _base_modulate
