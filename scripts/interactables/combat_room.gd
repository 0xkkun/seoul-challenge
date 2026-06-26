class_name CombatRoom
extends Room

const CHASER_SCENE = preload("res://scenes/enemies/chaser.tscn")
const RANGED_SHOOTER_SCENE = preload("res://scenes/enemies/ranged_shooter.tscn")
const CHASER_SPAWN_FACTORS: Array[Vector2] = [
	Vector2(0.15, -0.35),
	Vector2(0.45, 0.35),
	Vector2(0.3, 0.15),
	Vector2(0.65, -0.1),
]
const RANGED_SPAWN_FACTORS: Array[Vector2] = [
	Vector2(0.65, 0.0),
	Vector2(0.3, -0.2),
	Vector2(0.5, 0.3),
]
const ELITE_COLOR := Color(0.95, 0.72, 0.22, 1.0)

signal combat_started(room_id: StringName, enemy_count: int)
signal combat_resolved(room_id: StringName)
signal combat_cleared(room_id: StringName)
signal enemy_count_changed(remaining_count: int)

@export var chaser_scene: PackedScene = CHASER_SCENE
@export var ranged_scene: PackedScene = RANGED_SHOOTER_SCENE
@export_range(0, 12, 1) var chaser_count := 2
@export_range(0, 12, 1) var ranged_count := 1
@export_range(0, 12, 1) var elite_chaser_count := 0
@export_range(0, 12, 1) var elite_ranged_count := 0
@export_range(1, 8, 1) var elite_health_multiplier := 2
@export_range(1.0, 2.0, 0.05) var elite_speed_multiplier := 1.15
@export_range(0.2, 1.0, 0.05) var elite_fire_interval_multiplier := 0.75
@export_range(0, 6, 1) var elite_contact_damage_bonus := 1
@export_range(0, 99, 1) var enemy_defeat_ingame_reward := 1
@export_range(0, 99, 1) var combat_clear_ingame_reward := 3

var _combat_started := false
var _combat_resolved := false
var _active_enemies: Array[Node] = []

@onready var _enemy_layer: Node2D = _resolve_enemy_layer()


func _ready() -> void:
	room_type = &"combat"
	super._ready()


func enter() -> void:
	super.enter()
	if _combat_resolved:
		return
	if not _combat_started:
		_combat_started = true
		_spawn_encounter()
		combat_started.emit(room_id, get_remaining_enemy_count())
	if get_remaining_enemy_count() == 0:
		resolve_combat()


func is_cleared() -> bool:
	return _combat_resolved


func apply_room_config(config: Dictionary) -> void:
	chaser_count = _config_count(config, "chaser_count", chaser_count)
	ranged_count = _config_count(config, "ranged_count", ranged_count)
	elite_chaser_count = _config_count(config, "elite_chaser_count", elite_chaser_count)
	elite_ranged_count = _config_count(config, "elite_ranged_count", elite_ranged_count)


func get_encounter_summary() -> Dictionary:
	return {
		"chaser_count": chaser_count,
		"ranged_count": ranged_count,
		"elite_chaser_count": elite_chaser_count,
		"elite_ranged_count": elite_ranged_count,
		"total_count": chaser_count + ranged_count + elite_chaser_count + elite_ranged_count,
	}


func resolve_combat() -> void:
	if _combat_resolved:
		return
	_combat_resolved = true
	_emit_ingame_reward(combat_clear_ingame_reward, "combat_clear")
	combat_resolved.emit(room_id)
	combat_cleared.emit(room_id)
	enemy_count_changed.emit(0)
	mark_cleared()


func restore_cleared_state() -> void:
	_combat_started = true
	_combat_resolved = true
	_active_enemies.clear()
	super.restore_cleared_state()


func get_active_enemies() -> Array[Node]:
	_prune_inactive_enemies()
	return _active_enemies.duplicate()


func get_remaining_enemy_count() -> int:
	_prune_inactive_enemies()
	return _active_enemies.size()


func get_alive_count() -> int:
	return get_remaining_enemy_count()


func _spawn_encounter() -> void:
	_active_enemies.clear()
	_spawn_enemy_group(chaser_scene, chaser_count, CHASER_SPAWN_FACTORS, "Chaser")
	_spawn_enemy_group(ranged_scene, ranged_count, RANGED_SPAWN_FACTORS, "RangedShooter")
	_spawn_enemy_group(chaser_scene, elite_chaser_count, CHASER_SPAWN_FACTORS, "EliteChaser", true)
	_spawn_enemy_group(ranged_scene, elite_ranged_count, RANGED_SPAWN_FACTORS, "EliteRangedShooter", true)
	enemy_count_changed.emit(_active_enemies.size())


func _spawn_enemy_group(
	scene: PackedScene,
	count: int,
	spawn_factors: Array[Vector2],
	name_prefix: String,
	elite_variant := false
) -> void:
	if scene == null or count <= 0 or spawn_factors.is_empty():
		return
	for index in range(count):
		var enemy := scene.instantiate()
		if not enemy is Node2D:
			enemy.queue_free()
			continue
		_apply_enemy_variant(enemy, elite_variant)
		_enemy_layer.add_child(enemy)
		enemy.name = "%s%d" % [name_prefix, index + 1]
		(enemy as Node2D).position = RoomPalette.ROOM_HALF_SIZE * spawn_factors[index % spawn_factors.size()]
		_connect_enemy(enemy)
		_active_enemies.append(enemy)


func _apply_enemy_variant(enemy: Node, elite_variant: bool) -> void:
	if not elite_variant:
		enemy.set_meta("encounter_variant", &"normal")
		return

	enemy.set_meta("encounter_variant", &"elite")
	enemy.add_to_group(&"elite_enemy")
	if _has_property(enemy, "max_hp"):
		_set_int_property(enemy, "max_hp", maxi(1, int(enemy.get("max_hp")) * elite_health_multiplier))
	if _has_property(enemy, "contact_damage"):
		_set_int_property(enemy, "contact_damage", int(enemy.get("contact_damage")) + elite_contact_damage_bonus)
	if _has_property(enemy, "move_speed"):
		enemy.set("move_speed", float(enemy.get("move_speed")) * elite_speed_multiplier)
	if _has_property(enemy, "fire_interval"):
		enemy.set("fire_interval", maxf(0.35, float(enemy.get("fire_interval")) * elite_fire_interval_multiplier))

	var placeholder := enemy.get_node_or_null("Placeholder")
	if placeholder is Polygon2D:
		(placeholder as Polygon2D).color = ELITE_COLOR
	elif placeholder is CanvasItem:
		(placeholder as CanvasItem).modulate = ELITE_COLOR


func _connect_enemy(enemy: Node) -> void:
	if not enemy.has_signal("defeated"):
		return
	var callback := Callable(self, "_on_enemy_defeated")
	if not enemy.is_connected("defeated", callback):
		enemy.connect("defeated", callback)


func _on_enemy_defeated(enemy: Node) -> void:
	if not _active_enemies.has(enemy):
		return
	_active_enemies.erase(enemy)
	_emit_ingame_reward(enemy_defeat_ingame_reward, "enemy_defeated")
	var remaining := get_remaining_enemy_count()
	enemy_count_changed.emit(remaining)
	if remaining == 0:
		resolve_combat()


func _prune_inactive_enemies() -> void:
	for index in range(_active_enemies.size() - 1, -1, -1):
		var enemy := _active_enemies[index]
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			_active_enemies.remove_at(index)


func _resolve_enemy_layer() -> Node2D:
	var layer := get_node_or_null("Enemies") as Node2D
	if layer != null:
		return layer
	layer = Node2D.new()
	layer.name = "Enemies"
	add_child(layer)
	return layer


func _config_count(config: Dictionary, key: String, fallback: int) -> int:
	if not config.has(key):
		return fallback
	return clampi(int(config[key]), 0, 12)


func _set_int_property(node: Node, property_name: String, value: int) -> void:
	if not _has_property(node, property_name):
		return
	node.set(property_name, value)


func _has_property(node: Node, property_name: String) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _emit_ingame_reward(amount: int, reason: String) -> void:
	if amount <= 0 or not has_node("/root/EventBus"):
		return
	EventBus.emit_currency_changed({
		"kind": "ingame",
		"amount": amount,
		"reason": reason,
		"room_id": room_id,
		"room_type": room_type,
	})
