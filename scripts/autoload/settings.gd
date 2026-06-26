extends Node

var _settings: Dictionary = {
	"language": "en",
	"master_volume": 1.0,
	"touch_controls": true,
}


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func get_value(key: String, fallback: Variant = null) -> Variant:
	return _settings.get(key, fallback)


func set_value(key: String, value: Variant) -> void:
	_settings[key] = value
	if has_node("/root/EventBus"):
		EventBus.emit_settings_changed(_settings)


func reset_defaults() -> void:
	_settings = {
		"language": "en",
		"master_volume": 1.0,
		"touch_controls": true,
	}
	if has_node("/root/EventBus"):
		EventBus.emit_settings_changed(_settings)
