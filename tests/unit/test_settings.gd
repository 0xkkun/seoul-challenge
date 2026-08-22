extends Node

var _runner: Node
var _settings_payloads: Array[Dictionary] = []


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Settings.reset_defaults()
	AudioManager.reset()
	_settings_payloads.clear()
	EventBus.settings_changed.connect(_record_settings_payload)


func after_each() -> void:
	if EventBus.settings_changed.is_connected(_record_settings_payload):
		EventBus.settings_changed.disconnect(_record_settings_payload)
	Settings.reset_defaults()
	AudioManager.reset()
	_settings_payloads.clear()


func test_settings_default_audio_and_haptic_flags_are_on() -> void:
	_runner.assert_true(Settings.is_bgm_enabled(), "BGM defaults on")
	_runner.assert_true(Settings.is_sfx_enabled(), "SFX defaults on")
	_runner.assert_true(Settings.is_haptic_enabled(), "haptic defaults on")
	_runner.assert_true(Settings.has_method("is_reduced_motion_enabled"), "settings exposes reduced-motion state")
	if Settings.has_method("is_reduced_motion_enabled"):
		_runner.assert_false(bool(Settings.call("is_reduced_motion_enabled")), "reduced onboarding motion defaults off")
	_runner.assert_true(Settings.has_method("is_screen_effects_enabled"), "settings exposes screen-effects state")
	if Settings.has_method("is_screen_effects_enabled"):
		_runner.assert_true(bool(Settings.call("is_screen_effects_enabled")), "screen effects default on")
	_runner.assert_true(Settings.has_method("is_damage_numbers_enabled"), "settings exposes damage-number state")
	if Settings.has_method("is_damage_numbers_enabled"):
		_runner.assert_true(bool(Settings.call("is_damage_numbers_enabled")), "damage numbers default on")


func test_reduced_motion_setting_emits_the_updated_snapshot() -> void:
	_runner.assert_true(Settings.has_method("set_reduced_motion_enabled"), "settings exposes reduced-motion setter")
	if not Settings.has_method("set_reduced_motion_enabled"):
		return
	Settings.call("set_reduced_motion_enabled", true)

	_runner.assert_true(bool(Settings.call("is_reduced_motion_enabled")), "reduced motion setter updates the setting")
	_runner.assert_eq(_settings_payloads.size(), 1, "reduced motion change emits once")
	_runner.assert_true(bool(_settings_payloads[0].get("reduced_motion", false)), "settings payload exposes reduced motion")


func test_audio_manager_honors_bgm_toggle_without_forgetting_track() -> void:
	AudioManager.play_bgm(AudioManager.LOBBY_BGM_DEFAULT)

	Settings.set_bgm_enabled(false)

	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.LOBBY_BGM_DEFAULT, "BGM id is retained while muted")
	_runner.assert_false(AudioManager.is_bgm_playing(), "BGM stops when disabled")

	Settings.set_bgm_enabled(true)

	_runner.assert_eq(AudioManager.get_current_bgm(), AudioManager.LOBBY_BGM_DEFAULT, "BGM id remains stable after re-enable")
	_runner.assert_true(AudioManager.is_bgm_playing(), "BGM resumes when enabled")


func test_audio_manager_ignores_sfx_when_disabled() -> void:
	AudioManager.play_sfx(&"ui_accept")
	_runner.assert_eq(AudioManager.get_played_sfx().size(), 1, "SFX records while enabled")

	Settings.set_sfx_enabled(false)
	AudioManager.play_sfx(&"ui_cancel")

	_runner.assert_eq(AudioManager.get_played_sfx().size(), 1, "SFX is ignored while disabled")


func test_haptic_toggle_guard_is_callable() -> void:
	Settings.set_haptic_enabled(false)
	Settings.try_vibrate(10)
	_runner.assert_false(Settings.is_haptic_enabled(), "try_vibrate does not change disabled state")


func test_settings_changed_signal_emits_snapshot() -> void:
	Settings.set_bgm_enabled(false)

	_runner.assert_eq(_settings_payloads.size(), 1, "settings change emits once")
	_runner.assert_eq(_settings_payloads[0][Settings.KEY_BGM_ENABLED], false, "payload includes updated BGM flag")


func test_screen_effects_setter_emits_one_complete_settings_snapshot() -> void:
	Settings.set_haptic_enabled(false)
	_settings_payloads.clear()
	_runner.assert_true(Settings.has_method("set_screen_effects_enabled"), "settings exposes screen-effects setter")
	if not Settings.has_method("set_screen_effects_enabled"):
		return
	Settings.call("set_screen_effects_enabled", false)
	_runner.assert_eq(_settings_payloads.size(), 1, "typed screen-effects setter emits exactly once")
	if _settings_payloads.size() != 1:
		return
	_runner.assert_false(bool(_settings_payloads[0].get("screen_effects_enabled", true)), "payload includes disabled screen effects")
	_runner.assert_false(bool(_settings_payloads[0].get(Settings.KEY_HAPTIC_ENABLED, true)), "payload preserves the existing disabled haptic flag")


func test_damage_numbers_setter_emits_one_complete_settings_snapshot() -> void:
	Settings.set_screen_effects_enabled(false)
	_settings_payloads.clear()
	_runner.assert_true(Settings.has_method("set_damage_numbers_enabled"), "settings exposes damage-number setter")
	if not Settings.has_method("set_damage_numbers_enabled"):
		return
	Settings.call("set_damage_numbers_enabled", false)
	_runner.assert_eq(_settings_payloads.size(), 1, "typed damage-number setter emits exactly once")
	if _settings_payloads.size() != 1:
		return
	_runner.assert_false(bool(_settings_payloads[0].get("damage_numbers_enabled", true)), "payload includes disabled damage numbers")
	_runner.assert_false(bool(_settings_payloads[0].get(Settings.KEY_SCREEN_EFFECTS, true)), "payload preserves the existing disabled screen effects")
	_runner.assert_true(_settings_payloads[0].has(Settings.KEY_BGM_ENABLED), "payload remains a full settings snapshot")


func _record_settings_payload(payload: Dictionary) -> void:
	_settings_payloads.append(payload.duplicate(true))
