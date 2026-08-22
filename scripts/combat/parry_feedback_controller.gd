class_name ParryFeedbackController
extends CanvasLayer

const FLOATING_TEXT_SCENE := preload("res://scenes/ui/floating_combat_text.tscn")
const FLOATING_TEXT_POOL_ID := &"floating_combat_text"
const FLOATING_TEXT_CAP := 20
const HIT_STOP_DURATION := 0.10
const HIT_STOP_SCALE := 0.05
const FLASH_ALPHA := 0.52
const FLASH_DURATION := 0.16

signal presentation_step(step: StringName)

var _player: Node = null
var _effect_parent: Node2D = null
var _flash_rect: ColorRect = null
var _flash_tween: Tween = null


func _ready() -> void:
	layer = 17
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash()


func configure(player: Node = null, effect_parent: Node2D = null) -> void:
	_disconnect_player()
	_player = player
	_effect_parent = effect_parent
	_connect_player()
	PoolManager.clear_pool(FLOATING_TEXT_POOL_ID)
	PoolManager.register_scene(FLOATING_TEXT_POOL_ID, FLOATING_TEXT_SCENE, FLOATING_TEXT_CAP, _effect_parent)


func present(payload: Dictionary) -> void:
	var player_position := payload.get("player_position", Vector2.ZERO) as Vector2
	var enemy_position := payload.get("enemy_position", Vector2.ZERO) as Vector2
	_spawn_parry_text((player_position + enemy_position) * 0.5, "받아쳤다")
	presentation_step.emit(&"text")
	HitStopManager.request(HIT_STOP_DURATION, HIT_STOP_SCALE)
	presentation_step.emit(&"hit_stop")
	_flash_white()
	presentation_step.emit(&"flash")
	EventBus.emit_combat_feedback({
		"kind": &"parry",
		"direction": payload.get("direction", Vector2.RIGHT),
		"hit_count": 1,
		"intensity": 9.0,
		"source_position": player_position,
	})
	presentation_step.emit(&"shake")
	AudioManager.play_sfx(AudioManager.PARRY_SUCCESS)
	presentation_step.emit(&"sound")
	HapticManager.on_deflect()
	presentation_step.emit(&"haptic")


func reset() -> void:
	_kill_flash_tween()
	if _flash_rect != null:
		_flash_rect.color.a = 0.0
		_flash_rect.visible = false


func teardown() -> void:
	_disconnect_player()
	reset()
	_player = null
	_effect_parent = null


func get_flash_snapshot() -> Dictionary:
	return {
		"visible": _flash_rect != null and _flash_rect.visible and _flash_rect.color.a > 0.0,
		"alpha": _flash_rect.color.a if _flash_rect != null else 0.0,
		"tween_active": _flash_tween != null and _flash_tween.is_valid(),
	}


func _spawn_parry_text(world_position: Vector2, text: String) -> bool:
	if PoolManager.get_active_count(FLOATING_TEXT_POOL_ID) >= FLOATING_TEXT_CAP:
		return false
	var floating_text := PoolManager.acquire(FLOATING_TEXT_POOL_ID, _effect_parent)
	if floating_text == null:
		return false
	floating_text.call("initialize", world_position, text, &"parry")
	return true


func _build_flash() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.name = "ParryFlash"
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.visible = false
	add_child(_flash_rect)


func _flash_white() -> void:
	_kill_flash_tween()
	_flash_rect.visible = true
	_flash_rect.color = Color(1.0, 1.0, 1.0, FLASH_ALPHA)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash_rect, ^"color:a", 0.0, FLASH_DURATION)
	_flash_tween.tween_callback(_finish_flash)


func _finish_flash() -> void:
	_flash_tween = null
	_flash_rect.color.a = 0.0
	_flash_rect.visible = false


func _kill_flash_tween() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null


func _connect_player() -> void:
	if _player == null or not _player.has_signal("parry_succeeded"):
		return
	var callback := Callable(self, "_on_player_parry_succeeded")
	if not _player.is_connected(&"parry_succeeded", callback):
		_player.connect(&"parry_succeeded", callback)


func _disconnect_player() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.has_signal("parry_succeeded"):
		return
	var callback := Callable(self, "_on_player_parry_succeeded")
	if _player.is_connected(&"parry_succeeded", callback):
		_player.disconnect(&"parry_succeeded", callback)


func _on_player_parry_succeeded(payload: Dictionary) -> void:
	present(payload)


func _exit_tree() -> void:
	teardown()
