extends Node

const MIN_SCALE := 0.01
const MAX_DURATION := 1.0
const DURATION_EPSILON := 0.000001

var _remaining_real_seconds := 0.0
var _active_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _remaining_real_seconds <= 0.0:
		return
	var applied_scale := maxf(absf(Engine.time_scale), MIN_SCALE)
	var real_delta := maxf(0.0, delta) / applied_scale
	_remaining_real_seconds = maxf(0.0, _remaining_real_seconds - real_delta)
	if _remaining_real_seconds <= DURATION_EPSILON:
		restore()


func request(duration: float, scale: float = 0.05) -> bool:
	if duration <= 0.0:
		return false
	var requested_duration := clampf(duration, DURATION_EPSILON, MAX_DURATION)
	if requested_duration <= _remaining_real_seconds + DURATION_EPSILON:
		return false
	_remaining_real_seconds = requested_duration
	_active_scale = clampf(scale, MIN_SCALE, 1.0)
	Engine.time_scale = _active_scale
	return true


func restore() -> void:
	_remaining_real_seconds = 0.0
	_active_scale = 1.0
	Engine.time_scale = 1.0


func is_active() -> bool:
	return _remaining_real_seconds > DURATION_EPSILON


func get_remaining_real_seconds() -> float:
	return _remaining_real_seconds


func get_active_scale() -> float:
	return _active_scale


func _exit_tree() -> void:
	restore()
