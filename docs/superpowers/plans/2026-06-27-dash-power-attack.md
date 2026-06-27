# Dash Power Attack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 대시 중/직후 공격을 강화 근접 공격으로 바꾸고 전용 타격 이펙트를 표시한다.

**Architecture:** `scripts/player/player.gd` 안에 대시 강공격 창 상태와 순수 판정 함수를 추가한다. 기존 `_attack_melee()`의 피해/사거리/넉백 산출만 강화하고, `scenes/player/player.tscn`에 `PowerImpact` 폴리곤 노드를 추가해 기존 스윙 이펙트와 같은 갱신 루프에서 숨긴다.

**Tech Stack:** Godot 4.6 GDScript, 기존 플레이어 단위 테스트, `verify_quick.sh`.

---

### Task 1: 강공격 창 수학과 피해

**Files:**
- Modify: `tests/unit/test_player_special_skill.gd`
- Modify: `tests/unit/test_player_melee.gd`
- Modify: `scripts/player/player.gd`

- [ ] **Step 1: Write failing tests**

Add tests for `is_dash_power_attack_window_active()` and `_debug_enable_dash_power_attack_window()`, then assert that a dash power melee attack deals `melee_damage + dash_power_attack_damage_bonus`.

- [ ] **Step 2: Verify RED**

Run: `PYTHON_BIN=/opt/homebrew/bin/python3 GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/verify_quick.sh`

Expected: unit tests fail because the new methods/properties do not exist yet.

- [ ] **Step 3: Implement minimal player logic**

Add exported tuning values, a `_dash_power_attack_timer`, a pure window helper, and consume the window inside `_attack_melee()` when it is active.

- [ ] **Step 4: Verify GREEN**

Run the same quick gate and confirm the new unit tests pass.

### Task 2: 강화 넉백과 타격 이펙트

**Files:**
- Modify: `tests/unit/test_player_melee.gd`
- Modify: `scenes/player/player.tscn`
- Modify: `scripts/player/player.gd`

- [ ] **Step 1: Write failing tests**

Add tests that a bat dash power attack knocks farther than a normal bat attack, and that `player.tscn` includes a hidden `PowerImpact` `Polygon2D`.

- [ ] **Step 2: Verify RED**

Run: `PYTHON_BIN=/opt/homebrew/bin/python3 GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/verify_quick.sh`

Expected: the effect-node test fails before `PowerImpact` exists.

- [ ] **Step 3: Implement visual and knockback**

Add `PowerImpact` to the scene, cache it in player script, display it only for power attacks, and hide it with the swing timer.

- [ ] **Step 4: Verify GREEN and smoke**

Run `verify_quick.sh`, then:

`HOME="$PWD/test-results/godot-user-home-player-129" "$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 200 res://scenes/player/player.tscn`

Expected: no `SCRIPT ERROR`.
