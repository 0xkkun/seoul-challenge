class_name CombatRoom
extends Room
## 전투 방 — 입장 시 잡몹을 스폰하고, 전부 처치(defeated)되면 방을 클리어한다.
## #11 chaser / #16 ranged_shooter 적 프리미티브를 재사용한다(계약: defeated 시그널 + take_damage).
## 클리어 전까지 문은 잠겨 있어(Room 기본 동작) 플레이어는 적을 처치해야 다음 방으로 간다.

const CHASER_SCENE = preload("res://scenes/enemies/chaser.tscn")
const RANGED_SCENE = preload("res://scenes/enemies/ranged_shooter.tscn")
## 방 절반 크기 기준 스폰 위치 비율.
## 벨트 진행 방향(오른쪽) 쪽에 깊이를 달리해 스폰한다.
const ENEMY_SPAWN_FACTORS: Array[Vector2] = [
	Vector2(0.15, -0.35),
	Vector2(0.45, 0.35),
	Vector2(0.65, 0.0),
	Vector2(0.3, 0.15),
]

signal combat_started(room_id: StringName)
signal combat_cleared(room_id: StringName)

@export var chaser_count := 2
@export var ranged_count := 1

var _combat_active := false
var _combat_resolved := false
var _enemies_spawned := false
var _alive: Array[Node] = []

@onready var _enemy_layer: Node = _resolve_enemy_layer()


func _ready() -> void:
	room_type = &"combat"
	super._ready()


func enter() -> void:
	if _combat_resolved:
		super.enter()
		return
	if not _combat_active:
		_combat_active = true
		combat_started.emit(room_id)
	if not _enemies_spawned:
		_spawn_enemies()
	super.enter()
	if _alive.is_empty():
		_resolve_combat()


func is_cleared() -> bool:
	return _combat_resolved


func get_alive_count() -> int:
	return _alive.size()


func _spawn_enemies() -> void:
	_enemies_spawned = true
	_alive.clear()
	var points := _build_spawn_points()
	var index := 0
	for i in maxi(0, chaser_count):
		_spawn_one(CHASER_SCENE, points[index % points.size()])
		index += 1
	for i in maxi(0, ranged_count):
		_spawn_one(RANGED_SCENE, points[index % points.size()])
		index += 1


func _spawn_one(scene: PackedScene, spawn_position: Vector2) -> void:
	if scene == null:
		return
	var enemy := scene.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).position = spawn_position
	_enemy_layer.add_child(enemy)
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(_on_enemy_defeated)
	_alive.append(enemy)


func _on_enemy_defeated(enemy: Node) -> void:
	if not _alive.has(enemy):
		return
	_alive.erase(enemy)
	if _alive.is_empty():
		_resolve_combat()


func _resolve_combat() -> void:
	if _combat_resolved:
		return
	_combat_resolved = true
	combat_cleared.emit(room_id)
	mark_cleared()


func _build_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for factor: Vector2 in ENEMY_SPAWN_FACTORS:
		points.append(RoomPalette.ROOM_HALF_SIZE * factor)
	return points


func _resolve_enemy_layer() -> Node:
	var layer := get_node_or_null("Enemies")
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Enemies"
	add_child(layer)
	return layer
