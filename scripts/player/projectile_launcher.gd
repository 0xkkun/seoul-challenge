extends Node
## #10 정화탄 발사기 — 부모(플레이어)의 fired 시그널을 받아 풀에서 정화탄을 스폰한다.
## 풀링/스폰 책임을 플레이어에서 분리한다(플레이어는 fired 만 방출).

const BULLET_SCENE := preload("res://scenes/projectiles/purify_bullet.tscn")
const POOL_ID := &"purify_bullet"

@export var prewarm: int = 8


func _ready() -> void:
	PoolManager.register_scene(POOL_ID, BULLET_SCENE, prewarm, _spawn_parent())
	var source := get_parent()
	if source != null and source.has_signal("fired"):
		source.connect("fired", _on_fired)


func _on_fired(muzzle_position: Vector2, direction: Vector2) -> void:
	var bullet := PoolManager.acquire(POOL_ID, _spawn_parent())
	if bullet != null and bullet.has_method("activate"):
		bullet.call("activate", muzzle_position, direction, get_parent())


## 정화탄을 붙일 부모: 플레이어의 부모(월드) → 현재 씬 → self 순으로 폴백.
func _spawn_parent() -> Node:
	var player := get_parent()
	if player != null and player.get_parent() != null:
		return player.get_parent()
	if is_inside_tree() and get_tree().current_scene != null:
		return get_tree().current_scene
	return self
