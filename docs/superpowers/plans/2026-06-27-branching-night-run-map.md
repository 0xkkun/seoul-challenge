# Branching Night Run Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the in-game night run on a 15-room branching map with meaningful alternate routes and a boss reveal condition that does not require clearing every non-boss room.

**Architecture:** Keep `RoomLayout` as the route contract and extend it with a numeric reveal threshold. Replace the current organic-only generator behavior with a critical-path-first layout that grows branches and keeps enough junctions while preserving adjacency and bidirectional connections. `session_root` should instantiate the generated run layout with real room scenes instead of preloading the authored five-room line.

**Tech Stack:** Godot 4.6 GDScript resources/scenes, existing custom test runner, `scripts/verify_quick.sh`.

---

### Task 1: Generator Shape Contract

**Files:**
- Modify: `tests/unit/test_room_layout_generator.gd`
- Modify: `scripts/systems/room_layout_generator.gd`

- [ ] **Step 1: Write the failing tests**

Add tests that assert generated 15-room runs have at least two junctions, a start-to-boss shortest path of at least six edges, and at least one loop/alternate edge.

- [ ] **Step 2: Run unit tests to verify failure**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: the new generator-shape test fails because the current generator can create tree-only layouts.

- [ ] **Step 3: Implement critical-path-first generation**

Use a deterministic random walk to build a minimum-length path from start to final, then attach side branches from path nodes until `room_count` is reached. Add a deterministic extra-edge pass by allowing adjacent occupied cells to connect even if they were not parent/child, preserving grid adjacency.

- [ ] **Step 4: Run unit tests to verify pass**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn`

Expected: all unit tests pass.

### Task 2: Boss Reveal Threshold

**Files:**
- Modify: `scripts/systems/room_layout.gd`
- Modify: `tests/unit/test_room_layout_generator.gd`
- Modify: `tests/integration/test_room_manager_contract.gd`

- [ ] **Step 1: Write the failing tests**

Add tests that a generated 15-room layout reveals the hidden final room before every non-final room is cleared, while still keeping it hidden at start.

- [ ] **Step 2: Run tests to verify failure**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn && GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: reveal remains tied to clearing all non-hidden rooms.

- [ ] **Step 3: Implement reveal threshold**

Add `@export var required_clears_for_hidden_reveal := 0` to `RoomLayout`. Make `can_reveal_hidden_rooms()` use the explicit threshold when greater than zero. Set generated 15-room layouts to `ceil(non_final_count * 0.65)`, with a minimum of 4 and maximum `non_final_count - 1` when possible.

- [ ] **Step 4: Run tests to verify pass**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn && GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: all unit and integration tests pass.

### Task 3: In-Game Generated Layout

**Files:**
- Modify: `scripts/session/session_root.gd`
- Modify: `tests/integration/test_room_manager_contract.gd`
- Modify: `tests/integration/test_run_flow.gd`

- [ ] **Step 1: Write the failing tests**

Update session/root and run-flow tests to expect a generated 15-room layout, branching connections, and real room scenes for start/combat/event/final rooms.

- [ ] **Step 2: Run integration tests to verify failure**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: session still starts the authored five-room layout.

- [ ] **Step 3: Wire generated layout into session_root**

Create a small `_build_run_layout()` helper in `session_root.gd` that constructs `RoomLayoutGenerator`, sets `seed`, `room_count`, and `scene_paths`, then passes the generated layout to `room_manager.configure()`.

- [ ] **Step 4: Run integration tests to verify pass**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" bash scripts/godot_headless.sh res://tests/integration/integration_runner.tscn`

Expected: integration tests pass.

### Task 4: Verification and Ship Prep

**Files:**
- Inspect: all changed files

- [ ] **Step 1: Run quick gate**

Run: `GODOT_BIN="$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" PYTHON_BIN=/opt/homebrew/bin/python3 bash scripts/verify_quick.sh`

Expected: quick gate passes.

- [ ] **Step 2: Run headless smoke**

Run: `HOME="$PWD/test-results/godot-user-home" "$HOME/personal/godot/Godot.app/Contents/MacOS/Godot" --headless --path . --quit-after 200 res://scenes/session/session_root.tscn`

Expected: no `SCRIPT ERROR`.

- [ ] **Step 3: Inspect diff and commit**

Run: `git diff --stat && git status --short`

Commit message: `[Scene] 분기형 런 맵 생성과 보스 경로 확장`

Include `Closes #85` in the PR body.
