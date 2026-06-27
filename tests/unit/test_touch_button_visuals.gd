extends Node

const AttackButtonScript := preload("res://scripts/ui/attack_button.gd")
const SkillButtonScript := preload("res://scripts/ui/skill_button.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_attack_button_uses_b9_transparent_icon_contract() -> void:
	var button := AttackButtonScript.new()
	_runner.assert_true(button.has_method("get_visual_contract"), "attack button exposes B-9 visual contract")
	if not button.has_method("get_visual_contract"):
		button.free()
		return

	var contract: Dictionary = button.get_visual_contract()
	_runner.assert_eq(contract.get("background_fill_alpha"), 0.0, "B-9 removes attack button color fill")
	_runner.assert_eq(contract.get("pressed_fill_alpha"), 0.0, "B-9 keeps attack press feedback ring-only")
	_runner.assert_eq(contract.get("shadow_alpha"), 0.0, "B-9 removes attack button shadow")
	_runner.assert_eq(contract.get("icon_path"), "res://assets/ui/icons/combat/damage_1.png", "attack uses the provided damage icon")
	_runner.assert_true(is_equal_approx(float(contract.get("icon_alpha", 0.0)), 0.56), "attack icon is opacity-only muted")
	_runner.assert_true(float(contract.get("outer_ring_alpha", 0.0)) > float(contract.get("inner_ring_alpha", 0.0)), "outer ring stays clearer than inner ring")
	button.free()


func test_attack_button_dialogue_mode_uses_same_size_speech_icon_contract() -> void:
	var button := AttackButtonScript.new()
	_runner.assert_true(button.has_method("set_icon_mode"), "attack button can switch icon mode for non-combat contexts")
	_runner.assert_true(button.has_method("get_visual_contract"), "attack button exposes icon contract")
	if not button.has_method("set_icon_mode") or not button.has_method("get_visual_contract"):
		button.free()
		return

	button.call("set_icon_mode", "dialogue")

	var contract: Dictionary = button.get_visual_contract()
	_runner.assert_eq(contract.get("icon_mode"), "dialogue", "dialogue mode replaces the combat damage icon")
	_runner.assert_eq(contract.get("icon_shape"), "speech_bubble", "dialogue mode uses a speech bubble/message icon")
	_runner.assert_eq(contract.get("icon_path"), "", "dialogue mode uses the built-in pixel speech icon instead of the combat asset")
	_runner.assert_true(is_equal_approx(float(contract.get("icon_scale", 0.0)), 0.44), "dialogue icon keeps the same size as the combat icon")
	button.free()


func test_skill_button_uses_b9_transparent_center_icon_contract() -> void:
	var button := SkillButtonScript.new()
	_runner.assert_true(button.has_method("get_visual_contract"), "skill button exposes B-9 visual contract")
	if not button.has_method("get_visual_contract"):
		button.free()
		return

	var contract: Dictionary = button.get_visual_contract()
	_runner.assert_eq(contract.get("background_fill_alpha"), 0.0, "B-9 removes skill button color fill")
	_runner.assert_eq(contract.get("pressed_fill_alpha"), 0.0, "B-9 keeps skill press feedback ring-only")
	_runner.assert_eq(contract.get("disabled_fill_alpha"), 0.0, "B-9 avoids gray disabled fill")
	_runner.assert_eq(contract.get("shadow_alpha"), 0.0, "B-9 removes skill button shadow")
	_runner.assert_eq(contract.get("center_icon"), "chevron", "skill button uses a single center icon")
	_runner.assert_false(bool(contract.get("uses_label_visible", true)), "skill button does not draw the old numeric label")
	_runner.assert_true(bool(contract.get("charge_slots_visible", false)), "skill button renders remaining dodges as charge slots")
	_runner.assert_true(float(contract.get("outer_ring_alpha", 0.0)) >= 0.30, "skill button keeps a readable white outline at rest")
	_runner.assert_true(float(contract.get("slot_filled_alpha", 0.0)) > float(contract.get("slot_empty_alpha", 0.0)), "filled dodge slots read brighter than empty slots")
	button.free()


func test_skill_button_charge_slots_replace_numeric_count() -> void:
	var button := SkillButtonScript.new()
	_runner.assert_true(button.has_method("get_charge_slot_snapshot"), "skill button exposes a non-text charge slot snapshot")
	if not button.has_method("get_charge_slot_snapshot"):
		button.free()
		return

	button.set_skill_state({
		"uses_remaining": 2,
		"max_uses": 3,
		"cooldown_remaining": 1.5,
		"cooldown": 3.0,
	})

	_runner.assert_eq(button.get_uses_label(), "", "skill button does not expose a numeric uses label")
	var slots: Array = button.get_charge_slot_snapshot()
	_runner.assert_eq(slots.size(), 3, "base dodge displays three charge slots")
	if slots.size() == 3:
		_runner.assert_eq(slots[0]["state"], &"filled", "first stored dodge slot is filled")
		_runner.assert_eq(slots[1]["state"], &"filled", "second stored dodge slot is filled")
		_runner.assert_eq(slots[2]["state"], &"charging", "next missing dodge slot shows recharge progress")
		_runner.assert_true(is_equal_approx(float(slots[2]["progress"]), 0.5), "charging slot fills as cooldown completes")
	button.free()


func test_skill_button_charge_slots_show_empty_when_no_recharge_progress() -> void:
	var button := SkillButtonScript.new()
	_runner.assert_true(button.has_method("get_charge_slot_snapshot"), "skill button exposes charge slot state")
	if not button.has_method("get_charge_slot_snapshot"):
		button.free()
		return

	button.set_skill_state({
		"uses_remaining": 1,
		"max_uses": 3,
		"cooldown_remaining": 0.0,
		"cooldown": 3.0,
	})

	var slots: Array = button.get_charge_slot_snapshot()
	_runner.assert_eq(slots.size(), 3, "base dodge still reserves all three slot positions")
	if slots.size() == 3:
		_runner.assert_eq(slots[0]["state"], &"filled", "available dodge is filled")
		_runner.assert_eq(slots[1]["state"], &"empty", "missing dodge without recharge is empty")
		_runner.assert_eq(slots[2]["state"], &"empty", "remaining missing dodge is empty")
	button.free()
