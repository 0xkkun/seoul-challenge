extends Node
## #24 야구배트 보상 무기 — 넉백/무기전환/타격 단위 테스트.
## 기본 맨손 → equip_bat() 보상 시 더 강하고 길고 넉백.

const PlayerScript := preload("res://scripts/player/player.gd")

var _runner: Node


class StubEnemy extends Node2D:
	var taken: int = 0
	func take_damage(amount: int) -> void:
		taken += amount


func _set_runner(runner: Node) -> void:
	_runner = runner


func test_knockback_pushes_away() -> void:
	var p = PlayerScript.new()
	var k: Vector2 = p.knockback_vector(Vector2.ZERO, Vector2(10.0, 0.0), 50.0)
	_runner.assert_true(is_equal_approx(k.x, 50.0), "from→to 방향으로 distance만큼")
	_runner.assert_true(is_equal_approx(k.length(), 50.0), "크기 = distance")
	p.free()


func test_default_is_barehands_then_bat() -> void:
	var p = PlayerScript.new()
	_runner.assert_eq(p.current_weapon_name(), "맨손", "기본은 맨손")
	_runner.assert_false(p.is_bat_awakened(), "기본 배트 각성은 잠김")
	_runner.assert_false(p.has_bat(), "기본은 배트를 장착하지 않음")
	p.equip_bat()
	_runner.assert_true(p.has_bat(), "보상 후 배트 장착 상태를 노출")
	_runner.assert_eq(p.current_weapon_name(), "금 간 나무 배트", "보상 후 일반 배트 이름")
	p.free()


func test_awakened_bat_uses_final_season_name() -> void:
	var p = PlayerScript.new()
	p.equip_bat()
	p.set_bat_awakened(true)

	_runner.assert_true(p.has_bat(), "각성 배트도 배트 장착 상태")
	_runner.assert_true(p.is_bat_awakened(), "각성 상태가 켜짐")
	_runner.assert_eq(p.current_weapon_name(), "마지막 시즌의 배트", "각성 배트는 최종 이름으로 표시")
	p.free()


func test_equip_bat_disables_baseball_ranged_mode() -> void:
	var p = PlayerScript.new()
	p.ranged_enabled = true

	p.equip_bat()

	_runner.assert_false(p.ranged_enabled, "bat equip turns off baseball ranged mode")
	_runner.assert_eq(p.current_weapon_name(), "금 간 나무 배트", "bat equip still updates weapon name")
	p.free()


func test_barehands_damage() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	var e := StubEnemy.new()
	e.position = Vector2(30.0, 0.0)  # 맨손 사거리(34) 안
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, p.melee_damage, "맨손 피해")
	e.free()
	p.free()


func test_bat_awakened_state_is_explicit_for_progression_gate() -> void:
	var p = PlayerScript.new()
	_runner.assert_false(p.is_bat_awakened(), "progression 해금 전엔 미각성")
	p.set_bat_awakened(true)
	_runner.assert_true(p.is_bat_awakened(), "progression 해금 후 각성 상태를 켤 수 있음")
	p.free()


func test_bat_hits_harder_and_knocks_back() -> void:
	var p = PlayerScript.new()
	add_child(p)
	p.position = Vector2.ZERO
	p.equip_bat()
	var e := StubEnemy.new()
	e.position = Vector2(50.0, 0.0)  # 맨손(34)엔 안 닿지만 배트(56)엔 닿음
	e.add_to_group(&"enemy")
	add_child(e)
	p._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(e.taken, p.bat_damage, "배트 피해(맨손보다 큼)")
	_runner.assert_true(e.position.x > 50.0, "배트 넉백으로 밀려남")
	e.free()
	p.free()
