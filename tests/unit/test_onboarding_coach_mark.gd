extends Node

const TOKENS_PATH := "res://scripts/ui/onboarding_visual_tokens.gd"
const COACH_PATH := "res://scripts/ui/onboarding_coach_mark.gd"
const PARRY_ONBOARDING_PATH := "res://scripts/ui/parry_onboarding.gd"
const MobileSafeArea := preload("res://scripts/ui/mobile_safe_area.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	Settings.reset_defaults()


func after_each() -> void:
	Settings.reset_defaults()
	for child: Node in get_children():
		child.queue_free()


func test_tokens_drive_compact_timing_surface_and_reduced_motion() -> void:
	_runner.assert_true(ResourceLoader.exists(TOKENS_PATH), "onboarding visual tokens exist")
	var coach := _new_coach()
	if coach == null or not ResourceLoader.exists(TOKENS_PATH):
		return
	coach.call("configure", null, false)
	coach.call("show_prompt", {
		"id": &"parry",
		"tone": &"timing",
		"action": "받아치기",
		"key_label": "LMB",
		"detail": "늑대가 달려들 때",
		"target_kind": &"none",
		"placement": &"ribbon",
	})
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_eq(snapshot.get("tone_color"), Color(0.38, 0.94, 0.89, 1.0), "timing prompt renders the approved cyan")
	_runner.assert_true((snapshot.get("label_rect", Rect2()) as Rect2).size.x <= 340.0, "coach label never exceeds 340px")
	_runner.assert_true((snapshot.get("label_rect", Rect2()) as Rect2).size.y <= 72.0, "coach label never exceeds 72px")
	_runner.assert_eq(snapshot.get("enter_duration"), 0.18, "normal coach uses the bounded 180ms entrance")

	coach.call("configure", null, true)
	coach.call("show_prompt", {
		"id": &"reduced",
		"tone": &"info",
		"action": "이동",
		"target_kind": &"none",
	})
	snapshot = coach.call("get_snapshot")
	_runner.assert_true(bool(snapshot.get("reduced_motion")), "coach records reduced-motion mode")
	_runner.assert_eq(snapshot.get("enter_duration"), 0.0, "reduced motion applies the final state immediately")


func test_world_target_prompt_is_safe_compact_and_non_blocking() -> void:
	var coach := _new_coach()
	if coach == null:
		return
	var target := Node2D.new()
	target.name = "Wolf"
	target.global_position = Vector2(120.0, 80.0)
	add_child(target)
	coach.call("configure", null, false)
	coach.call("show_prompt", {
		"id": &"parry",
		"tone": &"timing",
		"action": "받아치기",
		"key_label": "LMB",
		"detail": "늑대가 달려들 때",
		"target_kind": &"world",
		"target": target,
		"placement": &"auto",
		"persistent": true,
	})
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_eq(snapshot.get("action"), "받아치기", "action copy is rendered separately")
	_runner.assert_eq(snapshot.get("key_label"), "LMB", "key chip names the real PC input")
	_runner.assert_eq(snapshot.get("target_name"), "Wolf", "world bracket tracks the intended target")
	_runner.assert_true(MobileSafeArea.meets_landscape_minimum(snapshot.get("label_rect", Rect2()) as Rect2), "label stays inside landscape safe area")
	_runner.assert_true(float(snapshot.get("screen_coverage", 1.0)) <= 0.25, "coachmark protects at least 75% of the playfield")
	_runner.assert_eq(snapshot.get("mouse_filter"), Control.MOUSE_FILTER_IGNORE, "coachmark never consumes combat pointer input")
	_runner.assert_eq(snapshot.get("bracket_style"), &"corners", "target uses corner brackets instead of a rounded box")


func test_stale_completion_cannot_dismiss_the_next_prompt() -> void:
	var coach := _new_coach()
	if coach == null:
		return
	coach.call("show_prompt", {"id": &"first", "action": "이동", "target_kind": &"none"})
	coach.call("complete")
	coach.call("show_prompt", {"id": &"second", "action": "공격", "target_kind": &"none"})
	coach.call("finish_motion_for_tests", &"first")
	var snapshot: Dictionary = coach.call("get_snapshot")
	_runner.assert_eq(snapshot.get("id"), &"second", "stale callback cannot replace the current prompt id")
	_runner.assert_true(bool(snapshot.get("active")), "stale callback cannot hide the current prompt")


func test_world_target_deletion_immediately_dismisses_the_coachmark() -> void:
	var coach := _new_coach()
	if coach == null:
		return
	var target := Node2D.new()
	add_child(target)
	coach.call("show_prompt", {
		"id": &"target_cleanup",
		"action": "공격",
		"target_kind": &"world",
		"target": target,
	})
	_runner.assert_true(bool(coach.call("is_active")), "world target prompt starts active")
	target.queue_free()
	coach.call("_process", 0.0)
	_runner.assert_false(bool(coach.call("is_active")), "queued target immediately dismisses its coachmark")
	_runner.assert_false(coach.visible, "dismissed target coachmark is hidden")


func test_detached_parry_onboarding_dismisses_without_root_lookup_error() -> void:
	_runner.assert_true(ResourceLoader.exists(PARRY_ONBOARDING_PATH), "parry onboarding script exists")
	if not ResourceLoader.exists(PARRY_ONBOARDING_PATH):
		return
	var tutorial := (load(PARRY_ONBOARDING_PATH) as Script).new() as Node
	var wolf := Node2D.new()
	add_child(tutorial)
	add_child(wolf)
	tutorial.call("show_for_wolf", wolf, &"desktop")
	remove_child(tutorial)

	_runner.assert_true(bool(tutorial.call("dismiss_for_wolf", wolf)), "detached scene teardown still dismisses the active prompt")
	_runner.assert_false(bool(tutorial.call("is_active")), "detached prompt cannot survive teardown")
	tutorial.free()


func _new_coach() -> Node:
	_runner.assert_true(ResourceLoader.exists(COACH_PATH), "onboarding coachmark script exists")
	if not ResourceLoader.exists(COACH_PATH):
		return null
	var coach := (load(COACH_PATH) as Script).new() as Node
	add_child(coach)
	return coach
