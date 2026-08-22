class_name DamageVignette
extends CanvasLayer

const RenderLayers = preload("res://scripts/constants/render_layers.gd")
const PULSE_DURATION := 0.42
const PULSE_COLOR := Color(0.95, 0.08, 0.12, 0.78)
const LOW_HEALTH_COLOR := Color(0.68, 0.015, 0.045, 0.48)
const LOW_HEALTH_RATIO := 0.25

var _pulse_overlay: ColorRect = null
var _low_health_overlay: ColorRect = null
var _pulse_tween: Tween = null
var _damage_pulse_active := false
var _low_health_requested := false
var _current_health := -1
var _max_health := 1
var _bound_player: Node = null


func _ready() -> void:
	layer = RenderLayers.UI_SESSION_LAYER - 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_overlays()
	_render_state()


func bind_player(player: Node) -> void:
	if player == null or not player.has_method("get_health"):
		return
	_bound_player = player
	var max_health := int(player.get("max_health")) if _has_property(player, "max_health") else 1
	_set_cached_health(int(player.call("get_health")), max_health)
	_connect_event_bus_once()
	_render_state()


func on_health_changed(current: int, max_health: int) -> void:
	var previous_health := _current_health
	_set_cached_health(current, max_health)
	if previous_health >= 0 and _current_health < previous_health and _screen_effects_enabled():
		_start_damage_pulse()
	_render_state()


func get_snapshot() -> Dictionary:
	_ensure_overlays()
	return {
		"current_health": _current_health,
		"max_health": _max_health,
		"damage_pulse_active": _damage_pulse_active and _screen_effects_enabled(),
		"low_health_visible": _low_health_overlay.visible,
		"screen_effects_enabled": _screen_effects_enabled(),
		"pulse_alpha": _pulse_overlay.modulate.a,
		"low_health_alpha": _low_health_overlay.modulate.a,
		"layer": layer,
		"mouse_filter": _pulse_overlay.mouse_filter,
		"health_connected": _health_signal_connected(),
		"settings_connected": _settings_signal_connected(),
	}


func _exit_tree() -> void:
	_cancel_damage_pulse()
	if has_node("/root/EventBus"):
		var health_callback := Callable(self, "_on_player_health_changed")
		var settings_callback := Callable(self, "_on_settings_changed")
		if EventBus.player_health_changed.is_connected(health_callback):
			EventBus.player_health_changed.disconnect(health_callback)
		if EventBus.settings_changed.is_connected(settings_callback):
			EventBus.settings_changed.disconnect(settings_callback)
	_bound_player = null


func _set_cached_health(current: int, max_health: int) -> void:
	_max_health = maxi(1, max_health)
	_current_health = clampi(current, 0, _max_health)
	_low_health_requested = float(_current_health) / float(_max_health) <= LOW_HEALTH_RATIO


func _connect_event_bus_once() -> void:
	if not has_node("/root/EventBus"):
		return
	var health_callback := Callable(self, "_on_player_health_changed")
	var settings_callback := Callable(self, "_on_settings_changed")
	if not EventBus.player_health_changed.is_connected(health_callback):
		EventBus.player_health_changed.connect(health_callback)
	if not EventBus.settings_changed.is_connected(settings_callback):
		EventBus.settings_changed.connect(settings_callback)


func _on_player_health_changed(payload: Dictionary) -> void:
	if not payload.has("current") or not payload.has("max"):
		return
	on_health_changed(int(payload["current"]), int(payload["max"]))


func _on_settings_changed(settings: Dictionary) -> void:
	if not settings.has(Settings.KEY_SCREEN_EFFECTS):
		return
	if not bool(settings[Settings.KEY_SCREEN_EFFECTS]):
		_cancel_damage_pulse()
	_render_state()


func _start_damage_pulse() -> void:
	_ensure_overlays()
	_cancel_damage_pulse()
	_damage_pulse_active = true
	_pulse_overlay.visible = true
	_pulse_overlay.modulate = Color.WHITE
	_pulse_tween = create_tween().set_ignore_time_scale(true)
	_pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pulse_tween.tween_property(_pulse_overlay, "modulate:a", 0.0, PULSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_callback(_finish_damage_pulse)


func _finish_damage_pulse() -> void:
	_damage_pulse_active = false
	_pulse_tween = null
	_render_state()


func _cancel_damage_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	_damage_pulse_active = false
	if _pulse_overlay != null:
		_pulse_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_pulse_overlay.visible = false


func _render_state() -> void:
	_ensure_overlays()
	var enabled := _screen_effects_enabled()
	_pulse_overlay.visible = enabled and _damage_pulse_active
	if not _pulse_overlay.visible:
		_pulse_overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_low_health_overlay.visible = enabled and _low_health_requested
	_low_health_overlay.modulate = Color.WHITE if _low_health_overlay.visible else Color(1.0, 1.0, 1.0, 0.0)


func _ensure_overlays() -> void:
	if _low_health_overlay == null:
		_low_health_overlay = _make_overlay("LowHealthEdges", LOW_HEALTH_COLOR)
		add_child(_low_health_overlay)
	if _pulse_overlay == null:
		_pulse_overlay = _make_overlay("DamagePulse", PULSE_COLOR)
		add_child(_pulse_overlay)


func _make_overlay(node_name: String, tint: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = node_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color.WHITE
	overlay.material = _make_vignette_material(tint)
	overlay.visible = false
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return overlay


func _make_vignette_material(tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 tint_color : source_color;
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = length(centered * vec2(0.82, 1.08));
	float edge = smoothstep(0.48, 1.06, radial);
	float side = smoothstep(0.68, 1.0, max(abs(centered.x), abs(centered.y)));
	float alpha = max(edge, side * 0.72) * tint_color.a;
	COLOR = vec4(tint_color.rgb, alpha);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint_color", tint)
	return material


func _screen_effects_enabled() -> bool:
	return not has_node("/root/Settings") or Settings.is_screen_effects_enabled()


func _health_signal_connected() -> bool:
	return has_node("/root/EventBus") and EventBus.player_health_changed.is_connected(Callable(self, "_on_player_health_changed"))


func _settings_signal_connected() -> bool:
	return has_node("/root/EventBus") and EventBus.settings_changed.is_connected(Callable(self, "_on_settings_changed"))


func _has_property(node: Object, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false
