extends Node
## #10 정화탄 발사기 — 부모(플레이어)의 fired 시그널을 받아 풀에서 정화탄을 스폰한다.
## 풀링/스폰 책임을 플레이어에서 분리한다(플레이어는 fired 만 방출).

const BULLET_SCENE := preload("res://scenes/projectiles/purify_bullet.tscn")
const POOL_ID := &"purify_bullet"

## 발사체 정체성 — UI/도감이 weapon_info()로 읽는다.
const WEAPON_NAME := "정화탄"
const WEAPON_FLAVOR := "밤의 어둠을 밀어내는 작은 빛."

@export var prewarm: int = 8


func _ready() -> void:
	PoolManager.register_scene(POOL_ID, BULLET_SCENE, prewarm, _spawn_parent())
	var source := get_parent()
	if source != null and source.has_signal("fired"):
		source.connect("fired", _on_fired)


func _on_fired(muzzle_position: Vector2, direction: Vector2) -> void:
	var bullet := PoolManager.acquire(POOL_ID, _spawn_parent())
	if bullet != null and bullet.has_method("activate"):
		bullet.call("activate", muzzle_position, direction)


## 정화탄을 붙일 부모: 플레이어의 부모(월드) → 현재 씬 → self 순으로 폴백.
func _spawn_parent() -> Node:
	var player := get_parent()
	if player != null and player.get_parent() != null:
		return player.get_parent()
	if is_inside_tree() and get_tree().current_scene != null:
		return get_tree().current_scene
	return self


## 장착 무기 정보(이름·기억 플레이버) — UI/도감용.
func weapon_info() -> Dictionary:
	return {"name": WEAPON_NAME, "flavor": WEAPON_FLAVOR}
