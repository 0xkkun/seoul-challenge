# Seoul Challenge Agent Guide

This repository is the Seoul Challenge Godot project. It was created from the
pixel-godot-template baseline, so keep the shared harness, autoload, pooling, and
interaction contracts stable unless a project change intentionally redesigns
them.

## Project Vocabulary

- Use Seoul Challenge vocabulary in game-specific scenes, scripts, assets, and
  tests.
- Keep generic harness, autoload, pooling, and interaction contracts stable unless
  a project change intentionally redesigns them.
- Keep local config, credentials, generated caches, and export outputs untracked.

## Baseline

- Godot: `4.6.3.stable.official.7d41c59c4`
- Standard non-.NET editor/runtime
- Main scene: `res://scenes/lobby/lobby.tscn`
- Dev scene: `res://scenes/dev/main_dev.tscn`
- Quick gate: `bash scripts/verify_quick.sh`
- Full gate: `bash scripts/verify_full.sh`

## Workflow

1. Pick one GitHub issue and assign it to yourself if it has no assignee (every issue must have an assignee). Then create a git worktree for it — never `checkout -b` in the main checkout. See `## Worktree` below.
2. Keep the PR focused on one verifiable contract.
3. Use the PR title format in `docs/pr-hygiene.md`, such as `[UI] 세션 컨트롤 추가`. PR titles/bodies and commit messages must be written in Korean (only the `[Area]` tag stays English).
4. Set assignee, milestone, priority label, and at least one `area:*` label before review.
5. Prefer Godot MCP for editor/runtime checks when available.
6. Fall back to CLI checks when MCP is unavailable.
7. Run `bash scripts/verify_quick.sh` before opening or updating a PR.
8. Run `bash scripts/verify_full.sh` before merging broad changes.
9. For UI-visible changes, follow `docs/pr-hygiene.md` `## UI Capture Flow`:
   capture the changed screen, push the image to the orphan `ui-previews` branch,
   and add the raw URL under `## UI 캡처` in the PR body.
10. When addressing GitHub review comments, reply with the change or rationale and
   resolve the review thread after the reply.

## Review & merge loop

Opening the PR is NOT the end of the task. Drive the PR to merge — do not stop
at "PR opened" and do not leave a green, review-clean PR sitting.

1. Open the PR as **ready (not draft)** and request the one codex review pass.
2. **Keep CI green.** If any check fails (`Quick verification` etc.), fix it in
   the same worktree and push until green. Never abandon a red PR — a red PR is
   your bug to fix, not a reason to stop.
3. **Wait for the codex review (1 pass).** If it requests changes, address them,
   push, and re-request review (loop). If it has no change requests, proceed.
   A `👍` reaction from Codex (`chatgpt-codex-connector[bot]`) on the PR body
   after a review request counts as the codex pass with no requested changes;
   when CI is green and there are no outstanding review comments, merge
   immediately instead of waiting for a formal review object.
4. **Merge as soon as CI is green AND the review has no outstanding change
   requests:** `gh pr merge <n> --merge --delete-branch`. Merge immediately;
   do not wait for a human unless the PR description explicitly asks for one.

Only stop short of merging when the PR body marks it as needing human sign-off,
or a merge conflict needs the orchestrator. Otherwise the loop ends in a merge.

## Worktree

Multiple agent sessions share this repository, so every code task MUST run in
its own git worktree. Working directly in the main checkout (`checkout -b`,
editing files, committing there) clobbers other sessions and is not allowed.

1. Create a worktree per issue, branched from `origin/main`:
   ```sh
   git fetch origin main
   git worktree add ../seoul-challenge-<issue> -b <branch> origin/main
   ```
2. Edit, run, verify, and commit ONLY inside that worktree directory.
3. Deliver results as branch commits / a PR — never copy files into the main checkout.
4. Never `checkout` another session's branch in the main checkout.
5. Branch and worktree deletion is the human's job — do not run `branch -D` or
   `git worktree remove` yourself.

Allowed in the main checkout without a worktree: read-only inspection
(`git log`, reading files), shared-config edits, and merges the user requested.

## Godot MCP Checks

Use these when available:

- `get_godot_version`
- `run_project`
- `create_scene`
- `save_scene`
- `get_uid`

MCP success is not enough by itself. Always inspect the diff and run the verification scripts.

## Android Device UAT Rules

Godot UI renders inside an Android `SurfaceView`, so Android native view tools
cannot select Godot nodes by `test_id`. Treat `test_id` and `uat_action` as
in-process Godot contracts, not Android view IDs.

- Keep debug Android builds installable and identifiable as a debug package. Use
  `com.oxkkun.afterschool.debug` for debug APKs and export them as
  `build/android/afterschool.debug.apk`.
- When a Godot `Control`/`Button` must respond to phone taps, keep
  `input_devices/pointing/emulate_mouse_from_touch=true`; otherwise keyboard or
  pad focus can work while real touch does not emit the expected GUI button
  press.
- Before judging a real-device launch or input bug, clear stale Android debugger
  wait state with `adb shell am clear-debug-app`, then relaunch and verify with
  screenshots before and after the input.
- Do not verify UI buttons on Android with screen coordinates such as
  `adb shell input tap`, `input tap <x> <y>`, or `tap_pct`.
- Do not use app-private `user://` command files, `run-as` shell redirection, or
  `/data/data` path writes as the primary device UAT transport.
- Local/headless tests may press controls through the in-process Godot harness
  by `test_id` or `uat_action`.
- Real device automation must enter Godot through an explicit debug-only bridge,
  such as localhost TCP/WebSocket with `adb forward`, and assert app state/log
  transitions rather than coordinate-tap success.
- Screenshots are evidence for visual review; they are not the pass/fail control
  path for button interaction.
- To build a debug APK and install/launch it on a device for visual
  playtesting, see [docs/android-build.md](docs/android-build.md).

## Mobile Landscape Safe-Area Rules

Design and review mobile UI against a **landscape phone** baseline, not a
desktop window. The canonical design viewport is 960x540, and UI touching the
edges must remain clear of left/right notches, punch holes, rounded corners, and
the bottom home-indicator/gesture bar.

- Treat these 960x540 margins as the minimum safe-area fallback: left/right
  `60px`, top `24px`, bottom `34px`.
- Core touch controls and primary combat buttons need extra touch comfort:
  prefer at least `72px` from left/right and `58px` from the bottom.
- Bottom CTAs such as map entry, run entry, and return buttons must sit at least
  `40px` above the bottom edge.
- Reuse `scripts/ui/mobile_safe_area.gd` for safe-area constants/helpers instead
  of scattering ad-hoc edge offsets.
- Preserve `test_id` and `uat_action` contracts when moving controls for
  safe-area compliance; Android UAT still enters Godot through those contracts,
  not coordinate taps.

## Naming Rules

- Use shared names such as `session_root`, `sample_actor`, `sample_interactable`, `InteractionSystem`, and `SessionSummaryUI`.
- Do not copy private project references, store identifiers, real service keys, or sample-specific vocabulary into reusable template files.
- Keep external SDK integrations disabled by default. Add adapter slots and examples instead of live integrations.

## Commit Hygiene

Do not commit:

- `.godot/`
- `build/`
- `exports/`
- `test-results/`
- local config files under `config/`
- service credentials or generated secrets

Commit asset-side Godot import metadata when real source assets are added.
