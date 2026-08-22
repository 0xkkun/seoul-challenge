extends Node

const KEY_LANGUAGE := "language"
const KEY_MASTER_VOLUME := "master_volume"
const KEY_TOUCH_CONTROLS := "touch_controls"
const KEY_BGM_ENABLED := "bgm_enabled"
const KEY_SFX_ENABLED := "sfx_enabled"
const KEY_HAPTIC_ENABLED := "haptic_enabled"
const KEY_REDUCED_MOTION := "reduced_motion"

const DEFAULT_SETTINGS := {
	"language": "en",
	"master_volume": 1.0,
	"touch_controls": true,
	"bgm_enabled": true,
	"sfx_enabled": true,
	"haptic_enabled": true,
	"reduced_motion": false,
}

var _settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _settings.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	_settings[key] = value
	_emit_settings_changed()


func is_bgm_enabled() -> bool:
	return bool(get_value(KEY_BGM_ENABLED, true))


func set_bgm_enabled(enabled: bool) -> void:
	set_value(KEY_BGM_ENABLED, enabled)


func is_sfx_enabled() -> bool:
	return bool(get_value(KEY_SFX_ENABLED, true))


func set_sfx_enabled(enabled: bool) -> void:
	set_value(KEY_SFX_ENABLED, enabled)


func is_haptic_enabled() -> bool:
	return bool(get_value(KEY_HAPTIC_ENABLED, true))


func set_haptic_enabled(enabled: bool) -> void:
	set_value(KEY_HAPTIC_ENABLED, enabled)


func is_reduced_motion_enabled() -> bool:
	return bool(get_value(KEY_REDUCED_MOTION, false))


func set_reduced_motion_enabled(enabled: bool) -> void:
	set_value(KEY_REDUCED_MOTION, enabled)


func try_vibrate(duration_ms: int = 80) -> void:
	if not is_haptic_enabled():
		return
	if not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(duration_ms)


func _emit_settings_changed() -> void:
	if has_node("/root/EventBus"):
		EventBus.emit_settings_changed(_settings)


func reset_defaults() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)
	_emit_settings_changed()
