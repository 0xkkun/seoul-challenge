extends Node

const CONTROLLER_PATH := "res://scripts/combat/parry_feedback_controller.gd"
const FLOATING_TEXT_SCENE_PATH := "res://scenes/ui/floating_combat_text.tscn"
const FLOATING_TEXT_POOL_ID := &"floating_combat_text"
const HAPTIC_STRONG := 2

var _runner: Node
var _feedback_callback := Callable()


func _set_runner(runner: Node) -> void:
	_runner = runner


func before_each() -> void:
	PoolManager.clear_all()
	HitStopManager.restore()
	AudioManager.reset()
	HapticManager.test_mode = true
	HapticManager.test_log.clear()
	HapticManager._enabled = true
	HapticManager._last_any_ms = -100000
	HapticManager._last_cat_ms.clear()
	HapticManager._test_now = 1000


func after_each() -> void:
	if _feedback_callback.is_valid() and EventBus.combat_feedback.is_connected(_feedback_callback):
		EventBus.combat_feedback.disconnect(_feedback_callback)
	_feedback_callback = Callable()
	PoolManager.clear_all()
	HitStopManager.restore()
	AudioManager.reset()
	HapticManager.test_mode = false
	HapticManager.test_log.clear()
	HapticManager._test_now = -1
	for child: Node in get_children():
		child.queue_free()


func test_parry_presentation_runs_real_effects_in_fixed_order() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	var effect_parent := Node2D.new()
	add_child(effect_parent)
	controller.call("configure", null, effect_parent)
	var steps: Array[StringName] = []
	controller.connect(&"presentation_step", func(step: StringName) -> void: steps.append(step))
	var feedback_payloads: Array[Dictionary] = []
	_feedback_callback = func(payload: Dictionary) -> void: feedback_payloads.append(payload)
	EventBus.combat_feedback.connect(_feedback_callback)

	controller.call("present", {
		"player_position": Vector2(20.0, 30.0),
		"enemy_position": Vector2(60.0, 50.0),
		"direction": Vector2.RIGHT,
	})

	_runner.assert_eq(steps, [&"text", &"hit_stop", &"flash", &"shake", &"sound", &"haptic"], "parry presentation order is deterministic")
	_runner.assert_eq(PoolManager.get_active_count(FLOATING_TEXT_POOL_ID), 1, "presentation spawns one pooled text")
	var active_texts: Array = (PoolManager.get("_active") as Dictionary).get(FLOATING_TEXT_POOL_ID, [])
	_runner.assert_eq((active_texts[0] as Node).call("get_snapshot").get("text"), "받아쳤다", "floating text copy is exact")
	_runner.assert_eq((active_texts[0] as Node2D).global_position, Vector2(40.0, 40.0), "text starts at the collision midpoint")
	_runner.assert_true(HitStopManager.is_active(), "presentation starts hit stop")
	_runner.assert_eq(HitStopManager.get_active_scale(), 0.05, "parry hit stop uses the fixed scale")
	_runner.assert_eq(feedback_payloads.size(), 1, "presentation emits one camera feedback event")
	if feedback_payloads.size() == 1:
		_runner.assert_eq(feedback_payloads[0].get("kind"), &"parry", "feedback kind is parry")
		_runner.assert_eq(feedback_payloads[0].get("intensity"), 9.0, "parry shake intensity is fixed")
	_runner.assert_eq(AudioManager.get_played_sfx(), [&"parry_success"], "presentation plays one dedicated sound")
	_runner.assert_eq(HapticManager.test_log, [HAPTIC_STRONG], "presentation owns exactly one strong haptic")
	_runner.assert_true(bool(controller.call("get_flash_snapshot").get("visible")), "white flash is visible at impact")


func test_floating_text_pool_caps_twenty_expires_and_reuses_clean_state() -> void:
	_runner.assert_true(ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH), "floating combat text scene exists")
	var controller := _new_controller()
	if controller == null or not ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH):
		return
	var effect_parent := Node2D.new()
	add_child(effect_parent)
	controller.call("configure", null, effect_parent)

	for index: int in range(21):
		controller.call("present", {
			"player_position": Vector2(float(index), 0.0),
			"enemy_position": Vector2(float(index) + 10.0, 0.0),
			"direction": Vector2.RIGHT,
		})
	_runner.assert_eq(PoolManager.get_active_count(FLOATING_TEXT_POOL_ID), 20, "the 21st text is rejected without allocation")
	var active_nodes: Array = (PoolManager.get("_active") as Dictionary).get(FLOATING_TEXT_POOL_ID, []).duplicate()
	for text_node: Node in active_nodes:
		text_node.call("_on_lifetime_finished", int(text_node.get("_activation_generation")))
	_runner.assert_eq(PoolManager.get_active_count(FLOATING_TEXT_POOL_ID), 0, "completed lifetimes leave the active list")
	_runner.assert_eq(PoolManager.get_available_count(FLOATING_TEXT_POOL_ID), 20, "expired texts return to the pool")

	var first := PoolManager.acquire(FLOATING_TEXT_POOL_ID, effect_parent)
	first.call("initialize", Vector2(77.0, 33.0), "오래된 문구", &"parry")
	first.modulate = Color(0.2, 0.3, 0.4, 0.5)
	first.scale = Vector2(2.0, 2.0)
	(first as Node2D).position = Vector2(99.0, 88.0)
	PoolManager.release(first)
	var reused := PoolManager.acquire(FLOATING_TEXT_POOL_ID, effect_parent)
	_runner.assert_true(reused == first, "released floating text instance is reused")
	var snapshot: Dictionary = reused.call("get_snapshot")
	_runner.assert_eq(snapshot.get("text"), "", "reacquired text clears stale copy")
	_runner.assert_eq(snapshot.get("style"), &"", "reacquired text clears stale style")
	_runner.assert_eq(snapshot.get("modulate"), Color.WHITE, "reacquired text restores modulate")
	_runner.assert_eq(snapshot.get("scale"), Vector2.ONE, "reacquired text restores scale")
	_runner.assert_eq(snapshot.get("position"), Vector2.ZERO, "reacquired text restores position")
	_runner.assert_false(bool(snapshot.get("tween_active", true)), "reacquired text owns no stale tween")
	PoolManager.release(reused)


func test_parry_style_is_readable_and_bounded() -> void:
	_runner.assert_true(ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH), "floating combat text scene exists")
	if not ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH):
		return
	var text_node := (load(FLOATING_TEXT_SCENE_PATH) as PackedScene).instantiate()
	add_child(text_node)
	var style: Dictionary = text_node.call("style_for", &"parry")
	_runner.assert_eq(style.get("font_size"), 32, "parry text is 32pt")
	_runner.assert_eq(style.get("duration"), 1.0, "parry text lasts one second")
	_runner.assert_eq(style.get("rise"), 20.0, "parry text rises 20px")
	_runner.assert_true(float(style.get("punch_scale", 1.0)) > 1.0, "parry text has a punch scale")
	_runner.assert_true((style.get("color", Color.TRANSPARENT) as Color).a > 0.99, "parry text stays fully readable")


func test_default_style_and_lifetime_progress_cover_punch_rise_and_fade() -> void:
	_runner.assert_true(ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH), "floating combat text scene exists")
	if not ResourceLoader.exists(FLOATING_TEXT_SCENE_PATH):
		return
	var text_node := (load(FLOATING_TEXT_SCENE_PATH) as PackedScene).instantiate() as Node2D
	add_child(text_node)
	var style: Dictionary = text_node.call("style_for", &"damage")
	_runner.assert_eq(style.get("font_size"), 24, "unknown styles use the readable default size")
	_runner.assert_eq(style.get("duration"), 0.8, "default style keeps a bounded lifetime")
	_runner.assert_eq(style.get("rise"), 16.0, "default style uses the compact rise distance")
	_runner.assert_eq(style.get("punch_scale"), 1.16, "default style keeps a smaller punch than parry")

	text_node.call("activate_from_pool")
	var start := Vector2(40.0, 60.0)
	text_node.call("initialize", start, "7", &"damage")
	var generation := int(text_node.get("_activation_generation"))
	_runner.assert_true(bool(text_node.call("get_snapshot").get("tween_active")), "initialize owns one real lifetime tween")
	text_node.call("_apply_lifetime_progress", 0.10, start, style, generation)
	_runner.assert_true(text_node.scale.x > 1.0, "early lifetime applies the punch scale")
	_runner.assert_true(text_node.position.y < start.y, "lifetime progress raises text upward")
	text_node.call("_apply_lifetime_progress", 0.80, start, style, generation)
	_runner.assert_true(text_node.modulate.a > 0.0 and text_node.modulate.a < 1.0, "late lifetime fades without disappearing early")
	_runner.assert_eq(text_node.scale, Vector2.ONE, "late lifetime settles punch scale to rest")
	text_node.call("reset_for_pool")


func test_stale_lifetime_callback_cannot_release_a_reused_text() -> void:
	var controller := _new_controller()
	if controller == null:
		return
	var effect_parent := Node2D.new()
	add_child(effect_parent)
	controller.call("configure", null, effect_parent)
	var first := PoolManager.acquire(FLOATING_TEXT_POOL_ID, effect_parent)
	first.call("initialize", Vector2.ZERO, "첫 활성", &"parry")
	var stale_generation := int(first.get("_activation_generation"))
	PoolManager.release(first)
	var reused := PoolManager.acquire(FLOATING_TEXT_POOL_ID, effect_parent)
	_runner.assert_true(reused == first, "fixture reacquires the same node")
	reused.call("initialize", Vector2.ONE, "새 활성", &"parry")
	var current_generation := int(reused.get("_activation_generation"))

	reused.call("_on_lifetime_finished", stale_generation)
	_runner.assert_eq(PoolManager.get_active_count(FLOATING_TEXT_POOL_ID), 1, "stale callback cannot release the reused active node")
	_runner.assert_eq(reused.call("get_snapshot").get("text"), "새 활성", "stale callback cannot clear new content")
	reused.call("_on_lifetime_finished", current_generation)
	_runner.assert_eq(PoolManager.get_active_count(FLOATING_TEXT_POOL_ID), 0, "current generation callback releases normally")


func _new_controller() -> Node:
	_runner.assert_true(ResourceLoader.exists(CONTROLLER_PATH), "parry feedback controller exists")
	if not ResourceLoader.exists(CONTROLLER_PATH):
		return null
	var controller := (load(CONTROLLER_PATH) as Script).new() as Node
	add_child(controller)
	return controller
