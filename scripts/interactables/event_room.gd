class_name EventRoom
extends Room

const RESCUE_STUDENT_SCENE = preload("res://scenes/interactables/rescue_student.tscn")
const RESCUE_STUDENT_SPAWN_FACTORS: Array[Vector2] = [
	Vector2(-0.45, -0.25),
	Vector2(0.45, -0.2),
	Vector2(-0.25, 0.4),
	Vector2(0.35, 0.4),
]

signal event_started(room_id: StringName)
signal event_resolved(room_id: StringName)
signal rescue_progress_changed(rescued_count: int, required_count: int)

@export var student_pool_id: StringName = &"rescue_student"
@export var rescue_student_scene: PackedScene = RESCUE_STUDENT_SCENE
@export_range(1, 8, 1) var rescue_student_count_min := 1
@export_range(1, 8, 1) var rescue_student_count_max := 2
@export var rescue_reward_amount := 1
@export var random_seed := 0

var _event_active := false
var _event_resolved := false
var _students_spawned := false
var _rescued_count := 0
var _required_rescue_count := 0
var _active_students: Array[Node] = []
var _rng := RandomNumberGenerator.new()

@onready var _student_layer: Node = _resolve_student_layer()


func _ready() -> void:
	room_type = &"event"
	super._ready()
	_configure_rng()
	_register_student_pool()


func enter() -> void:
	if _event_resolved:
		super.enter()
		return
	if not _event_active:
		_event_active = true
		event_started.emit(room_id)
	if not _students_spawned:
		_spawn_rescue_students()
	super.enter()
	if _required_rescue_count == 0:
		resolve_event()


func is_cleared() -> bool:
	return _event_resolved


func resolve_event() -> void:
	if _event_resolved:
		return
	_event_resolved = true
	event_resolved.emit(room_id)
	mark_cleared()


func get_active_students() -> Array[Node]:
	return _active_students.duplicate()


func get_rescued_count() -> int:
	return _rescued_count


func get_required_rescue_count() -> int:
	return _required_rescue_count


func _configure_rng() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed


func _register_student_pool() -> void:
	if rescue_student_scene == null or not has_node("/root/PoolManager"):
		return
	PoolManager.register_scene(student_pool_id, rescue_student_scene, rescue_student_count_max, _student_layer)


func _spawn_rescue_students() -> void:
	_students_spawned = true
	_rescued_count = 0
	_active_students.clear()
	_required_rescue_count = _pick_student_count()

	var spawn_points := _build_spawn_points()
	_shuffle_spawn_points(spawn_points)
	for index in range(_required_rescue_count):
		var student := _acquire_student()
		if student == null:
			continue
		var spawn_position := spawn_points[index % spawn_points.size()]
		var student_id := StringName("%s_student_%d" % [room_id, index + 1])
		_prepare_student(student, student_id, spawn_position)
		_active_students.append(student)

	_required_rescue_count = _active_students.size()
	rescue_progress_changed.emit(_rescued_count, _required_rescue_count)


func _pick_student_count() -> int:
	var lower := mini(rescue_student_count_min, rescue_student_count_max)
	var upper := maxi(rescue_student_count_min, rescue_student_count_max)
	return _rng.randi_range(lower, upper)


func _shuffle_spawn_points(spawn_points: Array[Vector2]) -> void:
	for index in range(spawn_points.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var current := spawn_points[index]
		spawn_points[index] = spawn_points[swap_index]
		spawn_points[swap_index] = current


func _build_spawn_points() -> Array[Vector2]:
	var spawn_points: Array[Vector2] = []
	for factor: Vector2 in RESCUE_STUDENT_SPAWN_FACTORS:
		spawn_points.append(RoomPalette.ROOM_HALF_SIZE * factor)
	return spawn_points


func _acquire_student() -> Node:
	if has_node("/root/PoolManager"):
		return PoolManager.acquire(student_pool_id, _student_layer)
	if rescue_student_scene == null:
		return null
	var student := rescue_student_scene.instantiate()
	_student_layer.add_child(student)
	return student


func _prepare_student(student: Node, student_id: StringName, spawn_position: Vector2) -> void:
	if student.has_method("configure_rescue"):
		student.call("configure_rescue", student_id, rescue_reward_amount)
	if student.has_method("activate_at"):
		student.call("activate_at", spawn_position)
	elif student is Node2D:
		(student as Node2D).position = spawn_position
	if student.has_signal("rescued"):
		var callback := Callable(self, "_on_student_rescued")
		if not student.rescued.is_connected(callback):
			student.rescued.connect(callback)


func _on_student_rescued(student: Node, _source: Node) -> void:
	if not _active_students.has(student):
		return
	_active_students.erase(student)
	_rescued_count += 1
	if has_node("/root/PoolManager") and student.has_meta("pool_id"):
		PoolManager.release(student)
	else:
		student.queue_free()
	rescue_progress_changed.emit(_rescued_count, _required_rescue_count)
	if _rescued_count >= _required_rescue_count:
		resolve_event()


func _resolve_student_layer() -> Node:
	var layer := get_node_or_null("Students")
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Students"
	add_child(layer)
	return layer
