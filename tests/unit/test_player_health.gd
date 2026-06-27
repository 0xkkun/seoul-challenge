extends Node
## 플레이어 체력/피격 — 적 데미지 ↔ EventBus(player_health_changed) 연결 단위 테스트.
## (Codex 리뷰: 플레이어에 take_damage 가 없어 적탄이 무효였던 버그 수정)

const PlayerScript := preload("res://scripts/player/player.gd")
const PlayerScene := preload("res://scenes/player/player.tscn")

var _runner: Node


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_damaged_health_clamps_to_zero() -> void:
	var p = PlayerScript.new()
	_runner.assert_eq(p.damaged_health(5, 2), 3, "5-2=3")
	_runner.assert_eq(p.damaged_health(1, 5), 0, "0 미만은 클램프")
	p.free()


func test_take_damage_reduces_health() -> void:
	var p = PlayerScript.new()
	add_child(p)  # _ready → _health = max_health
	var before: int = p.get_health()
	_runner.assert_true(before > 0, "초기 체력 > 0")
	p.take_damage(2)
	_runner.assert_eq(p.get_health(), before - 2, "피해만큼 체력 감소")
	p.free()


func test_invuln_blocks_immediate_second_hit() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.take_damage(1)
	var after_first: int = p.get_health()
	p.take_damage(1)  # 무적시간 내 → 무시
	_runner.assert_eq(p.get_health(), after_first, "무적시간 중 추가 피해 무시")
	p.free()


func test_hit_reaction_flashes_sprite_and_restores_after_invuln() -> void:
	var p = PlayerScene.instantiate()
	add_child(p)
	var sprite := p.get_node("Sprite") as CanvasItem
	var base_modulate := sprite.modulate
	p.take_damage(1)
	_runner.assert_true(p.has_method("is_hit_invulnerable"), "플레이어는 피격 무적 질의 API를 노출한다")
	_runner.assert_true(p.call("is_hit_invulnerable"), "피격 직후 무적 상태가 된다")
	_runner.assert_true(sprite.modulate != base_modulate, "피격 직후 스프라이트 시각 효과가 적용된다")
	p.call("tick_hit_reaction", p.invuln_time + 0.05)
	_runner.assert_false(p.call("is_hit_invulnerable"), "무적 시간이 끝나면 비활성화된다")
	_runner.assert_eq(sprite.modulate, base_modulate, "무적 종료 후 스프라이트 색/투명도가 복구된다")
	p.queue_free()


func test_emits_player_health_changed_on_damage() -> void:
	var p = PlayerScript.new()
	add_child(p)
	var got := {"current": -1, "max": -1}
	var cb := func(payload: Dictionary) -> void:
		got["current"] = int(payload.get("current", -1))
		got["max"] = int(payload.get("max", -1))
	EventBus.player_health_changed.connect(cb)
	p.take_damage(1)
	EventBus.player_health_changed.disconnect(cb)
	_runner.assert_eq(got["max"], p.max_health, "EventBus 발신: max")
	_runner.assert_eq(got["current"], p.max_health - 1, "EventBus 발신: current")
	p.free()
