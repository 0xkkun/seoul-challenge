extends Node

const RoomPalette = preload("res://scripts/constants/room_palette.gd")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func after_each() -> void:
	for child: Node in get_children():
		child.queue_free()


func test_ready_applies_locked_state_and_palette_layout() -> void:
	var door := _create_door(&"E")
	var visual := door.get_node("DoorVisual") as ColorRect
	var transition_area := door.get_node("TransitionArea") as Area2D
	var collision_shape := door.get_node("TransitionArea/CollisionShape2D") as CollisionShape2D
	var ping_marker := door.get_node("PingMarker") as Label
	var rectangle := collision_shape.shape as RectangleShape2D

	_runner.assert_true(door.is_locked(), "door starts locked")
	_runner.assert_eq(door.position, RoomPalette.EAST_DOOR_POSITION, "door uses palette position")
	_runner.assert_eq(visual.size, RoomPalette.DOOR_SIZE, "door visual uses palette size")
	_runner.assert_eq(visual.color, RoomPalette.DOOR_LOCKED_COLOR, "locked door uses palette color")
	_runner.assert_false(transition_area.monitoring, "locked door disables transition monitoring")
	_runner.assert_false(ping_marker.visible, "locked door hides exit ping")
	_runner.assert_not_null(rectangle, "door creates rectangle trigger shape")
	if rectangle != null:
		_runner.assert_eq(rectangle.size, RoomPalette.DOOR_TRIGGER_SIZE, "trigger shape uses palette size")


func test_open_and_lock_emit_state_changes_once_per_change() -> void:
	var door := _create_door(&"N")
	var visual := door.get_node("DoorVisual") as ColorRect
	var states: Array[int] = []
	var on_state_changed := func(_door_dir: StringName, state: int) -> void:
		states.append(state)

	door.state_changed.connect(on_state_changed)
	door.open()
	door.open()

	var ping_marker := door.get_node("PingMarker") as Label
	var portal_visual := door.get_node_or_null("PortalVisual") as Node2D
	_runner.assert_true(ping_marker.visible, "open door shows exit ping")
	_runner.assert_not_null(portal_visual, "open door creates a portal visual")
	if portal_visual != null:
		_runner.assert_true(portal_visual.visible, "open door shows portal visual")
	_runner.assert_true(visual.color.a < 0.01, "open door hides the old flat green rectangle")

	door.lock()

	_runner.assert_true(door.is_locked(), "door returns to locked state")
	_runner.assert_eq(visual.color, RoomPalette.DOOR_LOCKED_COLOR, "locked color reapplies")
	_runner.assert_false(ping_marker.visible, "locked door hides exit ping again")
	if portal_visual != null:
		_runner.assert_false(portal_visual.visible, "locked door hides portal visual again")
	_runner.assert_eq(states, [RoomDoor.DoorState.OPEN, RoomDoor.DoorState.LOCKED], "state signal emits only on changes")


func test_open_door_builds_five_frame_sprite_portal() -> void:
	var door := _create_door(&"E")

	door.open()

	var portal_visual := door.get_node_or_null("PortalVisual") as Node2D
	_runner.assert_not_null(portal_visual, "open door creates a portal visual")
	if portal_visual == null:
		return
	var portal_sprite := portal_visual.get_node_or_null("PortalSprite") as Sprite2D

	_runner.assert_not_null(portal_sprite, "portal uses the 5-frame sprite sheet")
	if portal_sprite == null:
		return
	_runner.assert_not_null(portal_sprite.texture, "portal sprite loads a texture")
	if portal_sprite.texture != null:
		_runner.assert_eq(portal_sprite.texture.resource_path, "res://assets/effects/portal.png", "portal uses the supplied sprite sheet")
	_runner.assert_eq(portal_sprite.hframes, 5, "portal sprite sheet has five horizontal frames")
	_runner.assert_eq(portal_sprite.vframes, 1, "portal sprite sheet has one row")
	_runner.assert_eq(portal_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "portal keeps pixel edges crisp")
	_runner.assert_true(portal_sprite.frame >= 0 and portal_sprite.frame < 5, "portal starts on a valid animation frame")
	_runner.assert_true(portal_visual.get_node_or_null("PortalColumn") == null, "procedural light column is removed")
	_runner.assert_true(portal_visual.get_node_or_null("PortalGroundGlow") == null, "procedural ground flare is removed")
	_runner.assert_true(portal_visual.get_node_or_null("PortalStreaks") == null, "procedural streaks are removed")
	_runner.assert_true(portal_visual.get_node_or_null("PortalSparkles") == null, "procedural sparkles are removed")


func test_open_door_portal_animates_sprite_frames_without_scaling() -> void:
	var door := _create_door(&"W")

	door.open()

	var portal_visual := door.get_node_or_null("PortalVisual") as Node2D
	_runner.assert_not_null(portal_visual, "open door creates a portal visual")
	if portal_visual == null:
		return
	var portal_sprite := portal_visual.get_node_or_null("PortalSprite") as Sprite2D
	_runner.assert_not_null(portal_sprite, "portal uses an animated sprite")
	if portal_sprite == null:
		return
	var initial_sprite_scale := portal_sprite.scale
	portal_sprite.frame = 0

	door._process(0.09)

	_runner.assert_eq(portal_sprite.frame, 1, "portal advances to the next sheet frame")
	_runner.assert_eq(portal_visual.scale, Vector2.ONE, "portal root does not pulse while animating")
	_runner.assert_eq(portal_sprite.scale, initial_sprite_scale, "portal sprite keeps a fixed display size")


func test_transition_request_requires_open_door() -> void:
	var door := _create_door(&"S")
	var requests: Array[StringName] = []
	var on_transition_requested := func(door_dir: StringName) -> void:
		requests.append(door_dir)

	door.transition_requested.connect(on_transition_requested)

	_runner.assert_false(door.request_transition(), "locked door rejects transition request")
	_runner.assert_eq(requests.size(), 0, "locked door does not emit transition")

	door.open()

	_runner.assert_true(door.request_transition(), "open door accepts transition request")
	_runner.assert_eq(requests, [&"S"], "open door emits direction")


func test_actor_overlap_transition_emits_once_per_entry() -> void:
	var door := _create_door(&"W")
	var actor := Node2D.new()
	var requests: Array[StringName] = []
	var on_transition_requested := func(door_dir: StringName) -> void:
		requests.append(door_dir)

	add_child(actor)
	door.transition_requested.connect(on_transition_requested)
	door.configure_actor(actor)
	door.open()

	actor.global_position = door.global_position

	_runner.assert_true(door.check_transition_for_actor(actor), "actor entering open door requests transition")
	_runner.assert_false(door.check_transition_for_actor(actor), "same overlap does not emit repeatedly")

	actor.global_position += Vector2(RoomPalette.DOOR_TRIGGER_SIZE.x * 2.0, 0.0)
	_runner.assert_false(door.check_transition_for_actor(actor), "actor outside trigger does not request transition")

	actor.global_position = door.global_position
	_runner.assert_true(door.check_transition_for_actor(actor), "actor can trigger after re-entering")
	_runner.assert_eq(requests, [&"W", &"W"], "door emits once for each trigger entry")


func _create_door(door_dir: StringName) -> RoomDoor:
	var door := RoomDoor.new()
	door.name = "%sDoor" % String(door_dir)
	door.door_dir = door_dir

	var visual := ColorRect.new()
	visual.name = "DoorVisual"
	door.add_child(visual)

	var transition_area := Area2D.new()
	transition_area.name = "TransitionArea"
	transition_area.collision_layer = 0
	door.add_child(transition_area)

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	transition_area.add_child(collision_shape)

	add_child(door)
	return door
