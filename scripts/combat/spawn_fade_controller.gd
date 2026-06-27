extends Node
## 전투방 등장 직후 적을 짧게 페이드인하고, 그동안 접촉/행동 피해를 막기 위한 상태 컨트롤러.

const DEFAULT_DURATION := 0.35

var _visual: CanvasItem = null
var _base_modulate := Color.WHITE
var _duration := DEFAULT_DURATION
var _remaining := 0.0
var _was_active := false


func bind_visual(visual: CanvasItem) -> void:
	_visual = visual
	if _visual != null and not is_active():
		_base_modulate = _visual.modulate


func start(duration: float = DEFAULT_DURATION, visual: CanvasItem = null) -> void:
	if visual != null:
		bind_visual(visual)
	_duration = maxf(0.001, duration)
	_remaining = maxf(0.0, duration)
	_was_active = _remaining > 0.0
	if _visual != null:
		_base_modulate = _visual.modulate
	_apply_visual()


func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if _remaining <= 0.0:
		if _was_active:
			_was_active = false
			_restore_visual()
		return
	_remaining = maxf(0.0, _remaining - delta)
	_apply_visual()


func clear() -> void:
	_remaining = 0.0
	_was_active = false
	_restore_visual()


func is_active() -> bool:
	return _remaining > 0.0


func get_remaining() -> float:
	return _remaining


func _apply_visual() -> void:
	if _visual == null:
		return
	if _remaining <= 0.0:
		_was_active = false
		_restore_visual()
		return
	var progress := 1.0 - (_remaining / _duration)
	var next := _base_modulate
	next.a = _base_modulate.a * clampf(progress, 0.0, 1.0)
	_visual.modulate = next


func _restore_visual() -> void:
	if _visual != null:
		_visual.modulate = _base_modulate
