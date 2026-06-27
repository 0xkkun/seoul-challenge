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
	button.free()
