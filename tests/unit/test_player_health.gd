extends Node
## 플레이어 체력/피격 — 적 데미지 ↔ EventBus(player_health_changed) 연결 단위 테스트.
## (Codex 리뷰: 플레이어에 take_damage 가 없어 적탄이 무효였던 버그 수정)

const PlayerScript := preload("res://scripts/player/player.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")
const L_MEDIUM := 1
const DAMAGE_VIGNETTE_SCRIPT_PATH := "res://scripts/ui/damage_vignette.gd"

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	HitStopManager.restore()


func after_each() -> void:
	HitStopManager.restore()


func _enable_haptic_test_mode(t: int = 1000) -> void:
	HapticManager.test_mode = true
	HapticManager.test_log.clear()
	HapticManager._enabled = true
	HapticManager._last_any_ms = -100000
	HapticManager._last_cat_ms.clear()
	HapticManager._last_health = -1
	HapticManager._test_now = t


func _restore_haptic_test_mode() -> void:
	HapticManager.test_mode = false
	HapticManager.test_log.clear()
	HapticManager._test_now = -1
	HapticManager._enabled = bool(Settings.get_value("haptic_enabled", true))


func test_damaged_health_clamps_to_zero() -> void:
	var p = PlayerScript.new()
	_runner.assert_eq(p.damaged_health(5, 2), 3, "5-2=3")
	_runner.assert_eq(p.damaged_health(1, 5), 0, "0 미만은 클램프")
	p.free()


func test_damage_vignette_distinguishes_damage_heal_and_low_health() -> void:
	_runner.assert_true(ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH), "damage vignette script exists")
	if not ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH):
		return
	Settings.reset_defaults()
	var vignette: Node = (load(DAMAGE_VIGNETTE_SCRIPT_PATH) as Script).new()
	add_child(vignette)
	vignette.call("on_health_changed", 5, 5)
	vignette.call("on_health_changed", 3, 5)
	_runner.assert_true(bool(vignette.call("get_snapshot")["damage_pulse_active"]), "damage pulses red")
	vignette.call("on_health_changed", 1, 5)
	_runner.assert_true(bool(vignette.call("get_snapshot")["low_health_visible"]), "critical health stays visible")
	vignette.call("on_health_changed", 4, 5)
	_runner.assert_false(bool(vignette.call("get_snapshot")["low_health_visible"]), "healing clears low-health state")
	var pulse_overlay := vignette.get("_pulse_overlay") as ColorRect
	var pulse_material := pulse_overlay.material as ShaderMaterial
	_runner.assert_true(pulse_material.shader.code.contains("alpha * canvas_alpha"), "vignette shader multiplies rendered alpha by the runtime CanvasItem alpha")
	vignette.free()
	Settings.reset_defaults()


func test_damage_vignette_ignores_proportional_max_health_removal() -> void:
	_runner.assert_true(ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH), "damage vignette script exists for max-health regression")
	if not ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH):
		return
	Settings.reset_defaults()
	var vignette: Node = (load(DAMAGE_VIGNETTE_SCRIPT_PATH) as Script).new()
	add_child(vignette)
	vignette.call("on_health_changed", 6, 6)
	vignette.call("on_health_changed", 5, 5)
	var snapshot: Dictionary = vignette.call("get_snapshot")
	_runner.assert_false(bool(snapshot["damage_pulse_active"]), "full-health max reduction cannot masquerade as incoming damage")
	_runner.assert_false(bool(snapshot["low_health_visible"]), "full-health max reduction stays visually healthy")
	vignette.free()
	Settings.reset_defaults()


func test_damage_vignette_fade_uses_real_time_progress() -> void:
	_runner.assert_true(ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH), "damage vignette script exists for fade timing")
	if not ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH):
		return
	Settings.reset_defaults()
	HitStopManager.restore()
	var vignette: Node = (load(DAMAGE_VIGNETTE_SCRIPT_PATH) as Script).new()
	add_child(vignette)
	vignette.call("on_health_changed", 5, 5)
	vignette.call("on_health_changed", 3, 5)
	vignette.call("_advance_damage_pulse", 0.21)
	var midpoint: Dictionary = vignette.call("get_snapshot")
	_runner.assert_true(is_equal_approx(float(midpoint["pulse_alpha"]), 0.25), "half-duration pulse renders quarter alpha with quadratic ease-out")
	_runner.assert_true(bool(midpoint["damage_pulse_active"]), "half-duration pulse remains active")
	vignette.call("_advance_damage_pulse", 0.21)
	var finished: Dictionary = vignette.call("get_snapshot")
	_runner.assert_false(bool(finished["damage_pulse_active"]), "full real-time duration finishes the pulse")
	_runner.assert_eq(float(finished["pulse_alpha"]), 0.0, "finished pulse clears rendered alpha")
	vignette.free()
	Settings.reset_defaults()


func test_damage_vignette_setting_hides_active_states_and_restores_cached_critical_health() -> void:
	_runner.assert_true(ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH), "damage vignette script exists for setting lifecycle")
	if not ResourceLoader.exists(DAMAGE_VIGNETTE_SCRIPT_PATH):
		return
	Settings.reset_defaults()
	var vignette: Node = (load(DAMAGE_VIGNETTE_SCRIPT_PATH) as Script).new()
	var player := PlayerScript.new()
	add_child(player)
	add_child(vignette)
	vignette.call("bind_player", player)
	vignette.call("on_health_changed", 1, 5)
	var active: Dictionary = vignette.call("get_snapshot")
	_runner.assert_true(bool(active["damage_pulse_active"]), "critical damage starts a pulse")
	_runner.assert_true(bool(active["low_health_visible"]), "critical damage enables persistent edges")

	Settings.call("set_screen_effects_enabled", false)
	var disabled: Dictionary = vignette.call("get_snapshot")
	_runner.assert_false(bool(disabled["damage_pulse_active"]), "setting off cancels the active pulse")
	_runner.assert_false(bool(disabled["low_health_visible"]), "setting off hides low-health state immediately")
	_runner.assert_eq(float(disabled["pulse_alpha"]), 0.0, "setting off clears rendered pulse alpha")

	Settings.call("set_screen_effects_enabled", true)
	var restored: Dictionary = vignette.call("get_snapshot")
	_runner.assert_true(bool(restored["low_health_visible"]), "setting on recomputes critical state from cached health")
	vignette.free()
	player.free()
	Settings.reset_defaults()


func test_take_damage_reduces_health() -> void:
	var p = PlayerScript.new()
	add_child(p)  # _ready → _health = max_health
	var before: int = p.get_health()
	_runner.assert_true(before > 0, "초기 체력 > 0")
	var applied: Variant = p.take_damage(2)
	_runner.assert_eq(p.get_health(), before - 2, "피해만큼 체력 감소")
	_runner.assert_eq(applied, 2, "플레이어 피격도 실제 적용 피해량을 반환한다")
	p.free()


func test_player_hit_stop_starts_only_for_accepted_damage() -> void:
	var player := PlayerScript.new()
	add_child(player)
	var accepted: Variant = player.take_damage(2)
	_runner.assert_eq(accepted, 2, "first player hit applies damage")
	_runner.assert_true(is_equal_approx(HitStopManager.get_remaining_real_seconds(), 0.05), "accepted player hit requests hurt duration")
	_runner.assert_true(is_equal_approx(HitStopManager.get_active_scale(), 0.10), "accepted player hit requests hurt slow scale")

	HitStopManager.restore()
	var rejected: Variant = player.take_damage(2)
	_runner.assert_eq(rejected, 0, "invulnerable repeat hit returns zero")
	_runner.assert_false(HitStopManager.is_active(), "invulnerable repeat hit cannot restart hit stop")
	_runner.assert_eq(Engine.time_scale, 1.0, "rejected player hit keeps normal time")
	player.free()


func test_player_damage_combat_text_emits_exact_accepted_delta() -> void:
	var player := PlayerScript.new()
	add_child(player)
	_runner.assert_true(player.has_signal(&"combat_text_requested"), "player exposes hurt combat text requests")
	if not player.has_signal(&"combat_text_requested"):
		player.free()
		return
	player.global_position = Vector2(44.0, 72.0)
	var requests: Array[Dictionary] = []
	player.connect(&"combat_text_requested", func(position: Vector2, text: String, style: StringName) -> void:
		requests.append({"position": position, "text": text, "style": style})
	)

	player.take_damage(2)
	player.take_damage(2)

	_runner.assert_eq(requests.size(), 1, "accepted hurt emits once and invulnerable rejection emits nothing")
	if requests.size() == 1:
		_runner.assert_eq(requests[0]["position"], Vector2(44.0, 72.0), "player reports its world position for session placement")
		_runner.assert_eq(requests[0]["text"], "2", "player hurt text uses exact applied damage")
		_runner.assert_eq(requests[0]["style"], &"player_damage", "player hurt uses player-damage style")
	player.free()


func test_invuln_blocks_immediate_second_hit() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.take_damage(1)
	var after_first: int = p.get_health()
	p.take_damage(1)  # 무적시간 내 → 무시
	_runner.assert_eq(p.get_health(), after_first, "무적시간 중 추가 피해 무시")
	p.free()


func test_player_hit_sfx_plays_only_for_accepted_damage() -> void:
	AudioManager.reset()
	var p = PlayerScript.new()
	add_child(p)
	p.take_damage(1)
	p.take_damage(1)
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"player_hit"], "accepted damage plays once and invulnerable rejection stays silent")
	p.free()
	AudioManager.reset()


func test_hit_reaction_flashes_sprite_and_restores_after_invuln() -> void:
	var p = PlayerScene.instantiate()
	add_child(p)
	var sprite := p.get_node("Sprite") as CanvasItem
	var base_modulate := sprite.modulate
	p.take_damage(1)
	_runner.assert_true(p.has_method("is_hit_invulnerable"), "플레이어는 피격 무적 질의 API를 노출한다")
	_runner.assert_true(p.call("is_hit_invulnerable"), "피격 직후 무적 상태가 된다")
	_runner.assert_true(sprite.modulate != base_modulate, "피격 직후 스프라이트 시각 효과가 적용된다")
	p.call("tick_hit_reaction", p.invuln_time + 0.05)
	_runner.assert_false(p.call("is_hit_invulnerable"), "무적 시간이 끝나면 비활성화된다")
	_runner.assert_eq(sprite.modulate, base_modulate, "무적 종료 후 스프라이트 색/투명도가 복구된다")
	p.queue_free()


func test_emits_player_health_changed_on_damage() -> void:
	var p = PlayerScript.new()
	add_child(p)
	var got := {"current": -1, "max": -1}
	var cb := func(payload: Dictionary) -> void:
		got["current"] = int(payload.get("current", -1))
		got["max"] = int(payload.get("max", -1))
	EventBus.player_health_changed.connect(cb)
	p.take_damage(1)
	EventBus.player_health_changed.disconnect(cb)
	_runner.assert_eq(got["max"], p.max_health, "EventBus 발신: max")
	_runner.assert_eq(got["current"], p.max_health - 1, "EventBus 발신: current")
	p.free()


func test_take_damage_triggers_player_hurt_haptic() -> void:
	_enable_haptic_test_mode()
	var p = PlayerScript.new()
	add_child(p)
	p.take_damage(1)
	var log := HapticManager.test_log.duplicate()
	p.free()
	_restore_haptic_test_mode()
	_runner.assert_eq(log, [L_MEDIUM], "플레이어 피격은 MEDIUM 진동을 울린다")
