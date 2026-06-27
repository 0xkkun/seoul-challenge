class_name RoomLayoutGenerator
extends Resource

const DEFAULT_SCENE_PATH := "res://scenes/session/room_base.tscn"
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(1, 0),
	Vector2i(-1, 0),
]
const MIN_GENERATED_SPECIAL_ROOM_COUNT := 8

@export var seed := 1
@export_range(8, 64) var default_room_count := 15
@export_range(3, 32) var grid_width := 9
@export_range(3, 32) var grid_height := 8
@export_range(0.0, 1.0, 0.05) var branch_chance := 0.5
@export_file("*.tscn") var start_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var combat_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var event_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var treasure_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var shop_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var friend_scene_path := DEFAULT_SCENE_PATH
@export_file("*.tscn") var final_scene_path := DEFAULT_SCENE_PATH


func build_layout() -> RoomLayout:
	return generate(seed)


func generate(layout_seed: int, params: Dictionary = {}) -> RoomLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed

	var target_count := clampi(
		int(params.get("room_count", params.get("target_room_count", default_room_count))),
		MIN_GENERATED_SPECIAL_ROOM_COUNT,
		RoomLayout.MAX_ROOM_COUNT
	)
	var min_dimension := _minimum_grid_dimension_for_count(target_count)
	var width := maxi(maxi(3, int(params.get("grid_width", grid_width))), min_dimension)
	var height := maxi(maxi(3, int(params.get("grid_height", grid_height))), min_dimension)
	var chance := clampf(float(params.get("branch_chance", branch_chance)), 0.0, 1.0)
	var scene_paths: Variant = params.get("scene_paths", {})

	var cells := _generate_cells(rng, width, height, target_count, chance)
	var adjacency := _build_adjacency(cells)
	var distances := _compute_distances(adjacency, 0)
	var final_index := _pick_final_room_index(cells, adjacency, distances)
	var friend_index := _pick_friend_room_index_for_final(cells, final_index, adjacency, distances, [0, final_index])
	var event_index := _pick_special_room_index(cells, adjacency, distances, [0, final_index, friend_index])
	var treasure_index := _pick_special_room_index(cells, adjacency, distances, [0, final_index, friend_index, event_index])
	var shop_index := _pick_special_room_index(cells, adjacency, distances, [0, final_index, friend_index, event_index, treasure_index])
	var room_ids := _assign_room_ids(cells.size(), final_index, friend_index, event_index, treasure_index, shop_index)
	var max_combat_distance := _max_combat_distance(
		cells.size(),
		final_index,
		friend_index,
		event_index,
		treasure_index,
		shop_index,
		distances
	)

	var layout := RoomLayout.new()
	layout.layout_id = StringName("generated_%d" % layout_seed)
	layout.start_room_id = &"start"
	layout.required_clears_for_hidden_reveal = _hidden_reveal_threshold(cells.size())
	layout.room_defs = []

	for index: int in range(cells.size()):
		var room_def := RoomDef.new()
		room_def.room_id = room_ids[index]
		room_def.room_type = _room_type_for_index(index, final_index, friend_index, event_index, treasure_index, shop_index)
		room_def.scene_path = _scene_path_for_type(room_def.room_type, scene_paths)
		room_def.hidden = index == final_index
		room_def.connections = _connection_ids_for_index(index, cells, adjacency, room_ids)
		room_def.grid_pos = cells[index] - cells[0]
		room_def.room_config = _room_config_for_type(
			room_def.room_type,
			int(distances.get(index, 0)),
			max_combat_distance
		)
		layout.room_defs.append(room_def)

	_enforce_final_friend_gate(layout)
	return layout


func _minimum_grid_dimension_for_count(target_count: int) -> int:
	return maxi(3, int(ceil(sqrt(float(target_count)))) * 2)


func _hidden_reveal_threshold(room_count: int) -> int:
	var non_final_count := room_count - 1
	if non_final_count <= 4:
		return non_final_count
	return clampi(int(ceil(float(non_final_count) * 0.65)), 4, non_final_count - 1)


func _generate_cells(
	rng: RandomNumberGenerator,
	width: int,
	height: int,
	target_count: int,
	chance: float
) -> Array[Vector2i]:
	var start := Vector2i(width / 2, height / 2)
	var cells: Array[Vector2i] = [start]
	var occupied := {start: true}
	_grow_critical_path(rng, cells, occupied, width, height, _minimum_boss_distance_for_count(target_count))

	var queue: Array[Vector2i] = cells.duplicate()
	var queue_index := 0

	while cells.size() < target_count:
		if queue_index >= queue.size():
			var fallback := _collect_valid_candidates(cells, occupied, width, height)
			if fallback.is_empty():
				break
			var chosen: Vector2i = fallback[rng.randi_range(0, fallback.size() - 1)]
			_add_cell(chosen, cells, occupied, queue)
			queue_index = 0
			continue

		var current := queue[queue_index]
		queue_index += 1
		var neighbors := _shuffled_neighbors(current, rng)
		for candidate: Vector2i in neighbors:
			if cells.size() >= target_count:
				break
			if not _is_valid_candidate(candidate, occupied, width, height):
				continue
			if rng.randf() <= chance:
				_add_cell(candidate, cells, occupied, queue)

	return cells


func _minimum_boss_distance_for_count(target_count: int) -> int:
	return mini(target_count - 1, maxi(2, int(floor(float(target_count) * 0.4))))


func _grow_critical_path(
	rng: RandomNumberGenerator,
	cells: Array[Vector2i],
	occupied: Dictionary,
	width: int,
	height: int,
	target_distance: int
) -> void:
	var start := cells[0]
	while cells.size() - 1 < target_distance:
		var current := cells[cells.size() - 1]
		var candidates: Array[Vector2i] = []
		for candidate: Vector2i in _shuffled_neighbors(current, rng):
			if candidate.x < 0 or candidate.y < 0 or candidate.x >= width or candidate.y >= height:
				continue
			if occupied.has(candidate):
				continue
			if _occupied_neighbor_count(candidate, occupied) != 1:
				continue
			candidates.append(candidate)
		if candidates.is_empty():
			return

		var chosen := candidates[0]
		var chosen_distance := _grid_distance(chosen, start)
		for candidate: Vector2i in candidates:
			var candidate_distance := _grid_distance(candidate, start)
			if candidate_distance > chosen_distance:
				chosen = candidate
				chosen_distance = candidate_distance
		occupied[chosen] = true
		cells.append(chosen)


func _grid_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _add_cell(
	cell: Vector2i,
	cells: Array[Vector2i],
	occupied: Dictionary,
	queue: Array[Vector2i]
) -> void:
	occupied[cell] = true
	cells.append(cell)
	queue.append(cell)


func _shuffled_neighbors(cell: Vector2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		neighbors.append(cell + direction)

	for index: int in range(neighbors.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temp := neighbors[index]
		neighbors[index] = neighbors[swap_index]
		neighbors[swap_index] = temp

	return neighbors


func _collect_valid_candidates(
	cells: Array[Vector2i],
	occupied: Dictionary,
	width: int,
	height: int
) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var seen := {}
	for cell: Vector2i in cells:
		for direction: Vector2i in DIRECTIONS:
			var candidate := cell + direction
			if seen.has(candidate):
				continue
			seen[candidate] = true
			if _is_valid_candidate(candidate, occupied, width, height):
				candidates.append(candidate)
	return candidates


func _is_valid_candidate(candidate: Vector2i, occupied: Dictionary, width: int, height: int) -> bool:
	if candidate.x < 0 or candidate.y < 0 or candidate.x >= width or candidate.y >= height:
		return false
	if occupied.has(candidate):
		return false
	return _occupied_neighbor_count(candidate, occupied) < 3


func _occupied_neighbor_count(cell: Vector2i, occupied: Dictionary) -> int:
	var count := 0
	for direction: Vector2i in DIRECTIONS:
		if occupied.has(cell + direction):
			count += 1
	return count


func _build_adjacency(cells: Array[Vector2i]) -> Dictionary:
	var index_by_cell := {}
	for index: int in range(cells.size()):
		index_by_cell[cells[index]] = index

	var adjacency := {}
	for index: int in range(cells.size()):
		var neighbors: Array[int] = []
		for direction: Vector2i in DIRECTIONS:
			var neighbor_cell := cells[index] + direction
			if index_by_cell.has(neighbor_cell):
				neighbors.append(int(index_by_cell[neighbor_cell]))
		adjacency[index] = neighbors
	return adjacency


func _compute_distances(adjacency: Dictionary, start_index: int) -> Dictionary:
	var distances := {start_index: 0}
	var queue: Array[int] = [start_index]
	var cursor := 0

	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		for neighbor: int in adjacency[current]:
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			queue.append(neighbor)

	return distances


func _max_combat_distance(
	count: int,
	final_index: int,
	friend_index: int,
	event_index: int,
	treasure_index: int,
	shop_index: int,
	distances: Dictionary
) -> int:
	var max_value := 0
	for index: int in range(count):
		if _room_type_for_index(index, final_index, friend_index, event_index, treasure_index, shop_index) != RoomLayout.TYPE_COMBAT:
			continue
		max_value = maxi(max_value, int(distances.get(index, 0)))
	return max_value


func _room_config_for_type(room_type: StringName, distance_from_start: int, max_distance: int) -> Dictionary:
	if room_type != RoomLayout.TYPE_COMBAT:
		return {}
	return _combat_room_config(distance_from_start, max_distance)


func _combat_room_config(distance_from_start: int, max_distance: int) -> Dictionary:
	var progress := 0.0
	if max_distance > 0:
		progress = clampf(float(distance_from_start) / float(max_distance), 0.0, 1.0)

	if progress >= 0.7:
		return {
			"chaser_count": 3,
			"ranged_count": 2,
			"wolf_count": 1,
			"elite_chaser_count": 0,
			"elite_ranged_count": 0,
			"elite_wolf_count": 0,
			"wave_count": 2,
		}
	if progress >= 0.4:
		return {
			"chaser_count": 3,
			"ranged_count": 2,
			"wolf_count": 1,
			"elite_chaser_count": 0,
			"elite_ranged_count": 0,
			"elite_wolf_count": 0,
			"wave_count": 2,
		}
	return {
		"chaser_count": 2,
		"ranged_count": 1,
		"wolf_count": 1,
		"elite_chaser_count": 0,
		"elite_ranged_count": 0,
		"elite_wolf_count": 0,
		"wave_count": 1,
	}


func _pick_special_room_index(
	cells: Array[Vector2i],
	adjacency: Dictionary,
	distances: Dictionary,
	excluded: Array[int]
) -> int:
	var best_index := -1
	var best_distance := -1

	for index: int in range(cells.size()):
		if excluded.has(index):
			continue
		var neighbors: Array = adjacency[index]
		if neighbors.size() != 1:
			continue
		var distance := int(distances.get(index, -1))
		if _is_better_special_candidate(index, distance, best_index, best_distance, cells):
			best_index = index
			best_distance = distance

	if best_index != -1:
		return best_index

	for index: int in range(cells.size()):
		if excluded.has(index):
			continue
		var distance := int(distances.get(index, -1))
		if _is_better_special_candidate(index, distance, best_index, best_distance, cells):
			best_index = index
			best_distance = distance

	return best_index


func _pick_final_room_index(
	cells: Array[Vector2i],
	adjacency: Dictionary,
	distances: Dictionary
) -> int:
	var best_index := -1
	var best_distance := -1
	for index: int in range(cells.size()):
		if index == 0:
			continue
		var neighbors: Array = adjacency[index]
		if neighbors.has(0):
			continue
		if neighbors.size() != 1:
			continue
		var distance := int(distances.get(index, -1))
		if _is_better_special_candidate(index, distance, best_index, best_distance, cells):
			best_index = index
			best_distance = distance
	if best_index != -1:
		return best_index

	for index: int in range(cells.size()):
		if index == 0:
			continue
		var neighbors: Array = adjacency[index]
		var has_non_start_neighbor := false
		for neighbor: int in neighbors:
			if neighbor != 0:
				has_non_start_neighbor = true
				break
		if not has_non_start_neighbor:
			continue
		var distance := int(distances.get(index, -1))
		if _is_better_special_candidate(index, distance, best_index, best_distance, cells):
			best_index = index
			best_distance = distance
	if best_index != -1:
		return best_index

	return _pick_special_room_index(cells, adjacency, distances, [0])


func _pick_friend_room_index_for_final(
	cells: Array[Vector2i],
	final_index: int,
	adjacency: Dictionary,
	distances: Dictionary,
	excluded: Array[int]
) -> int:
	var neighbors: Array = adjacency.get(final_index, [])
	var best_index := -1
	var best_distance := -1
	for neighbor: int in neighbors:
		if excluded.has(neighbor):
			continue
		var distance := int(distances.get(neighbor, -1))
		if distance > best_distance:
			best_index = neighbor
			best_distance = distance
	if best_index != -1:
		return best_index
	return _pick_special_room_index(cells, adjacency, distances, excluded)


func _is_better_special_candidate(
	index: int,
	distance: int,
	best_index: int,
	best_distance: int,
	cells: Array[Vector2i]
) -> bool:
	if best_index == -1:
		return true
	if distance != best_distance:
		return distance > best_distance
	var cell := cells[index]
	var best_cell := cells[best_index]
	if cell.y != best_cell.y:
		return cell.y < best_cell.y
	return cell.x < best_cell.x


func _assign_room_ids(
	count: int,
	final_index: int,
	friend_index: int,
	event_index: int,
	treasure_index: int,
	shop_index: int
) -> Array[StringName]:
	var ids: Array[StringName] = []
	var combat_index := 1
	for index: int in range(count):
		if index == 0:
			ids.append(&"start")
		elif index == final_index:
			ids.append(&"final_1")
		elif index == friend_index:
			ids.append(&"friend_1")
		elif index == event_index:
			ids.append(&"event_1")
		elif index == treasure_index:
			ids.append(&"treasure_1")
		elif index == shop_index:
			ids.append(&"shop_1")
		else:
			ids.append(StringName("combat_%d" % combat_index))
			combat_index += 1
	return ids


func _room_type_for_index(
	index: int,
	final_index: int,
	friend_index: int,
	event_index: int,
	treasure_index: int,
	shop_index: int
) -> StringName:
	if index == 0:
		return RoomLayout.TYPE_START
	if index == final_index:
		return RoomLayout.TYPE_FINAL
	if index == friend_index:
		return RoomLayout.TYPE_FRIEND
	if index == event_index:
		return RoomLayout.TYPE_EVENT
	if index == treasure_index:
		return RoomLayout.TYPE_TREASURE
	if index == shop_index:
		return RoomLayout.TYPE_SHOP
	return RoomLayout.TYPE_COMBAT


func _connection_ids_for_index(
	index: int,
	cells: Array[Vector2i],
	adjacency: Dictionary,
	room_ids: Array[StringName]
) -> Array[StringName]:
	var connected_ids: Array[StringName] = []
	var neighbor_indices: Array[int] = adjacency[index]
	for direction: Vector2i in DIRECTIONS:
		var neighbor_cell := cells[index] + direction
		for neighbor_index: int in neighbor_indices:
			if cells[neighbor_index] == neighbor_cell:
				connected_ids.append(room_ids[neighbor_index])
				break
	return connected_ids


func _scene_path_for_type(room_type: StringName, scene_paths: Variant) -> String:
	if scene_paths is Dictionary:
		var map := scene_paths as Dictionary
		if map.has(room_type):
			return String(map[room_type])
		var string_key := String(room_type)
		if map.has(string_key):
			return String(map[string_key])

	match room_type:
		RoomLayout.TYPE_START:
			return start_scene_path
		RoomLayout.TYPE_EVENT:
			return event_scene_path
		RoomLayout.TYPE_TREASURE:
			return treasure_scene_path
		RoomLayout.TYPE_SHOP:
			return shop_scene_path
		RoomLayout.TYPE_FRIEND:
			return friend_scene_path
		RoomLayout.TYPE_FINAL:
			return final_scene_path
	return combat_scene_path


func _enforce_final_friend_gate(layout: RoomLayout) -> void:
	var final_room := layout.get_room(&"final_1")
	var friend_room := layout.get_room(&"friend_1")
	if final_room == null or friend_room == null:
		return

	final_room.connections = [friend_room.room_id]
	if not friend_room.connections.has(final_room.room_id):
		friend_room.connections.append(final_room.room_id)
	for room_def: RoomDef in layout.room_defs:
		if room_def == null or room_def == final_room or room_def == friend_room:
			continue
		room_def.connections.erase(final_room.room_id)
