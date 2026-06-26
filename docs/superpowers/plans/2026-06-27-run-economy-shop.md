# Run Economy Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close issue #84 by making ingame currency earnable during combat, visible in the HUD, and spendable in one shop room placed into the generated night-run map.

**Architecture:** Keep economy events on the existing `EventBus.currency_changed` contract so `CurrencySystem` remains the single balance authority. Add `ShopRoom` as a `Room` subclass with two fixed offers that apply existing player upgrade methods, and let the generated layout assign exactly one visible `shop` room.

**Tech Stack:** Godot 4.6 GDScript resources/scenes, existing autoloads (`EventBus`, `CurrencySystem`), existing room manager/layout contracts, repository unit/integration runners.

---

### Task 1: Combat Earn Sources

**Files:**
- Modify: `tests/unit/test_combat_room.gd`
- Modify: `scripts/interactables/combat_room.gd`

- [ ] **Step 1: Write the failing test**

Add `test_combat_room_emits_ingame_rewards_for_enemy_defeats_and_clear()` to `tests/unit/test_combat_room.gd`. Reset `CurrencySystem`, instantiate `combat_room.tscn`, enter it, defeat all spawned enemies, and assert `CurrencySystem.get_ingame() == 6` with the default 3 enemies and clear bonus.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: the new combat room reward test fails because combat does not emit ingame currency yet.

- [ ] **Step 3: Write minimal implementation**

In `scripts/interactables/combat_room.gd`, add exported reward amounts:

```gdscript
@export_range(0, 99, 1) var enemy_defeat_ingame_reward := 1
@export_range(0, 99, 1) var combat_clear_ingame_reward := 3
```

Emit `EventBus.emit_currency_changed({"kind": "ingame", "amount": amount, "reason": reason, "room_id": room_id, "room_type": room_type})` once per enemy defeat and once on combat resolve.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: all unit tests pass.

### Task 2: Shop Room

**Files:**
- Create: `scripts/interactables/shop_room.gd`
- Create: `scenes/interactables/shop_room.tscn`
- Modify: `tests/integration/test_special_room_contract.gd`

- [ ] **Step 1: Write the failing tests**

Add tests that instantiate `shop_room.tscn`, give ingame currency via `EventBus.emit_currency_changed`, purchase `bat` and `dodge_refill`, and assert:
- `bat` spends its cost and calls the player's existing `equip_bat()`.
- `dodge_refill` spends its cost and calls the player's existing `equip_special_skill()` with stronger emergency dodge values.
- insufficient currency leaves the offer unsold and the ingame balance unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: tests fail because `shop_room.tscn` does not exist.

- [ ] **Step 3: Write minimal implementation**

Create `ShopRoom` as a `Room` subclass. It should clear itself on entry so doors open, stay in the `interactable` group for purchases, expose `purchase_offer(offer_id, buyer)`, spend ingame currency through `EventBus.emit_currency_changed({"kind": "ingame", "amount": -cost, ...})`, apply `equip_bat()` or `equip_special_skill(&"emergency_dodge", 5, 1.0)` on the buyer, mark offers sold, and update simple in-room labels.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: all integration tests pass.

### Task 3: HUD Currency Display

**Files:**
- Modify: `tests/unit/test_combat_hud.gd`
- Modify: `scripts/ui/combat_hud.gd`
- Modify: `scenes/ui/combat_hud.tscn` only if label sizing needs adjustment

- [ ] **Step 1: Write the failing tests**

Add tests that call `set_currency_state({"ingame": 7})` and emit a processed `EventBus.currency_changed` payload with `{"kind": "ingame", "ingame": 3}`. Assert `get_currency_text()` contains the current ingame balance.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: tests fail because the HUD has no public currency setter/getter and does not subscribe to currency updates.

- [ ] **Step 3: Write minimal implementation**

Add `set_currency_state(payload)`, `get_currency_text()`, connect `EventBus.currency_changed`, initialize from `CurrencySystem.get_ingame()` when available, and render compact Korean copy like `엽전: 7`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: all unit tests pass.

### Task 4: Generated Layout Shop Placement

**Files:**
- Modify: `tests/unit/test_room_layout_generator.gd`
- Modify: `tests/integration/test_room_manager_contract.gd`
- Modify: `scripts/systems/room_layout_generator.gd`
- Modify: `scripts/session/session_root.gd`

- [ ] **Step 1: Write the failing tests**

Update layout generator invariants to require exactly one `RoomLayout.TYPE_SHOP`, `expected_count - 4` combat rooms, and a non-empty shop scene path. Update session root integration to assert generated run layout contains one shop room mounted from `res://scenes/interactables/shop_room.tscn`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn` and `bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`.

Expected: tests fail because generated layouts still contain only start/event/final/combat room types.

- [ ] **Step 3: Write minimal implementation**

Add `shop_scene_path` to `RoomLayoutGenerator`, pick one shop index excluding start/final/event, assign `shop_1`, return `RoomLayout.TYPE_SHOP`, route scene path for shop, and set `SessionRoot`'s run generator to `res://scenes/interactables/shop_room.tscn`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn` and `bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`.

Expected: all unit and integration tests pass.

### Task 5: Final Verification and Shipping

**Files:**
- All changed files

- [ ] **Step 1: Run quick gate**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" PYTHON_BIN=/opt/homebrew/bin/python3 bash scripts/verify_quick.sh`

Expected: quick gate passes. If `.gd.uid` files are generated, add them and rerun the quick gate.

- [ ] **Step 2: Run session smoke**

Run: `HOME="$PWD/test-results/godot-user-home" "$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 200 res://scenes/session/session_root.tscn > test-results/session-root-smoke-84.log 2>&1 && /opt/homebrew/bin/python3 scripts/verify_godot_output.py test-results/session-root-smoke-84.log`

Expected: smoke log has no script errors.

- [ ] **Step 3: Commit and open PR**

Commit with Korean message and `Co-Authored-By:` trailer. Push with personal token/SSH remote only, create a ready PR against `main` with `Closes #84`, labels `P2`, `area:events`, `area:night-run`, `area:meta`, and drive CI/review to merge.
