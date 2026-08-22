# First Five Minutes Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved first-five-minutes program so the intro never hard-blocks on a click, platform copy matches the active controls, the first journey is success-driven, parry is taught and celebrated, and the highest-priority missing requirements are implemented with traceable evidence.

**Architecture:** Execute twelve ordered implementation slices followed by one fresh-main verification slice. Every implementation slice starts from the previous slice's merged `origin/main`, owns one GitHub issue/worktree/ready PR, and reaches CI + Codex + Web UAT before the next slice begins. Existing scene-local controllers remain responsible for their domains; shared policy is introduced only for platform copy, hit stop, and reusable combat text.

**Tech Stack:** Godot `4.6.3.stable.official.7d41c59c4`, GDScript, custom unit/integration runners, headed Chromium WebGL2 UAT, GitHub Actions/`gh`.

**Spec:** `docs/superpowers/specs/2026-08-22-first-five-minutes-onboarding-design.md`

## Global Constraints

- PC controls are `left click=attack`, `SPACE=dash`, `E=talk`; `SHIFT` remains an unadvertised secondary dash.
- Native mobile and mobile Web retain the current virtual joystick, attack button, and dash button contracts.
- Use `mobile`, `web_android`, and `web_ios` feature tags for default touch copy; do not classify by touchscreen availability alone.
- Main scene remains `res://scenes/lobby/lobby.tscn`; dev scene remains `res://scenes/dev/main_dev.tscn`.
- Keep `input_devices/pointing/emulate_mouse_from_touch=true` and the Android debug UAT bridge contract intact.
- Do not add mouse aiming, key rebinding, a separate tutorial arena, or a new global onboarding autoload.
- Every production edit follows RED → GREEN → refactor; watch the new test fail for the intended reason before implementation.
- Every code task creates and assigns a GitHub issue, stores the returned integer as `ISSUE_NUMBER`, then creates `../seoul-challenge-$ISSUE_NUMBER` from latest `origin/main`.
- PR/commit text is Korean except the English `[Area]` tag. Set assignee, milestone, priority, and `area:*` labels.
- Run `bash scripts/verify_quick.sh` before every PR update and `bash scripts/verify_full.sh` for broad combat/session changes.
- UI-visible PRs store the actual pull-request integer as `PR_NUMBER`, publish `ui-previews/pr-$PR_NUMBER/...` raw screenshots, and satisfy `scripts/verify_pr_ui_capture.py`.
- Merge only after current-head CI is green, Codex has no outstanding request, and all review threads are answered and resolved.
- After each merge, update `docs/requirements/2026-08-22-improvement-coverage.md` with the issue, merge commit, tests, and UAT evidence.

## Dependency Order

```text
Task 1 intro/prompt policy
  → Task 2 first-room success flow
  → Task 3 first-run contextual journey
  → Task 4 parry success event/tutorial
  → Task 5 parry feedback primitives
  → Task 6 portal/onboarding cleanup
  → Task 7 real waves
  → Task 8 chaser pressure
  → Task 9 combat SFX foundation
  → Task 10 damage vignette
  → Task 11 general hit stop
  → Task 12 damage numbers
  → Task 13 fresh-main verification
```

Tasks 7 and 8 both affect difficulty. Do not combine them; play and merge Task 7 before measuring Task 8.

---

### Task 1: Intro Auto-Advance and Platform Prompt Policy

**Issue contract:** `[UI] 인트로 자동 진행과 플랫폼별 계속 안내` with `P0`, `area:ui`.

**Files:**
- Create: `scripts/ui/input_prompt_policy.gd`
- Modify: `scripts/autoload/platform_manager.gd`
- Modify: `scripts/cutscene/night_intro_cutscene.gd`
- Modify: `scripts/ui/hub_dialogue_ui.gd`
- Modify: `scripts/ui/purify_onboarding_spotlight.gd`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/dev/day_corridor_movement_test.gd`
- Test: `tests/unit/test_night_intro_cutscene.gd`
- Test: `tests/unit/test_hub_dialogue_ui.gd`
- Test: `tests/unit/test_purify_onboarding_spotlight.gd`
- Test: `tests/integration/test_day_corridor_movement_test.gd`
- Test: `tests/unit/test_boss_intro_gating.gd`

**Interfaces:**
- Produces: `InputPromptPolicy.input_mode_from_features(features: Dictionary) -> StringName`.
- Produces: `InputPromptPolicy.continue_hint(input_mode: StringName) -> String`.
- Produces: `InputPromptPolicy.action_hint(action: StringName, input_mode: StringName) -> String`.
- Produces: `NightIntroCutscene.should_advance_line(narration_started: bool, narration_playing: bool, line_elapsed: float, narration_finished_elapsed: float, user_requested: bool) -> bool`.
- Preserves: `NightIntroCutscene.finished`, `skip()`, `HubDialogueUi` choice ids and UAT metadata.

- [ ] **Step 1: Create the platform-copy RED tests**

Add to `tests/unit/test_hub_dialogue_ui.gd`:

```gdscript
func test_continue_hint_matches_active_input_mode() -> void:
	var policy := load("res://scripts/ui/input_prompt_policy.gd")
	_runner.assert_eq(policy.continue_hint(&"desktop"), "클릭하여 계속", "PC는 클릭 표현을 쓴다")
	_runner.assert_eq(policy.continue_hint(&"touch"), "탭하여 계속", "터치는 탭 표현을 쓴다")
	_runner.assert_eq(policy.action_hint(&"start", &"desktop"), "클릭하여 시작", "PC 시작 안내도 클릭 표현을 쓴다")
	_runner.assert_eq(policy.action_hint(&"start", &"touch"), "탭하여 시작", "터치 시작 안내는 탭 표현을 쓴다")
	_runner.assert_eq(
		policy.input_mode_from_features({"web": true, "web_android": false, "web_ios": false, "mobile": false, "touch_input": true}),
		&"desktop",
		"마우스 터치 에뮬레이션은 PC를 모바일로 오분류하지 않는다"
	)
	_runner.assert_eq(policy.input_mode_from_features({"web_ios": true}), &"touch", "모바일 Web은 touch 문구를 쓴다")
```

- [ ] **Step 2: Run unit tests and confirm RED**

Run:

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot \
  bash scripts/godot_headless.sh res://tests/unit/test_runner.tscn
```

Expected: `test_continue_hint_matches_active_input_mode` fails because `input_prompt_policy.gd` does not exist.

- [ ] **Step 3: Implement `InputPromptPolicy` and platform flags**

Create `scripts/ui/input_prompt_policy.gd`:

```gdscript
class_name InputPromptPolicy
extends RefCounted

const MODE_DESKTOP := &"desktop"
const MODE_TOUCH := &"touch"

static func input_mode_from_features(features: Dictionary) -> StringName:
	return MODE_TOUCH if (
		bool(features.get("mobile", false))
		or bool(features.get("web_android", false))
		or bool(features.get("web_ios", false))
	) else MODE_DESKTOP

static func continue_hint(input_mode: StringName) -> String:
	return action_hint(&"continue", input_mode)

static func action_hint(action: StringName, input_mode: StringName) -> String:
	var gesture := "탭하여" if input_mode == MODE_TOUCH else "클릭하여"
	var verb := "시작" if action == &"start" else "계속"
	return "%s %s" % [gesture, verb]
```

Extend `PlatformManager.get_feature_flags()` with literal `web_android` and `web_ios` entries. Do not change `has_touch_input()` semantics in this slice.

- [ ] **Step 4: Add the intro-timing RED tests**

Add to `tests/unit/test_night_intro_cutscene.gd`:

```gdscript
func test_intro_line_auto_advance_covers_audio_and_web_fallbacks() -> void:
	_runner.assert_false(NightIntroCutsceneScript.should_advance_line(true, true, 1.0, 0.0, true), "early click buffers while narration plays")
	_runner.assert_true(NightIntroCutsceneScript.should_advance_line(true, false, 2.0, 0.35, false), "voiced line auto advances after narration grace")
	_runner.assert_true(NightIntroCutsceneScript.should_advance_line(false, false, 2.2, 0.0, false), "autoplay-blocked line advances by reading fallback")
	_runner.assert_true(NightIntroCutsceneScript.should_advance_line(true, true, 4.0, 0.0, false), "stuck narration cannot soft-lock intro")
```

- [ ] **Step 5: Run unit tests and confirm timing RED**

Run the unit runner. Expected: failure because `should_advance_line` is absent.

- [ ] **Step 6: Implement bounded intro scheduling**

Add constants to `NightIntroCutscene`:

```gdscript
const AUTO_ADVANCE_AFTER_NARRATION_SECONDS := 0.35
const VOICELESS_READING_SECONDS := 2.2
const HARD_MAX_LINE_SECONDS := 4.0
```

Implement `should_advance_line` exactly as:

```gdscript
static func should_advance_line(
	narration_started: bool,
	narration_playing: bool,
	line_elapsed: float,
	narration_finished_elapsed: float,
	user_requested: bool
) -> bool:
	if line_elapsed >= HARD_MAX_LINE_SECONDS:
		return true
	if not narration_started:
		return user_requested or line_elapsed >= VOICELESS_READING_SECONDS
	if narration_playing:
		return false
	return user_requested or narration_finished_elapsed >= AUTO_ADVANCE_AFTER_NARRATION_SECONDS
```

Refactor `_wait_for_advance()` to track real line elapsed and post-narration elapsed. Keep early user input buffered. Shorten plate/subtitle transition constants enough that the measured `14.88s` narration set completes below 30 seconds in the normal path. Set the plate to a nonzero initial alpha before its first tween so the canvas is never only black for longer than one second.

- [ ] **Step 7: Replace every runtime continue hint**

Use `InputPromptPolicy.continue_hint(InputPromptPolicy.input_mode_from_features(PlatformManager.get_feature_flags()))` in:

- `NightIntroCutscene._build_ui()`
- `HubDialogueUi` unlock hint
- `PurifyOnboardingSpotlight` intro/continue hint
- `SessionRoot._set_encounter_beat()`
- `DayCorridor` dialogue choice construction

Keep the existing choice ids, `tap_to_continue` boolean, `test_id`, and `uat_action` contracts unchanged; only player-facing copy changes.

- [ ] **Step 8: Update copy consumers' tests**

Update desktop integration expectations to `클릭하여 계속`; add a mobile
feature fixture expecting `탭하여 계속`. In the real
`PurifyOnboardingSpotlight`, assert desktop renders `클릭하여 시작/계속` and
touch renders `탭하여 시작/계속`. Test the value returned by the policy and the
rendered Control text rather than grepping source text.

- [ ] **Step 9: Verify GREEN and run the quick gate**

Run the unit runner, integration runner, then:

```bash
PYTHON_BIN=/opt/homebrew/bin/python3.12 GODOT_BIN=/opt/homebrew/bin/godot bash scripts/verify_quick.sh
```

Expected: all tests pass with no `SCRIPT ERROR` or failure markers.

- [ ] **Step 10: Run PC and mobile release Web UAT**

Export release Web and serve it locally. In fresh browser contexts verify:

- PC 960x540 and 1920x900 display `클릭하여 계속`.
- Mobile Web 960x540 displays `탭하여 계속`.
- No input: normal and autoplay-blocked fixtures reach the lobby/session within 30 seconds.
- A stuck-audio fixture reaches the lobby/session within 45 seconds.
- No fully black frame persists longer than 1.5 seconds.
- `WebGL2=true` and console/page/request errors are empty.

- [ ] **Step 11: Commit, open the ready PR, and merge**

Commit message: `[UI] 인트로 자동 진행과 계속 안내 분기`.

Publish PC/mobile screenshots under `ui-previews/pr-$PR_NUMBER/`, set metadata, request `@codex review`, resolve all comments, and merge after current-head checks are green. Update the Q1 coverage rows with the merge SHA.

---

### Task 2: Success-Driven First-Room Controls and Minimap

**Issue contract:** `[UI] 첫 방 성공 기반 조작 온보딩` with `P0`, `area:ui`, `area:player`.

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `scripts/ui/ingame_control_onboarding.gd`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/interactables/start_room.gd`
- Modify: `scripts/systems/room.gd`
- Test: `tests/unit/test_player_aim_fire.gd`
- Test: `tests/unit/test_touch_input.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Produces: `Player.attack_executed(payload: Dictionary)`.
- Produces: `Player.dash_started(payload: Dictionary)`.
- Produces: `SessionRoot.minimap_expanded_changed(expanded: bool)`.
- Produces: `IngameControlOnboarding.gate_released`, `completed`, and `skipped`.
- Produces: a visible `안내 건너뛰기` button after 5.0 active seconds with
  `test_id=onboarding.skip_guidance_button` and
  `uat_action=onboarding.skip_guidance`.
- Produces: `StartRoom.set_tutorial_gate_active(active: bool)`.

- [ ] **Step 1: Write player action-signal RED tests**

Add to `tests/unit/test_player_aim_fire.gd` and the existing special-skill test file:

```gdscript
func test_successful_attack_and_dash_expose_onboarding_signals() -> void:
	var player := PlayerScript.new()
	_runner.assert_true(player.has_signal("attack_executed"), "attack start has an explicit success signal")
	_runner.assert_true(player.has_signal("dash_started"), "dash start has an explicit success signal")
	player.free()
```

- [ ] **Step 2: Run unit tests and confirm RED**

Expected: both signal assertions fail.

- [ ] **Step 3: Add signals at the successful state transitions**

Declare the two signals in `player.gd`. Emit `attack_executed` only after `_try_attack()` commits the attack timer and starts the melee/ranged action. Emit `dash_started` only after `try_start_special_skill()` consumes a charge and sets `_dodge_timer > 0`. Payloads include `direction`, `position`, and the attack/special id.

- [ ] **Step 4: Write the six-step onboarding RED contract**

Update `tests/unit/test_touch_input.gd` to expect:

```gdscript
_runner.assert_eq(
	contract.get("step_ids", []),
	[&"move", &"attack", &"dash", &"power_attack", &"minimap", &"exit"],
	"first room teaches controls, exploration, then exit"
)
```

Add assertions that raw `attack_pressed` and `dash_pressed` dictionaries no longer advance those stages; call explicit `record_action(&"attack_executed")` and `record_action(&"dash_started")` instead. Movement completes only after cumulative displacement reaches 96px.

- [ ] **Step 5: Run unit tests and confirm onboarding RED**

Expected: step list and success-event assertions fail against the four-step raw-input implementation.

- [ ] **Step 6: Refactor `IngameControlOnboarding` to event-driven progression**

Add:

```gdscript
signal completed
signal skipped
signal gate_released

func record_action(action: StringName, payload: Dictionary = {}) -> bool
func record_player_position(position: Vector2) -> bool
func skip_guidance() -> void
```

Connect `attack_executed`, `dash_started`, and `power_attack_executed` from the configured player. Track cumulative absolute displacement between sampled positions. Add platform-specific `minimap` and `exit` copy. Keep touch target lookup for joystick/buttons and accept an explicit minimap `Control` target from `configure()`.

Emit `gate_released` when the minimap step succeeds and the controller enters the exit step. Emit `completed` only after the room transition proves the exit step. `skip_guidance()` emits `gate_released` and `skipped` together, hides step UI, and leaves the compact legend visible.

Build the real `안내 건너뛰기` Button in `IngameControlOnboarding` with
`MOUSE_FILTER_STOP`, mobile safe-area offsets, and the stable metadata above.
Keep it hidden until the onboarding has remained active for
`SKIP_REVEAL_SECONDS := 5.0`, wire `pressed` to `skip_guidance()`, and hide it
again after gate release, completion, or skip. The timer uses process time while
the non-pausing onboarding is active; it is not reset by a failed capability
input.

- [ ] **Step 7: Write start-room gate integration RED tests**

Add to `tests/integration/test_session_contract.gd`:

```gdscript
func test_onboarding_start_room_exit_waits_for_capabilities_or_skip() -> void:
	var session := _instantiate_baseball_onboarding_session()
	var start_room := session.get_node("%RoomManager").current_room as StartRoom
	_runner.assert_false(start_room.is_cleared(), "tutorial gate keeps the start exit closed")
	_complete_control_steps(session)
	_runner.assert_true(start_room.is_cleared(), "completed capabilities open the exit")
	session.queue_free()

func _instantiate_baseball_onboarding_session() -> Node:
	GameManager.start_session({
		SceneTransition.RUN_CONFIG_ONBOARDING_KIND: SceneTransition.ONBOARDING_KIND_BASEBALL_CAPTAIN,
	})
	var session := (load("res://scenes/session/session_root.tscn") as PackedScene).instantiate()
	add_child(session)
	return session

func _complete_control_steps(session: Node) -> void:
	var onboarding := session.get_node("%IngameControlOnboarding")
	var start := session.get_node("%Player").global_position as Vector2
	onboarding.record_player_position(start)
	onboarding.record_player_position(start + Vector2(96.0, 0.0))
	onboarding.record_action(&"attack_executed")
	onboarding.record_action(&"dash_started")
	onboarding.record_action(&"power_attack_executed")
	onboarding.record_action(&"minimap_expanded", {"expanded": true})
```

Add a second fixture that starts onboarding, proves the real skip button remains
hidden at 4.9 seconds and is visible at 5.0 seconds, then presses it by
`test_id`/`uat_action` through the in-process UAT dispatcher. Assert the exit
opens, `skipped` emits once, and the compact key legend remains visible. Direct
method invocation alone is not sufficient evidence for the player escape path.

- [ ] **Step 8: Implement the start-room gate and minimap event**

Add to `StartRoom`:

```gdscript
var _tutorial_gate_active := false

func set_tutorial_gate_active(active: bool) -> void:
	_tutorial_gate_active = active
	if active:
		_cleared = false
		_apply_door_state()
	else:
		mark_cleared()

func is_cleared() -> bool:
	return not _tutorial_gate_active
```

In `SessionRoot._on_room_changed`, activate the gate before `Room.enter()`
finishes when the room is the onboarding start. Unlock it once on onboarding
`gate_released`; `skip_guidance()` emits that same signal, so a second `skipped`
unlock path is unnecessary. Waiting for `completed` would deadlock because
completion requires crossing that door. Emit `minimap_expanded_changed` exactly
when `_minimap_full` changes and feed it to the onboarding controller.

- [ ] **Step 9: Verify GREEN, full gate, and Web UAT**

Run unit, integration, quick, and full gates. Web UAT must execute: move 96px →
left click → SPACE → SPACE+left click → minimap click → door transition. Test
an invalid SPACE during attack and HUD click guard. In a separate fresh run,
wait five seconds and invoke the visible `안내 건너뛰기` control on PC and mobile;
assert the door opens and the compact legend remains. Repeat the normal path on
mobile with real touch buttons and minimap tap.

- [ ] **Step 10: Commit and merge**

Commit message: `[UI] 첫 방 성공 기반 조작 온보딩`. Capture each platform at the minimap and exit steps, finish the PR loop, and update P3/P6 coverage.

---

### Task 3: Contextual First-Run Journey

**Issue contract:** `[UI] 첫 런 보상·정화·대화 안내 연결` with `P0`, `area:ui`, `area:run`.

**Files:**
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/ui/session_ui_root.gd`
- Modify: `scripts/ui/purify_onboarding_spotlight.gd`
- Modify: `scripts/dev/day_corridor_movement_test.gd`
- Test: `tests/integration/test_session_contract.gd`
- Test: `tests/integration/test_day_corridor_movement_test.gd`
- Test: `tests/unit/test_touch_input.gd`

**Interfaces:**
- Consumes: existing `reward_choice_selected`, `friend_purified`, and `dialogue_requested` signals.
- Produces: `SessionRoot.get_onboarding_journey_snapshot() -> Dictionary` for the night-run phases.
- Produces: `DayCorridorMovementTest.get_onboarding_journey_snapshot() -> Dictionary` for the school phases.
- Persists the cross-scene checkpoint through the existing
  `SceneTransition.FLAG_ONBOARDING_BASEBALL_COMPLETE` and
  `SceneTransition.FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED` SaveManager flags.

- [ ] **Step 1: Write journey snapshot RED tests**

Add an integration test that starts the baseball onboarding layout and asserts snapshot phases in order:

```gdscript
_runner.assert_eq(session.get_onboarding_journey_snapshot()["phase"], &"combat")
session.call("_on_room_cleared_for_reward", {"room_id": &"combat_1", "room_type": &"combat"})
_runner.assert_eq(session.get_onboarding_journey_snapshot()["phase"], &"reward")
```

Continue through reward selected, friend intro, groggy, and purification. After
purification, free the session fixture, instantiate a fresh day-corridor fixture,
and prove its snapshot reconstructs `talk` from SaveManager. Assert `[E]`/touch
prompt and `dialogue_requested` advance to `bat_reward`; claiming the existing
captain reward advances to `complete`. Reinstantiate the day corridor after each
durable checkpoint to prove the phase survives scene replacement.

- [ ] **Step 2: Run integration tests and confirm RED**

Expected: missing `get_onboarding_journey_snapshot` and missing phase transitions.

- [ ] **Step 3: Implement scene-local state with an existing SaveManager handoff**

Add a session-local `StringName` phase and transition only from existing domain
signals. Do not create a global manager. At purification, keep the existing
`FLAG_ONBOARDING_BASEBALL_COMPLETE=true` write as the durable handoff before
`SceneTransition.go_to_day_lobby()` replaces `SessionRoot`. The fresh day
corridor derives `talk` when onboarding is complete and the captain reward is
unclaimed, keeps `bat_reward` as its local dialogue/reward phase, and derives
`complete` when `FLAG_BASEBALL_CAPTAIN_REWARD_CLAIMED=true`. Expose the same
duplicate snapshot schema from both scene roots: `phase`,
`completed_phases`, `current_instruction`, and `input_mode`.

```gdscript
const JOURNEY_PHASES: Array[StringName] = [
	&"combat", &"reward", &"friend_intro", &"purify", &"talk", &"bat_reward", &"complete",
]

func _advance_onboarding_journey(expected: StringName, next_phase: StringName) -> bool:
	if _onboarding_journey_phase != expected:
		return false
	_completed_onboarding_phases.append(expected)
	_onboarding_journey_phase = next_phase
	return true

func get_onboarding_journey_snapshot() -> Dictionary:
	return {
		"phase": _onboarding_journey_phase,
		"completed_phases": _completed_onboarding_phases.duplicate(),
		"current_instruction": _journey_instruction(_onboarding_journey_phase),
		"input_mode": _onboarding_input_mode(),
	}
```

The day-corridor snapshot must reconstruct its completed phases from the two
persisted flags rather than accepting a copied SessionRoot dictionary. Reloading
before reward claim safely returns to `talk`; reloading after reward claim
returns `complete`.

Use these exact contextual instructions:

```text
combat: 적을 쓰러뜨리면 다음 길이 열린다
reward: 카드 하나를 골라 이번 탐험을 강화
friend_intro: 공격해 기절시킨 뒤 가까이 다가가 정화
purify: 친구 곁에서 정화가 끝날 때까지 지키기
talk_desktop: [E] 야구부 주장에게 말 걸기
talk_touch: 야구부 주장 말 걸기
```

- [ ] **Step 4: Reuse existing UI surfaces**

Keep reward cards, `PurifyOnboardingSpotlight`, and the day-corridor interaction prompt. Standardize title/body spacing and input copy, but do not add another full-screen overlay. Preserve `test_id` and `uat_action` metadata.

- [ ] **Step 5: Verify event ordering and failure paths**

Tests must show an unrelated room clear, hidden reward button, early dialogue
input, attacking while a dialogue is open, or a scene reload before captain
reward claim cannot skip phases. Run integration and quick gates.

- [ ] **Step 6: Web UAT and merge**

Drive the full first-run journey with in-process UAT actions for non-coordinate pass/fail and screenshots for visual evidence. Verify PC E and mobile dialogue button. Commit: `[UI] 첫 런 맥락형 안내 연결`.

---

### Task 4: Parry Success Event and Repeatable Tutorial

**Issue contract:** `[Combat] 첫 늑대 패링 학습 추가` with `P0`, `area:player`, `area:enemy`, `area:ui`.

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `scripts/enemies/wolf.gd`
- Modify: `scripts/interactables/combat_room.gd`
- Create: `scripts/ui/parry_onboarding.gd`
- Modify: `scenes/session/session_root.tscn`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/autoload/scene_transition.gd`
- Test: `tests/unit/test_player_melee.gd`
- Test: `tests/unit/test_wolf_assets.gd`
- Test: `tests/unit/test_combat_room.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Produces: `Player.parry_succeeded(payload: Dictionary)`.
- Produces: `Wolf.dash_state_changed(state: StringName)`.
- Produces: `CombatRoom.enemy_spawned(enemy: Node, enemy_type: StringName, wave_index: int)` after each real spawn.
- Produces: `ParryOnboarding.show_for_wolf(wolf: Node2D, input_mode: StringName)` and `dismiss()`.
- Persists: `SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE := &"parry_tutorial_complete"`.

- [ ] **Step 1: Write parry-return RED tests**

Extend `tests/unit/test_player_melee.gd` so a fake dash enemy returns `false` outside dash and `true` during dash. Assert `parry_succeeded` emits exactly once only for `true` and includes `player_position`, `enemy_position`, and `direction`.

- [ ] **Step 2: Run unit tests and confirm RED**

Expected: no signal and the current player discards the return value.

- [ ] **Step 3: Implement the success event**

Capture the return value:

```gdscript
var parried := false
if _has_bat and enemy.has_method("parry_dash"):
	parried = bool(enemy.call("parry_dash", dir))
if parried:
	parry_succeeded.emit({
		"direction": dir,
		"player_position": global_position,
		"enemy_position": e.global_position,
	})
```

Do not emit on a normal hit, bare hands, non-dashing wolf, or repeated call after the wolf enters recovery.

- [ ] **Step 4: Write tutorial lifecycle RED tests**

Integration fixtures cover:

- hidden before bat reward;
- `SessionRoot` subscribes to `CombatRoom.enemy_spawned` during `room_changed`,
  before `CombatRoom.enter()` performs the initial spawn;
- shown on first eligible wolf `prepare`;
- shown for a wolf emitted by a later Task 7 wave, not only the initial wave;
- remains incomplete when the wolf dies without parry;
- appears again for the next wolf;
- successful parry sets the flag and prevents later prompts;
- room completion never waits for tutorial completion.

- [ ] **Step 5: Implement the non-blocking parry tutorial**

Add `dash_state_changed` to wolf transitions. Add `enemy_spawned` to
`CombatRoom` and emit it from `_spawn_enemy_instance()` after the enemy is in
the tree and tracked, for every initial or later wave. During
`SessionRoot._on_room_changed`, connect the current combat room's
`enemy_spawned` signal before `CombatRoom.enter()` runs; connect a wolf's
`dash_state_changed` from that spawn callback only when bat reward is claimed
and the completion flag is false. Do not scan `get_active_enemies()` only once
from `room_changed` because that event precedes encounter spawning. Mount
`ParryOnboarding` below modal layers, use the existing target spotlight style,
and never pause the tree after the first 0.6-second telegraph reveal.

```gdscript
func _on_wolf_dash_state_changed(state: StringName, wolf: Node2D) -> void:
	if state != &"prepare" or _is_parry_tutorial_complete():
		return
	parry_onboarding.show_for_wolf(wolf, _onboarding_input_mode())

func _on_player_parry_succeeded(payload: Dictionary) -> void:
	if _is_parry_tutorial_complete():
		return
	SaveManager.set_flag(SceneTransition.FLAG_PARRY_TUTORIAL_COMPLETE, true)
	parry_onboarding.dismiss()
```

Disconnect the combat-room spawn callback and all wolf callbacks when the room
changes or a wolf exits. Wolf death without the success callback leaves the
flag false. Task 7 must preserve `enemy_spawned` emission for every sequential
wave.

- [ ] **Step 6: Verify and merge**

Run unit, integration, quick, and full gates. UAT a missed dash, wolf death, next-wolf retry, and success. Commit: `[Combat] 첫 늑대 패링 학습 추가`.

---

### Task 5: Parry Text, Hit Stop, Flash, Shake, and Sound

**Issue contract:** `[Combat] 패링 성공 피드백 완성` with `P0`, `area:combat`, `area:ui`.

**Files:**
- Create: `scripts/autoload/hit_stop_manager.gd`
- Modify: `project.godot`
- Create: `scripts/ui/floating_combat_text.gd`
- Create: `scenes/ui/floating_combat_text.tscn`
- Create: `scripts/combat/parry_feedback_controller.gd`
- Modify: `scripts/enemies/wolf.gd`
- Modify: `scenes/session/session_root.tscn`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/autoload/audio_manager.gd`
- Add: `assets/audio/sfx/parry_success.wav` and `.import`
- Test: `tests/unit/test_hit_stop_manager.gd`
- Test: `tests/unit/test_player_melee.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Produces: `HitStopManager.request(duration: float, scale: float = 0.05) -> bool` and `restore() -> void`.
- Produces: `FloatingCombatText.initialize(position: Vector2, text: String, style: StringName) -> void`.
- Produces: `FloatingCombatText.style_for(style: StringName) -> Dictionary`.
- Consumes: `Player.parry_succeeded`.

- [ ] **Step 1: Write hit-stop RED tests**

Tests assert a longer request replaces a shorter request, a shorter request is ignored, real-time duration divides delta by current time scale, and `restore()` always sets `Engine.time_scale=1.0`.

- [ ] **Step 2: Run tests and confirm RED**

Expected: missing manager/autoload API.

- [ ] **Step 3: Implement `HitStopManager`**

Use `PROCESS_MODE_ALWAYS`, clamp duration/scale, track remaining real seconds, and restore in `_exit_tree`. Register it in `project.godot`. Add a session-exit defensive `HitStopManager.restore()`.

- [ ] **Step 4: Write parry presentation RED tests**

Record controller calls and assert exact order:

```gdscript
_runner.assert_eq(log, [&"text", &"hit_stop", &"flash", &"shake", &"sound", &"haptic"])
```

Add a pool-cap test that the 21st floating text is rejected while 20 are active.

- [ ] **Step 5: Implement presentation order**

`ParryFeedbackController` creates `받아쳤다` at the midpoint, requests `(0.10, 0.05)`, emits `combat_feedback` with `kind=&"parry"` and `intensity=9.0`, flashes white, plays `AudioManager.PARRY_SUCCESS`, and calls `HapticManager.on_deflect()`.

```gdscript
func present(payload: Dictionary) -> void:
	var player_position := payload.get("player_position", Vector2.ZERO) as Vector2
	var enemy_position := payload.get("enemy_position", Vector2.ZERO) as Vector2
	_spawn_parry_text((player_position + enemy_position) * 0.5, "받아쳤다")
	HitStopManager.request(0.10, 0.05)
	_flash_white()
	EventBus.emit_combat_feedback({
		"kind": &"parry",
		"direction": payload.get("direction", Vector2.RIGHT),
		"hit_count": 1,
		"intensity": 9.0,
	})
	AudioManager.play_sfx(AudioManager.PARRY_SUCCESS)
	HapticManager.on_deflect()
```

Remove the old direct `HapticManager.on_deflect()` call from `Wolf.parry_dash()` in this same slice so one successful parry produces exactly one strong haptic.

The parry style is fixed at 32pt, 1.0s, 20px rise, cyan/white glow, punch scale. Register a pool of 20 and reject further acquire attempts without allocating.

- [ ] **Step 6: Verify recovery and Web behavior**

Test session exit during hit stop, repeated parries, and Web frame pacing. Run full gate. UAT must capture before/impact/recovery frames and confirm time scale and camera offset return to defaults.

- [ ] **Step 7: Commit and merge**

Commit: `[Combat] 패링 성공 피드백 완성`. Publish impact screenshots and update F2/F4/S7/T1/T2/T6 coverage rows.

---

### Task 6: Portal Retry and Onboarding Exit Cleanup

**Issue contract:** `[Session] 포탈 재시도와 온보딩 종료 정리` with `P0`, `area:run`.

**Files:**
- Modify: `scripts/systems/room_door.gd`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/ui/session_ui_root.gd`
- Test: `tests/unit/test_room_door.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Preserves: `RoomDoor.request_transition() -> bool` and transition signals.
- Produces: `SessionRoot._finish_all_onboarding_ui() -> void` as an idempotent cleanup boundary.

- [ ] **Step 1: Write portal retry RED test**

Create a door with an overlapping actor, pause the tree, and assert the first check fails. Unpause without moving the actor and assert the next physics check succeeds exactly once.

- [ ] **Step 2: Confirm RED and implement latch-on-success**

Change `check_transition_for_actor` so `_was_actor_overlapping` becomes true only when `request_transition()` returns true. A failed request remains retryable while overlap continues. Keep the post-success latch preventing duplicate transitions.

```gdscript
if _was_actor_overlapping:
	return false
var transitioned := request_transition()
_was_actor_overlapping = transitioned
return transitioned
```

- [ ] **Step 3: Write onboarding cleanup matrix RED tests**

Cover completion, death, abandon, retry request, return to school, and scene
exit. In every path assert control onboarding, purify spotlight, parry hint,
camera zoom, touch visibility, pause state, and `Engine.time_scale` are
restored. Start a real `_camera_feedback_tween` that would write a nonzero
offset after cleanup, call the boundary, advance past the tween duration, and
assert the tween is killed/cleared and the camera offset remains
`Vector2.ZERO`.

- [ ] **Step 4: Implement one idempotent cleanup boundary**

Add `_finish_all_onboarding_ui()` and call it at every session termination/handoff entry point and `_exit_tree()`. Always place `onboarding_kind` in results built while the session latch is active, including death.

```gdscript
func _finish_all_onboarding_ui() -> void:
	if ingame_control_onboarding != null and ingame_control_onboarding.has_method("finish"):
		ingame_control_onboarding.call("finish")
	_finish_purify_onboarding_spotlight()
	if parry_onboarding != null:
		parry_onboarding.dismiss()
	get_tree().paused = false
	player_camera.zoom = Vector2.ONE
	if _camera_feedback_tween != null and _camera_feedback_tween.is_valid():
		_camera_feedback_tween.kill()
	_camera_feedback_tween = null
	player_camera.offset = Vector2.ZERO
	HitStopManager.restore()
```

Kill and clear `_camera_feedback_tween` before resetting the offset; assigning
`Vector2.ZERO` alone does not prevent the previous tween from writing a later
nonzero value while the death summary keeps the session scene alive.

- [ ] **Step 5: Verify and merge**

Run full gate and Web UAT the pause-over-portal and onboarding-death paths. Commit: `[Session] 포탈 재시도와 온보딩 종료 정리`.

---

### Task 7: Real Wave Spawning

**Issue contract:** `[Room] 전투 웨이브 순차 스폰 활성화` with `P1`, `area:rooms`, `area:enemy`.

**Files:**
- Modify: `scripts/interactables/combat_room.gd`
- Modify: `tests/unit/test_combat_room.gd`
- Modify: `tests/performance/test_room_perf.gd`

**Interfaces:**
- Preserves: authored `wave_count`, total encounter budget,
  `enemy_count_changed`, Task 4's `enemy_spawned` event, and room clear event.
- Produces: `get_wave_snapshot() -> Dictionary` with `configured`, `spawned`, `pending`, `active`.

- [ ] **Step 1: Replace the old full-spawn test with RED wave cases**

For six enemies and `wave_count=2`, assert three spawn initially, the second
three spawn only after the first wave reaches zero, and the room clears only
after wave two reaches zero. Add uneven `5/2` partition expecting `3+2`. Record
`enemy_spawned` payloads and prove every enemy in both waves emits exactly once,
including the second-wave wolf used by the parry tutorial.

- [ ] **Step 2: Run unit tests and confirm RED**

Expected: current while loop spawns all entries in wave one.

- [ ] **Step 3: Implement deterministic partitioning**

Compute remaining waves and use ceiling division:

```gdscript
var waves_left := maxi(1, wave_count - _waves_spawned)
var batch_size := ceili(float(_pending_spawn_entries.size()) / float(waves_left))
for _index in range(batch_size):
	_spawn_enemy_entry(_pending_spawn_entries.pop_front())
```

Emit active count after each batch and call `_spawn_next_wave()` only when active reaches zero.

- [ ] **Step 4: Verify performance and play balance**

Run unit, performance, quick, and full gates. Web UAT authored `combat_2` and verify two visible spawn moments, no empty-room clear, and total encounter count unchanged.

- [ ] **Step 5: Commit and merge**

Commit: `[Room] 전투 웨이브 순차 스폰 활성화`. Do not modify enemy speed in this PR. Update L1 coverage.

---

### Task 8: Chaser Pressure Calibration

**Issue contract:** `[Enemy] 악귀 추적 압박 조정` with `P1`, `area:enemy`.

**Files:**
- Modify: `scripts/enemies/chaser.gd`
- Modify: `scenes/enemies/akgwi.tscn`
- Modify: `tests/unit/test_chaser.gd`
- Modify: `tests/unit/test_akgwi_assets.gd`
- Modify: `tests/unit/test_combat_room.gd`
- Modify: `tests/performance/test_room_perf.gd`

**Interfaces:**
- Changes only: `Chaser.move_speed` default `90.0 -> 140.0`.
- Removes the serialized `move_speed = 92.0` override from
  `scenes/enemies/akgwi.tscn` so the scene preloaded by `CombatRoom` inherits
  the calibrated default.
- Preserves: contact range, damage, cooldown, spawn protection, movement bounds.

- [ ] **Step 1: Write the RED default-pressure test**

Instantiate both the base chaser and `scenes/enemies/akgwi.tscn`, assert each
has `move_speed == 140.0`, then assert `chase_velocity` remains normalized and
stops inside contact range. Add a combat-room test that inspects the actual
default AkGwi spawned through `CombatRoom` rather than the separate chaser
fixture.

- [ ] **Step 2: Run unit tests and confirm RED**

Expected: the script default is 90.0 and the instantiated AkGwi remains 92.0.

- [ ] **Step 3: Change only the default speed**

Set `@export var move_speed: float = 140.0` and remove the AkGwi scene's
serialized 92.0 override. Do not alter count, HP, contact damage, or elite
multiplier. Keep any explicit teaching-safe room-config override local to that
room rather than in the shared AkGwi scene.

- [ ] **Step 4: Verify after-wave playability**

Run quick/full/performance gates. In Web, play the first combat after Task 7 with keyboard and touch. Capture time-to-contact and first-room survival. If the first onboarding combat uses a chaser, keep its explicit room-config speed at the teaching-safe value rather than weakening the global default.

- [ ] **Step 5: Commit and merge**

Commit: `[Enemy] 악귀 추적 압박 조정`. Update M6a coverage with before/after UAT.

---

### Task 9: Combat SFX Cooldown and Missing Reaction Sounds

**Issue contract:** `[Audio] 전투 효과음 쿨다운 기반 추가` with `P1`, `area:combat`.

**Files:**
- Modify: `scripts/autoload/audio_manager.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/enemies/chaser.gd`
- Modify: `scripts/enemies/wolf.gd`
- Modify: `scripts/enemies/ranged_shooter.gd`
- Modify: `scripts/enemies/boss.gd`
- Add: `assets/audio/sfx/awakened_bat_reveal.wav` and import metadata
- Add: `assets/audio/sfx/player_hit.wav`, `enemy_hit.wav`, `enemy_death.wav`, `chaser_attack.wav`, `bare_hand_swing.wav` and import metadata
- Test: `tests/unit/test_audio_manager.gd`
- Test: `tests/unit/test_player_health.gd`
- Test: `tests/unit/test_enemy_death_feedback.gd`

**Interfaces:**
- Produces: `AudioManager.play_sfx(id: StringName, cooldown: float = 0.0) -> bool`.
- Produces: `AudioManager.can_play_sfx(id: StringName, now_seconds: float, cooldown: float) -> bool`.
- Preserves: all existing SFX ids and headless playback log behavior for accepted plays.

- [ ] **Step 1: Write cooldown RED tests**

Add:

```gdscript
func test_same_sfx_is_throttled_without_blocking_other_ids() -> void:
	AudioManager.reset()
	_runner.assert_true(AudioManager.can_play_sfx(&"enemy_hit", 10.0, 0.08), "first play is accepted")
	AudioManager.set("_last_sfx_played_at", {&"enemy_hit": 10.0})
	_runner.assert_false(AudioManager.can_play_sfx(&"enemy_hit", 10.04, 0.08), "same id inside cooldown is rejected")
	_runner.assert_true(AudioManager.can_play_sfx(&"player_hit", 10.04, 0.08), "different id is independent")
	_runner.assert_true(AudioManager.can_play_sfx(&"enemy_hit", 10.08, 0.08), "boundary play is accepted")
```

The test sets the real runtime dictionary directly; do not add a test-only production method.
Add a reset lifecycle assertion: seed `_last_sfx_played_at`, call the real
`AudioManager.reset()`, and prove an immediate same-ID play is accepted. This
catches cooldown state leaking between tests or audio lifecycles.

- [ ] **Step 2: Run unit tests and confirm RED**

Expected: missing `can_play_sfx` and new ids.

- [ ] **Step 3: Implement cooldown semantics**

Add:

```gdscript
var _last_sfx_played_at := {}

func can_play_sfx(id: StringName, now_seconds: float, cooldown: float) -> bool:
	if cooldown <= 0.0 or not _last_sfx_played_at.has(id):
		return true
	return now_seconds - float(_last_sfx_played_at[id]) >= cooldown

func play_sfx(id: StringName, cooldown: float = 0.0) -> bool:
	var now_seconds := Time.get_ticks_msec() / 1000.0
	if not _is_sfx_enabled() or not can_play_sfx(id, now_seconds, cooldown):
		return false
	_last_sfx_played_at[id] = now_seconds
	# Preserve the existing accepted-play load/player path here.
	return true
```

Only append to `_played_sfx` after cooldown acceptance.
`AudioManager.reset()` must also clear `_last_sfx_played_at` along with the
existing playback state.

- [ ] **Step 4: Add assets and exact event wiring**

Register ids `PLAYER_HIT`, `ENEMY_HIT`, `ENEMY_DEATH`, `CHASER_ATTACK`, `BARE_HAND_SWING`, and point `AWAKENED_BAT_REVEAL` at the real added file. Use cooldowns `0.12`, `0.06`, `0.08`, `0.18`, and `0.10` seconds respectively. Wire player damage, enemy damage/death, chaser attack start, and bare-hand swing start. Preserve Task 5's existing parry SFX path. Do not double-play enemy death from each enemy and a shared event in the same PR; this slice keeps the current enemy-local death calls until D3 is implemented.

```gdscript
const PLAYER_HIT := &"player_hit"
const ENEMY_HIT := &"enemy_hit"
const ENEMY_DEATH := &"enemy_death"
const CHASER_ATTACK := &"chaser_attack"
const BARE_HAND_SWING := &"bare_hand_swing"

const _SFX_COOLDOWNS := {
	PLAYER_HIT: 0.12,
	ENEMY_HIT: 0.06,
	ENEMY_DEATH: 0.08,
	CHASER_ATTACK: 0.18,
	BARE_HAND_SWING: 0.10,
}
```

Generate deterministic seed assets with the installed `/opt/homebrew/bin/ffmpeg`, then judge them in Web UAT rather than accepting them from waveform existence alone:

```bash
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "sine=frequency=1320:duration=0.32" -af "afade=t=out:st=0.18:d=0.14,volume=0.45" assets/audio/sfx/awakened_bat_reveal.wav
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "anoisesrc=color=brown:duration=0.16" -af "highpass=f=180,lowpass=f=1800,afade=t=out:st=0.06:d=0.10,volume=0.35" assets/audio/sfx/player_hit.wav
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "anoisesrc=color=white:duration=0.10" -af "highpass=f=500,lowpass=f=3800,afade=t=out:st=0.03:d=0.07,volume=0.18" assets/audio/sfx/enemy_hit.wav
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "sine=frequency=120:duration=0.28" -af "afade=t=out:st=0.08:d=0.20,volume=0.40" assets/audio/sfx/enemy_death.wav
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "sine=frequency=220:duration=0.18" -af "afade=t=out:st=0.06:d=0.12,volume=0.30" assets/audio/sfx/chaser_attack.wav
/opt/homebrew/bin/ffmpeg -y -f lavfi -i "anoisesrc=color=pink:duration=0.12" -af "highpass=f=300,lowpass=f=2400,afade=t=out:st=0.04:d=0.08,volume=0.20" assets/audio/sfx/bare_hand_swing.wav
```

If a seed sound fails the Web sell-test, tune its exact filter/volume in this issue and document the accepted command in the PR body; do not defer a known-bad asset.

- [ ] **Step 5: Verify and merge**

Run unit, quick, and full gates. Web UAT a multi-hit swing and simultaneous deaths; confirm accepted counts, no clipping, and errors empty. Commit: `[Audio] 전투 효과음 쿨다운 기반 추가`. Update S1/S3/S4/S5 coverage.

---

### Task 10: Player Damage and Low-Health Vignette

**Issue contract:** `[UI] 플레이어 피격 비네트 추가` with `P1`, `area:ui`, `area:player`.

**Files:**
- Create: `scripts/ui/damage_vignette.gd`
- Modify: `scenes/session/session_root.tscn`
- Modify: `scripts/autoload/settings.gd`
- Modify: `scripts/ui/settings_ui.gd`
- Test: `tests/unit/test_player_health.gd`
- Test: `tests/unit/test_settings.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Produces: `DamageVignette.on_health_changed(current: int, max_health: int) -> void`.
- Produces: `DamageVignette.get_snapshot() -> Dictionary`.
- Produces: `Settings.KEY_SCREEN_EFFECTS := "screen_effects_enabled"`.

- [ ] **Step 1: Write vignette state RED tests**

```gdscript
func test_damage_vignette_distinguishes_damage_heal_and_low_health() -> void:
	var vignette := DamageVignette.new()
	add_child(vignette)
	vignette.on_health_changed(5, 5)
	vignette.on_health_changed(3, 5)
	_runner.assert_true(vignette.get_snapshot()["damage_pulse_active"], "damage pulses red")
	vignette.on_health_changed(1, 5)
	_runner.assert_true(vignette.get_snapshot()["low_health_visible"], "critical health stays visible")
	vignette.on_health_changed(4, 5)
	_runner.assert_false(vignette.get_snapshot()["low_health_visible"], "healing clears low-health state")
	vignette.queue_free()
```

- [ ] **Step 2: Confirm RED and implement the CanvasLayer**

Use a full-rect `ColorRect`/gradient texture with `MOUSE_FILTER_IGNORE`, below modal UI. Track previous health, start a real-time tween on decreases only, and keep low-health alpha when `current/max <= 0.25`.

```gdscript
class_name DamageVignette
extends CanvasLayer

func on_health_changed(current: int, max_health: int) -> void:
	var safe_max := maxi(1, max_health)
	var damaged := _last_health >= 0 and current < _last_health
	_low_health_visible = float(current) / float(safe_max) <= 0.25
	if damaged and _screen_effects_enabled():
		_start_damage_pulse()
	_last_health = current
	_render_state()
```

- [ ] **Step 3: Add the settings contract**

Add `KEY_SCREEN_EFFECTS`, default true, setter/getter, settings row, and reuse
the complete `settings_changed` snapshot emitted once by `set_value()`. Test
disabled mode hides both states and cancels a running tween. Also disable
haptics first, toggle screen effects, and assert exactly one emitted snapshot
contains both `KEY_SCREEN_EFFECTS=false` and
`KEY_HAPTIC_ENABLED=false`; this catches a partial payload silently
re-enabling another setting consumer.

```gdscript
const KEY_SCREEN_EFFECTS := "screen_effects_enabled"

func set_screen_effects_enabled(enabled: bool) -> void:
	set_value(KEY_SCREEN_EFFECTS, enabled)

func is_screen_effects_enabled() -> bool:
	return bool(get_value(KEY_SCREEN_EFFECTS, true))
```

Do not emit `EventBus.settings_changed` again from the typed setter:
`set_value()` already calls `_emit_settings_changed()` with the full settings
dictionary, and existing consumers rely on a single complete snapshot.

- [ ] **Step 4: Verify and merge**

Run unit/integration/quick gates. Web UAT damage, healing, critical health, pause, and scene exit. Commit: `[UI] 플레이어 피격 비네트 추가`. Update F7/F7b/F7c coverage.

---

### Task 11: General Hit Stop

**Issue contract:** `[Combat] 일반 타격 히트스톱 연결` with `P1`, `area:combat`, `area:player`.

**Files:**
- Modify: `scripts/player/player.gd`
- Modify: `scripts/session/session_root.gd`
- Test: `tests/unit/test_player_melee.gd`
- Test: `tests/unit/test_player_health.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Consumes: `HitStopManager.request(duration: float, scale: float)` and `restore()` from Task 5.

- [ ] **Step 1: Write hit-kind RED tests**

```gdscript
func test_hit_stop_profile_matches_combat_result() -> void:
	_runner.assert_eq(PlayerScript.hit_stop_profile(false, false), {"duration": 0.03, "scale": 0.15})
	_runner.assert_eq(PlayerScript.hit_stop_profile(true, false), {"duration": 0.06, "scale": 0.08})
	_runner.assert_eq(PlayerScript.hit_stop_profile(false, true), {"duration": 0.05, "scale": 0.10})
```

- [ ] **Step 2: Confirm RED and implement profiles**

Add the pure profile helper. Request ordinary/power hit stop only when `hit_count > 0`; request player-damage hit stop only after damage is accepted past invulnerability.

```gdscript
static func hit_stop_profile(power_attack: bool, player_damaged: bool) -> Dictionary:
	if player_damaged:
		return {"duration": 0.05, "scale": 0.10}
	if power_attack:
		return {"duration": 0.06, "scale": 0.08}
	return {"duration": 0.03, "scale": 0.15}
```

- [ ] **Step 3: Verify overlap and recovery**

Tests assert parry `(0.10, 0.05)` beats every general request, rejected damage produces none, and session exit restores 1.0. Run full gate and Web UAT frame pacing.

- [ ] **Step 4: Commit and merge**

Commit: `[Combat] 일반 타격 히트스톱 연결`. Update F3/F8 coverage.

---

### Task 12: Damage Numbers and Display Setting

**Issue contract:** `[UI] 데미지 숫자와 표시 설정 추가` with `P1`, `area:ui`, `area:combat`.

**Files:**
- Modify: `scripts/ui/floating_combat_text.gd`
- Modify: `scripts/player/player.gd`
- Modify: `scripts/enemies/chaser.gd`
- Modify: `scripts/enemies/wolf.gd`
- Modify: `scripts/enemies/ranged_shooter.gd`
- Modify: `scripts/enemies/boss.gd`
- Modify: `scripts/enemies/yokai_friend.gd`
- Modify: `scripts/session/session_root.gd`
- Modify: `scripts/autoload/settings.gd`
- Modify: `scripts/ui/settings_ui.gd`
- Test: `tests/unit/test_player_melee.gd`
- Test: `tests/unit/test_yokai_friend.gd`
- Test: `tests/unit/test_settings.gd`
- Test: `tests/integration/test_session_contract.gd`

**Interfaces:**
- Produces: `Settings.KEY_DAMAGE_NUMBERS := "damage_numbers_enabled"`.
- Produces: `SessionRoot.spawn_combat_text(position: Vector2, text: String, style: StringName) -> bool`.
- Produces: `Player.combat_text_requested(position: Vector2, text: String, style: StringName)`.
- Changes: enemy `take_damage(amount: int) -> int` returns the clamped HP delta
  actually applied, with `0` for rejected damage.
- Changes: `YokaiFriend.take_damage(amount: int) -> int` returns the clamped
  stun-accumulator delta, with `0` outside attacking/chasing or during hit
  invulnerability.
- Consumes: Task 5's shared 20-node pool.

- [ ] **Step 1: Write style and cap RED tests**

```gdscript
func test_damage_text_styles_are_distinct_and_capped() -> void:
	_runner.assert_eq(FloatingCombatText.style_for(&"ordinary")["font_size"], 18)
	_runner.assert_eq(FloatingCombatText.style_for(&"power")["font_size"], 24)
	_runner.assert_eq(FloatingCombatText.style_for(&"player_damage")["font_size"], 20)
	for index in range(20):
		_runner.assert_true(_session.spawn_combat_text(Vector2.ZERO, str(index), &"ordinary"))
	_runner.assert_false(_session.spawn_combat_text(Vector2.ZERO, "overflow", &"ordinary"))
```

- [ ] **Step 2: Confirm RED and implement styles**

Use ordinary 18pt white/40px/0.8s, power 24pt yellow/40px/0.8s, player damage 20pt red/20px/0.5s. Check `PoolManager.get_active_count(&"floating_combat_text") >= 20` before acquire.

- [ ] **Step 3: Add and test the setting**

Add default-true `KEY_DAMAGE_NUMBERS`, settings row, and event propagation. `spawn_combat_text` returns false without acquiring when disabled.

```gdscript
const KEY_DAMAGE_NUMBERS := "damage_numbers_enabled"

func spawn_combat_text(position: Vector2, text: String, style: StringName) -> bool:
	if not Settings.get_value(Settings.KEY_DAMAGE_NUMBERS, true):
		return false
	if PoolManager.get_active_count(&"floating_combat_text") >= 20:
		return false
	var node := PoolManager.acquire(&"floating_combat_text", pooled_object_layer)
	if node == null:
		return false
	node.initialize(position, text, style)
	return true
```

- [ ] **Step 4: Wire real, clamped damage payloads**

For HP enemies, before subtraction capture `previous_hp`; after clamping HP to zero, return
`previous_hp - current_hp`. Return `0` when dead, invulnerable, or otherwise
rejected. Add a RED overkill test where a 1-HP enemy receives 5 damage and must
return `1`, plus a rejected-hit test returning `0`. In the player's melee loop,
use the returned value once:

```gdscript
var applied_damage := int(enemy.call("take_damage", dmg))
if applied_damage > 0:
	combat_text_requested.emit(enemy.global_position, str(applied_damage), &"power" if power_attack else &"ordinary")
```

`YokaiFriend` is also in the `enemy` group and is hit by the same player loop.
Clamp its accepted accumulator to `max_stun` and return
`new_stun_accum - previous_stun_accum`. Add real-scene tests proving a hit
needed to fill only 1 remaining stun point returns `1`, while a hit during
stun or hit invulnerability returns `0`. Do not cast a `void` return from any
node in the `enemy` group.

Player health changes surface the accepted `previous-current` delta near the health HUD.

- [ ] **Step 5: Verify and merge**

Run full gate and Web UAT ordinary, power, player damage, 20-cap, disabled setting, and hit-stop ordering. Commit: `[UI] 데미지 숫자와 표시 설정 추가`. Update T3/T4/T5/T7 coverage.

---

### Task 13: Final Combined Program Verification

**Files:**
- Modify: `docs/requirements/2026-08-22-improvement-coverage.md`
- Test: all existing gates and ignored local UAT scripts only

**Interfaces:**
- Consumes: the merged `origin/main` from Tasks 1–12.
- Produces: final goal-loop evidence packet; no new product behavior.

- [ ] **Step 1: Run fresh-main gates**

Create a fresh verification worktree from latest `origin/main`. Run `verify_quick.sh` and `verify_full.sh`; record exact counts and logs.

- [ ] **Step 2: Run the complete release Web journey**

Exercise intro auto progression, all first-run steps, school talk, bat reward, first-wolf miss/retry/success, waves, chaser pressure, player damage, ordinary hit, power hit, parry, and multiple deaths. Confirm no audio clipping, no time-scale leak, no more than 20 texts, and console/page/request errors empty.

- [ ] **Step 3: Audit and update every execution row**

For Q1–Q8 and their component rows, add issue, PR, merge SHA, test evidence, and UAT artifact. Do not mark a row complete from green tests that do not exercise its user-visible contract.

- [ ] **Step 4: Run independent Challenger and hand off**

Give the Challenger the approved spec, coverage ledger, merged diffs, raw logs, screenshots, and UAT scripts. Resolve every valid finding, replace the handoff packet, then request explicit `검수 완료`.

---

## Spec Coverage Matrix

| Approved spec section | Implemented by |
|---|---|
| Night intro auto-advance, black-gap bound, click/tap copy | Task 1 |
| First-room movement, attack, dash, power, minimap, exit success | Task 2 |
| Combat, reward, purification, school talk, bat-reward journey | Task 3 |
| First eligible wolf prompt, miss/death retry, success flag | Task 4 |
| `받아쳤다`, hit stop, flash, shake, parry sound/haptic | Task 5 |
| Portal retry and every onboarding/session cleanup path | Task 6 |
| Sequential waves without budget drift | Task 7 |
| Chaser 90→140 isolated balance change | Task 8 |
| SFX cooldown and missing first-impression audio | Task 9 |
| Damage pulse, low-health vignette, screen-effect setting | Task 10 |
| Ordinary/power/player-damage hit stop | Task 11 |
| Ordinary/power/player damage text, 20 cap, setting | Task 12 |
| Fresh-main gates, complete PC/mobile journey, ledger evidence | Task 13 |

No approved spec section is left without an implementation or verification task.

---

## Program Completion Audit

After Task 13's final verification:

- [ ] Every Q1–Q8 coverage row has issue, PR, merge SHA, test counts, and UAT artifact.
- [ ] Search the plan and spec for every interface name and confirm production/test spelling matches.
- [ ] Run `bash scripts/verify_full.sh` on fresh `origin/main`.
- [ ] Export release Web from fresh `origin/main` and execute the complete PC/mobile journey.
- [ ] Run an independent Challenger against the spec, coverage ledger, merged diffs, test logs, and Web artifacts.
- [ ] Produce a goal-loop handoff and request explicit `검수 완료`; never infer acceptance from green CI alone.
