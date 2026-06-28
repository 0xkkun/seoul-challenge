extends RefCounted


static func clamp_body_position_to_bounds(position: Vector2, bounds: Rect2, body: Node2D) -> Vector2:
	var position_bounds := body_position_bounds(bounds, body)
	return Vector2(
		clampf(position.x, position_bounds.position.x, position_bounds.end.x),
		clampf(position.y, position_bounds.position.y, position_bounds.end.y)
	)


static func body_position_bounds(bounds: Rect2, body: Node2D) -> Rect2:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or body == null:
		return bounds
	var local_rect := collision_local_rect(body)
	if local_rect.size.x <= 0.0 or local_rect.size.y <= 0.0:
		return bounds
	var x_range := _axis_position_range(bounds.position.x, bounds.end.x, local_rect.position.x, local_rect.end.x)
	var y_range := _axis_position_range(bounds.position.y, bounds.end.y, local_rect.position.y, local_rect.end.y)
	return Rect2(
		Vector2(x_range.x, y_range.x),
		Vector2(maxf(0.0, x_range.y - x_range.x), maxf(0.0, y_range.y - y_range.x))
	)


static func collision_local_rect(body: Node2D) -> Rect2:
	if body == null:
		return Rect2()
	var state := {
		"has_rect": false,
		"rect": Rect2(),
	}
	_collect_collision_rects(body, body, state)
	return state["rect"] if bool(state["has_rect"]) else Rect2()


static func _axis_position_range(bound_min: float, bound_max: float, local_min: float, local_max: float) -> Vector2:
	var min_position := bound_min - local_min
	var max_position := bound_max - local_max
	if min_position > max_position:
		var centered := (bound_min + bound_max - local_min - local_max) * 0.5
		return Vector2(centered, centered)
	return Vector2(min_position, max_position)


static func _collect_collision_rects(body: Node2D, node: Node, state: Dictionary) -> void:
	for child: Node in node.get_children():
		var collision := child as CollisionShape2D
		if collision != null and not collision.disabled and collision.shape != null:
			_merge_collision_rect(body, collision, state)
		_collect_collision_rects(body, child, state)


static func _merge_collision_rect(body: Node2D, collision: CollisionShape2D, state: Dictionary) -> void:
	var points := _shape_points(collision.shape)
	if points.is_empty():
		return
	var rect := Rect2()
	var has_point := false
	for point: Vector2 in points:
		var body_local := body.to_local(collision.to_global(point))
		if not has_point:
			rect = Rect2(body_local, Vector2.ZERO)
			has_point = true
		else:
			rect = rect.expand(body_local)
	if not has_point:
		return
	if bool(state["has_rect"]):
		state["rect"] = (state["rect"] as Rect2).merge(rect)
	else:
		state["rect"] = rect
		state["has_rect"] = true


static func _shape_points(shape: Shape2D) -> PackedVector2Array:
	var circle := shape as CircleShape2D
	if circle != null:
		var radius := circle.radius
		return PackedVector2Array([
			Vector2(-radius, -radius),
			Vector2(radius, -radius),
			Vector2(radius, radius),
			Vector2(-radius, radius),
		])
	var rectangle := shape as RectangleShape2D
	if rectangle != null:
		var half := rectangle.size * 0.5
		return PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y),
		])
	var capsule := shape as CapsuleShape2D
	if capsule != null:
		var half_height := capsule.height * 0.5
		var radius := capsule.radius
		return PackedVector2Array([
			Vector2(-radius, -half_height),
			Vector2(radius, -half_height),
			Vector2(radius, half_height),
			Vector2(-radius, half_height),
		])
	return PackedVector2Array()
