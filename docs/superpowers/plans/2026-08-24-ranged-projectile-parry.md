# Ranged Projectile Parry Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 각성 배트로 첫 원거리 투사체를 실제 반사할 때까지 비차단 안내를 반복하고, 성공을 늑대 패링과 독립적으로 저장한다.

**Architecture:** `RangedShooter`가 실제 bullet node 생성 signal을 제공하고, `Player.parry_succeeded`가 `kind`로 늑대/투사체를 구분한다. `SessionRoot`는 종류별 eligibility와 signal lifecycle을 조정하고, 일반화한 `ParryOnboarding`과 기존 `ParryFeedbackController`를 공유한다.

**Tech Stack:** Godot 4.6.3, GDScript, custom unit/integration runner, headed Chromium WebGL2

**Spec:** `docs/superpowers/specs/2026-08-24-first-combat-input-language-design.md`

## Global Constraints

- GitHub issue `#549`, branch `feat/issue-549-ranged-projectile-parry`, worktree `../seoul-challenge-549`를 #546과 #548 merge 이후 최신 `origin/main`에서 생성한다.
- 각성 배트의 실제 `EnemyBullet.deflect()` 성공만 원거리 패링 완료로 센다.
- 각성 전 배트의 projectile 삭제와 이미 반사된 탄은 성공이 아니다.
- 원거리 안내는 miss/소멸 뒤 다음 탄에서 반복하고 room clear를 막지 않는다.
- `parry_tutorial_complete`와 `ranged_parry_tutorial_complete`를 합치지 않는다.
- 공통 패링 피드백 순서 `text → hit stop → flash → shake → sound → haptic`를 유지한다.
- 한 번에 coach prompt 하나만 활성화한다. 다른 종류 요청은 현재 prompt를 교체하지 않고 다음 eligible threat에서 재시도한다.
- PR은 ready, assignee, milestone, `P1`, `area:combat`, `area:enemy`, `area:ui`, inline UI capture를 갖는다.

---

### Task 1: bullet deflect와 projectile spawn을 관찰 가능하게 만들기

**Files:**
- Modify: `scripts/enemies/enemy_bullet.gd:30-48`
- Modify: `scripts/enemies/ranged_shooter.gd:1-15`
- Modify: `scripts/enemies/ranged_shooter.gd:340-360`
- Modify: `tests/unit/test_player_melee.gd:790-815`
- Modify: `tests/unit/test_ranged_shooter.gd`

**Interfaces:**
- Produces: `EnemyBullet.deflect(new_direction: Vector2) -> bool`, `RangedShooter.projectile_spawned(projectile: Node2D)`
- Consumes: existing `fired(origin, direction)` and projectile scene

- [ ] **Step 1: deflect return과 spawned node 실패 테스트 작성**

```gdscript
func test_enemy_bullet_deflect_returns_true_once_then_false() -> void:
	var bullet := (load("res://scenes/enemies/enemy_bullet.tscn") as PackedScene).instantiate()
	add_child(bullet)
	bullet.launch(Vector2.ZERO, Vector2.LEFT)
	_runner.assert_true(bullet.deflect(Vector2.RIGHT), "first deflect is accepted")
	_runner.assert_false(bullet.deflect(Vector2.UP), "already deflected bullet rejects repeats")
	_runner.assert_eq(bullet.collision_mask, 1, "accepted deflect targets enemies")


func test_ranged_shooter_emits_actual_spawned_projectile() -> void:
	var enemy = RangedShooterScene.instantiate()
	add_child(enemy)
	var projectiles: Array[Node2D] = []
	enemy.projectile_spawned.connect(func(projectile: Node2D) -> void: projectiles.append(projectile))
	enemy.call("_spawn_bullet", Vector2(10.0, 20.0), Vector2.RIGHT)
	_runner.assert_eq(projectiles.size(), 1, "one bullet node is announced")
	_runner.assert_true(is_instance_valid(projectiles[0]), "announced projectile is in the tree")
	_runner.assert_eq(projectiles[0].global_position, Vector2(10.0, 20.0), "signal follows launch")
```

- [ ] **Step 2: unit runner에서 void return/signal missing FAIL 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

- [ ] **Step 3: 최소 signal/return 구현**

```gdscript
# enemy_bullet.gd
func deflect(new_direction: Vector2) -> bool:
	if _deflected:
		return false
	_deflected = true
	# existing direction/rotation/speed/damage/mask/group/modulate changes
	return true
```

```gdscript
# ranged_shooter.gd
signal projectile_spawned(projectile: Node2D)

func _spawn_bullet(origin: Vector2, direction: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var scene := projectile_scene if projectile_scene != null else ENEMY_BULLET
	var bullet := scene.instantiate() as Node2D
	if bullet == null:
		return
	parent.add_child(bullet)
	bullet.call("launch", origin, direction)
	projectile_spawned.emit(bullet)
```

- [ ] **Step 4: unit runner PASS 확인**

Run: Step 2와 동일.

- [ ] **Step 5: projectile observation 커밋**

```bash
git add scripts/enemies/enemy_bullet.gd scripts/enemies/ranged_shooter.gd tests/unit/test_player_melee.gd tests/unit/test_ranged_shooter.gd
git commit -m "[Enemy] 투사체 생성과 실제 반사 성공 신호화"
```

### Task 2: Player parry payload를 종류별로 일반화

**Files:**
- Modify: `tests/unit/test_player_melee.gd:40-80`
- Modify: `tests/unit/test_player_melee.gd:630-820`
- Modify: `scripts/player/player.gd:1095-1170`
- Modify: `scripts/player/player.gd:1650-1685`
- Modify: `scripts/combat/parry_feedback_controller.gd:35-55`
- Modify: `tests/unit/test_parry_feedback_controller.gd`

**Interfaces:**
- Consumes: `EnemyBullet.deflect() -> bool`
- Produces: `parry_succeeded` payload `kind=&"wolf_dash"|&"enemy_projectile"`

- [ ] **Step 1: wolf kind와 projectile count 실패 테스트 작성**

`StubBullet.deflect()`는 bool을 반환하도록 바꾼다.

```gdscript
class StubBullet extends Node2D:
	var deflect_count := 0
	var accept_deflect := true
	func deflect(_direction: Vector2) -> bool:
		deflect_count += 1
		return accept_deflect
```

```gdscript
func test_parry_payload_distinguishes_wolf_and_projectile() -> void:
	var player = _new_awakened_bat_player()
	var payloads: Array[Dictionary] = []
	player.parry_succeeded.connect(func(payload: Dictionary) -> void: payloads.append(payload))
	var bullet := _add_stub_bullet(Vector2(40.0, 0.0), true)
	player._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 1)
	_runner.assert_eq(payloads[0]["kind"], &"enemy_projectile")
	_runner.assert_eq(payloads[0]["count"], 1)
	_runner.assert_eq(payloads[0]["projectile_position"], bullet.global_position)
	_runner.assert_eq(payloads[0]["target_position"], bullet.global_position)


func test_multiple_projectiles_emit_one_aggregated_parry_success() -> void:
	var player = _new_awakened_bat_player()
	var payloads: Array[Dictionary] = []
	player.parry_succeeded.connect(func(payload: Dictionary) -> void: payloads.append(payload))
	_add_stub_bullet(Vector2(32.0, -4.0), true)
	_add_stub_bullet(Vector2(40.0, 6.0), true)
	player._attack_melee(Vector2.RIGHT)
	_runner.assert_eq(payloads.size(), 1, "one swing emits one success")
	_runner.assert_eq(payloads[0]["count"], 2, "payload records accepted bullets")


func _new_awakened_bat_player() -> Node:
	var player = PlayerScript.new()
	add_child(player)
	player.call("equip_bat")
	player.call("set_bat_awakened", true)
	return player


func _add_stub_bullet(position: Vector2, accepted: bool) -> StubBullet:
	var bullet := StubBullet.new()
	bullet.global_position = position
	bullet.accept_deflect = accepted
	bullet.add_to_group(&"enemy_projectile")
	add_child(bullet)
	return bullet
```

기존 wolf test는 `payloads[0]["kind"] == &"wolf_dash"`와 `target_position == enemy_position`을 추가한다. `accept_deflect=false`와 unawakened clear는 projectile payload 0을 단정한다. `test_parry_feedback_controller.gd`에는 `target_position` 우선과 legacy fallback을 단정한다.

```gdscript
func test_feedback_target_position_supports_typed_and_legacy_payloads() -> void:
	_runner.assert_eq(
		ParryFeedbackController.feedback_target_position({"player_position": Vector2.ZERO, "target_position": Vector2(20.0, 8.0)}),
		Vector2(20.0, 8.0),
	)
	_runner.assert_eq(
		ParryFeedbackController.feedback_target_position({"player_position": Vector2.ZERO, "enemy_position": Vector2(12.0, 4.0)}),
		Vector2(12.0, 4.0),
	)
```

- [ ] **Step 2: unit runner에서 kind/count 단정 FAIL 확인**

Run: Task 1 Step 2.

- [ ] **Step 3: accepted projectile 결과를 집계해 payload 발행**

```gdscript
func _deflect_bullets_in_arc(dir: Vector2, rng: float, arc: float) -> Dictionary:
	var count := 0
	var first_position := Vector2.ZERO
	for bullet: Node in get_tree().get_nodes_in_group(&"enemy_projectile"):
		var node := bullet as Node2D
		if node == null or not _projectile_is_in_arc(node, dir, rng, arc):
			continue
		if node.has_method("deflect") and bool(node.call("deflect", dir)):
			if count == 0:
				first_position = node.global_position
			count += 1
	return {"count": count, "first_position": first_position}
```

`_attack_melee()`는 wolf 성공 payload에 `kind=&"wolf_dash"`를 넣고, projectile result count가 양수이면 한 번 emit한다.

```gdscript
parry_succeeded.emit({
	"kind": &"enemy_projectile",
	"direction": dir,
	"player_position": global_position,
	"target_position": result["first_position"],
	"projectile_position": result["first_position"],
	"count": result["count"],
})
```

wolf payload도 `target_position=e.global_position`을 추가한다. `ParryFeedbackController.present()`는 다음 helper를 사용한다.

```gdscript
static func feedback_target_position(payload: Dictionary) -> Vector2:
	if payload.has("target_position"):
		return payload["target_position"] as Vector2
	if payload.has("enemy_position"):
		return payload["enemy_position"] as Vector2
	if payload.has("projectile_position"):
		return payload["projectile_position"] as Vector2
	return payload.get("player_position", Vector2.ZERO) as Vector2
```

- [ ] **Step 4: unit runner와 parry feedback unit PASS 확인**

Run: Task 1 Step 2.

Expected: Player melee와 ParryFeedbackController tests 모두 0 failed.

- [ ] **Step 5: typed parry payload 커밋**

```bash
git add scripts/player/player.gd scripts/combat/parry_feedback_controller.gd tests/unit/test_player_melee.gd tests/unit/test_parry_feedback_controller.gd
git commit -m "[Combat] 패링 성공 payload에 늑대와 투사체 종류 추가"
```

### Task 3: ParryOnboarding을 target/kind 기반으로 일반화

**Files:**
- Modify: `scripts/ui/parry_onboarding.gd`
- Modify: `tests/unit/test_onboarding_coach_mark.gd`
- Modify: `tests/unit/test_touch_input.gd`

**Interfaces:**
- Consumes: #546 `InputPromptStrip`, target Node2D, input mode, parry kind
- Produces: `show_for_target(target, input_mode, kind) -> bool`, `dismiss_for_target(target)`, `dismiss_for_kind(kind)`, preserved `show_for_wolf()`

- [ ] **Step 1: projectile prompt와 single-active 실패 테스트 작성**

```gdscript
func test_projectile_parry_prompt_uses_aim_then_attack_glyphs() -> void:
	var tutorial := _new_parry_onboarding()
	var projectile := Node2D.new()
	add_child(projectile)
	_runner.assert_true(tutorial.show_for_target(projectile, &"desktop", &"enemy_projectile"))
	var snapshot: Dictionary = tutorial.get_snapshot()
	_runner.assert_eq(snapshot["kind"], &"enemy_projectile")
	_runner.assert_eq(snapshot["input_actions"], [&"aim_hold", &"attack"])
	_runner.assert_eq(snapshot["detail"], "날아오는 공격을 되받아쳐")
	_runner.assert_false(snapshot["blocks_gameplay"])


func test_active_parry_prompt_is_not_replaced_by_other_kind() -> void:
	var tutorial := _new_parry_onboarding()
	var wolf := Node2D.new()
	var projectile := Node2D.new()
	add_child(wolf)
	add_child(projectile)
	_runner.assert_true(tutorial.show_for_wolf(wolf, &"desktop"))
	_runner.assert_false(tutorial.show_for_target(projectile, &"desktop", &"enemy_projectile"))
	_runner.assert_eq(tutorial.get_snapshot()["kind"], &"wolf_dash")
	_runner.assert_false(tutorial.dismiss_for_kind(&"enemy_projectile"), "projectile success cannot dismiss active wolf lesson")
	_runner.assert_true(tutorial.get_snapshot()["active"], "mismatched dismiss keeps current prompt")
	_runner.assert_true(tutorial.dismiss_for_kind(&"wolf_dash"), "matching kind dismisses its own prompt")


func _new_parry_onboarding() -> ParryOnboarding:
	var tutorial := (load("res://scripts/ui/parry_onboarding.gd") as Script).new() as ParryOnboarding
	add_child(tutorial)
	return tutorial
```

Touch projectile prompt는 `key_label="공격 버튼"`, empty input_actions를 단정한다.

- [ ] **Step 2: unit runner에서 new API FAIL 확인**

Run: Task 1 Step 2.

- [ ] **Step 3: target/kind model과 wolf adapter 구현**

```gdscript
func show_for_wolf(wolf: Node2D, input_mode: StringName) -> bool:
	return show_for_target(wolf, input_mode, &"wolf_dash")


func show_for_target(target: Node2D, input_mode: StringName, kind: StringName) -> bool:
	if _active or target == null or not is_instance_valid(target):
		return false
	_target = target
	_kind = kind
	_input_mode = InputPromptPolicy.MODE_TOUCH if input_mode == InputPromptPolicy.MODE_TOUCH else InputPromptPolicy.MODE_DESKTOP
	_active = true
	_coach.show_prompt(_prompt_model_for(kind, _input_mode, target))
	return true


func dismiss_for_kind(kind: StringName) -> bool:
	if not _active or _kind != kind:
		return false
	return dismiss()
```

`_prompt_model_for()`는 wolf desktop `[&"attack"]`, projectile desktop `[&"aim_hold", &"attack"]`, touch key label을 반환한다. 기존 `dismiss_for_wolf()`는 `dismiss_for_target()` adapter로 유지한다. snapshot은 kind/input_actions를 포함한다.

- [ ] **Step 4: unit runner PASS 확인**

Run: Task 1 Step 2.

- [ ] **Step 5: generalized coach commit**

```bash
git add scripts/ui/parry_onboarding.gd tests/unit/test_onboarding_coach_mark.gd tests/unit/test_touch_input.gd
git commit -m "[UI] 패링 안내를 늑대와 투사체 공통 타깃으로 일반화"
```

### Task 4: SessionRoot 종류별 lifecycle과 독립 flag 연결

**Files:**
- Modify: `scripts/autoload/scene_transition.gd:1-20`
- Modify: `scripts/session/session_root.gd:1180-1320`
- Modify: `tests/integration/test_session_contract.gd:370-535`
- Modify: `tests/integration/test_session_contract.gd:930-1020`

**Interfaces:**
- Consumes: `CombatRoom.enemy_spawned`, `RangedShooter.projectile_spawned`, typed `parry_succeeded`
- Produces: independent wolf/ranged eligibility, flags, cleanup

- [ ] **Step 1: miss→retry→success→independent flag integration 테스트 작성**

```gdscript
func test_ranged_parry_tutorial_retries_and_completes_only_on_actual_deflect() -> void:
	var session := _new_regular_session_with_awakened_bat()
	var ranged := _spawn_ranged_enemy_in_current_room(session)
	var actor := session.get_node("%Player") as Node2D
	var first := _spawn_enemy_bullet(ranged, actor.global_position + Vector2(40.0, 0.0))
	_runner.assert_eq(session.get_parry_tutorial_snapshot()["kind"], &"enemy_projectile")
	first.queue_free()
	await get_tree().process_frame
	_runner.assert_false(SaveManager.get_flag(SceneTransition.FLAG_RANGED_PARRY_TUTORIAL_COMPLETE))
	var second := _spawn_enemy_bullet(ranged, actor.global_position + Vector2(40.0, 0.0))
	_runner.assert_eq(session.get_parry_tutorial_snapshot()["target_name"], second.name)
	actor.call("_attack_melee", (second.global_position - actor.global_position).normalized())
	_runner.assert_true(SaveManager.get_flag(SceneTransition.FLAG_RANGED_PARRY_TUTORIAL_COMPLETE))
	_runner.assert_false(SaveManager.get_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE), "projectile success does not complete wolf lesson")


func _new_regular_session_with_awakened_bat() -> Node:
	GameManager.start_session({
		"source": "ranged_parry_integration",
		SceneTransition.RUN_CONFIG_SELECTED_WEAPON_ID: &"bat",
	})
	var session := (load("res://scenes/session/session_root.tscn") as PackedScene).instantiate()
	add_child(session)
	var actor := session.get_node("%Player")
	actor.call("equip_bat")
	actor.call("set_bat_awakened", true)
	return session


func _spawn_ranged_enemy_in_current_room(session: Node) -> Node2D:
	var manager := session.get_node("%RoomManager") as RoomManager
	var combat_def := _first_room_of_type(manager.layout, RoomLayout.TYPE_COMBAT)
	manager.enter_room(combat_def.room_id)
	var room := manager.current_room
	var ranged := (load("res://scenes/enemies/ranged_shooter.tscn") as PackedScene).instantiate() as Node2D
	room.add_child(ranged)
	room.emit_signal("enemy_spawned", ranged, &"ranged", 0)
	return ranged


func _spawn_enemy_bullet(ranged: Node, origin: Vector2) -> Node2D:
	var spawned: Array[Node2D] = []
	ranged.connect(&"projectile_spawned", func(projectile: Node2D) -> void: spawned.append(projectile), CONNECT_ONE_SHOT)
	ranged.call("_spawn_bullet", origin, Vector2.LEFT)
	return spawned[0]
```

별도 테스트는 unawakened bat에서 prompt 0, prompt 미완료 room clear 가능, death/retry/exit 후 ranged/projectile signal 0을 단정한다. mixed room 테스트는 active wolf prompt 상태에서 `kind=enemy_projectile` 성공 payload를 처리해도 snapshot kind가 `wolf_dash`, active=true로 남는지 검증한다.

역순 mixed room 테스트는 active projectile prompt 중 같은 wolf의 첫 `prepare`가 거절된 뒤 prompt를 닫고 두 번째 `prepare`를 보내 wolf prompt가 실제로 표시되는지 검증한다. 이 테스트는 rejected prompt가 `_prompted_parry_wolf_ids`에 기록되는 회귀를 잡는다.

- [ ] **Step 2: integration runner에서 ranged lifecycle FAIL 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 \
  bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
```

- [ ] **Step 3: flag와 종류별 eligibility 추가**

```gdscript
# scene_transition.gd
const FLAG_RANGED_PARRY_TUTORIAL_COMPLETE := &"ranged_parry_tutorial_complete"
```

```gdscript
func _is_ranged_parry_tutorial_eligible() -> bool:
	return (
		has_node("/root/SaveManager")
		and actor != null
		and actor.has_method("is_bat_awakened")
		and bool(actor.call("is_bat_awakened"))
		and not SaveManager.get_flag(SceneTransition.FLAG_RANGED_PARRY_TUTORIAL_COMPLETE)
	)
```

`_on_parry_enemy_spawned()`는 wolf와 ranged를 분기한다. ranged enemy는 `projectile_spawned`와 tree exit를 연결한다. `_on_ranged_projectile_spawned(projectile)`는 eligibility와 active prompt를 확인한 뒤 `show_for_target()`을 호출하고 projectile tree exit에서 target prompt만 dismiss한다.

wolf ID는 prompt가 수락된 뒤에만 소비한다.

```gdscript
func _on_wolf_dash_state_changed(state: StringName, wolf: Node2D) -> void:
	if state != &"prepare" or not _is_wolf_parry_tutorial_eligible():
		return
	var wolf_id := wolf.get_instance_id()
	if _prompted_parry_wolf_ids.has(wolf_id):
		return
	if parry_onboarding.show_for_wolf(wolf, _onboarding_journey_input_mode()):
		_prompted_parry_wolf_ids[wolf_id] = true
```

- [ ] **Step 4: typed success handler와 cleanup 구현**

```gdscript
func _on_player_parry_succeeded(payload: Dictionary) -> void:
	match StringName(payload.get("kind", &"")):
		&"wolf_dash":
			if _is_wolf_parry_tutorial_eligible():
				SaveManager.set_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE, true)
		&"enemy_projectile":
			if _is_ranged_parry_tutorial_eligible():
				SaveManager.set_flag(SceneTransition.FLAG_RANGED_PARRY_TUTORIAL_COMPLETE, true)
				parry_onboarding.dismiss_for_kind(&"enemy_projectile")
	_refresh_parry_room_connections()
```

`_refresh_parry_room_connections()`는 둘 다 완료됐을 때만 전체 room/enemy signal을 끊는다. 한 종류 성공이 다른 종류 학습 signal을 제거하지 않는다. 기존 `_finish_all_onboarding_ui()`와 room change cleanup은 wolf/ranged/projectile arrays를 모두 정리한다.

- [ ] **Step 5: unit/integration/full PASS 확인**

```bash
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
GODOT_BIN=/opt/homebrew/bin/godot PYTHON_BIN=/opt/homebrew/bin/python3.12 bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

- [ ] **Step 6: coordinator 커밋**

```bash
git add scripts/autoload/scene_transition.gd scripts/session/session_root.gd tests/integration/test_session_contract.gd
git commit -m "[Combat] 원거리 패링 반복 학습과 독립 완료 상태 연결"
```

### Task 5: Release Web fixture·증거·merge

**Files:**
- Create: `tests/uat/ranged_parry_web_fixture.gd`
- Create: `tests/uat/ranged_parry_web_fixture.gd.uid`
- Create: `tests/uat/ranged_parry_web_fixture.tscn`
- Modify: `tests/uat/README.md`
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`

**Interfaces:**
- Consumes: modes `desktop_prompt`, `touch_prompt`, `miss`, `retry`, `success`, `completed_hidden`, `teardown`
- Produces: `UAT_RANGED_PARRY_READY` markers와 screenshots

- [ ] **Step 1: production scene 기반 fixture 작성**

```gdscript
print("UAT_RANGED_PARRY_READY mode=%s prompt=%s kind=%s actions=%s reflected=%d wolf_complete=%s ranged_complete=%s room_clear=%s connections=%d valid=%s" % [
	_mode,
	str(snapshot["active"]).to_lower(),
	String(snapshot.get("kind", &"")),
	str(snapshot.get("input_actions", [])),
	_reflected_count,
	str(SaveManager.get_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE)).to_lower(),
	str(SaveManager.get_flag(SceneTransition.FLAG_RANGED_PARRY_TUTORIAL_COMPLETE)).to_lower(),
	str(_room_cleared).to_lower(),
	_connection_count,
	str(valid).to_lower(),
])
```

`success`는 real awakened Player의 actual `_attack_melee()`로 real EnemyBullet을 반사한다. `teardown`은 room/session exit 뒤 connection_count=0, prompt=false를 요구한다.

- [ ] **Step 2: full gate 실행**

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_full.sh
```

- [ ] **Step 3: headed Chromium WebGL2 7-mode 검증**

각 mode는 `valid=true`, console/page/request error 0. `miss`와 `retry`는 ranged flag false, `success`는 ranged true/wolf false, `completed_hidden`은 prompt false, `teardown`은 connections 0이어야 한다.

- [ ] **Step 4: 960×540 PC/touch/success 캡처**

```text
ranged-parry-prompt-pc-960x540.png
ranged-parry-prompt-touch-960x540.png
ranged-parry-success-960x540.png
```

- [ ] **Step 5: fixture·장부 커밋**

```bash
git add tests/uat/ranged_parry_web_fixture.gd tests/uat/ranged_parry_web_fixture.gd.uid tests/uat/ranged_parry_web_fixture.tscn tests/uat/README.md docs/requirements/2026-08-22-improvement-coverage.md
git commit -m "[QA] 원거리 투사체 패링 학습 Web 증거 추가"
```

- [ ] **Step 6: ready PR과 merge loop 완료**

PR title: `[Combat] 원거리 투사체 패링 학습 연결`

PR body에 7-mode markers, exact tests, three inline screenshots, `Closes #549`를 넣는다. current-head Codex·CI green·unresolved 0이면 즉시 merge한다.
