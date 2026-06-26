# Seoul Challenge Agent Guide

This repository is the Seoul Challenge Godot project. It was created from the
pixel-godot-template baseline, so keep the shared harness, autoload, pooling, and
interaction contracts stable unless a project change intentionally redesigns
them.

## Project Vocabulary

- Use Seoul Challenge vocabulary in game-specific scenes, scripts, assets, and
  tests.
- Keep generic harness, autoload, pooling, and interaction contracts neutral.
- Keep local config, credentials, generated caches, and export outputs untracked.

## Baseline

- Godot: `4.6.3.stable.official.7d41c59c4`
- Standard non-.NET editor/runtime
- Main scene: `res://scenes/lobby/lobby.tscn`
- Dev scene: `res://scenes/dev/main_dev.tscn`
- Quick gate: `bash scripts/verify_quick.sh`
- Full gate: `bash scripts/verify_full.sh`

## Workflow

1. For that issue, create a git worktree — never `checkout -b` in the main checkout. See `## Worktree` below.
2. Keep the PR focused on one verifiable contract.
3. Use the PR title format in `docs/pr-hygiene.md`, such as `[UI] Add session controls`.
4. Set assignee, milestone, priority label, and at least one `area:*` label before review.
5. Prefer Godot MCP for editor/runtime checks when available.
6. Fall back to CLI checks when MCP is unavailable.
7. Run `bash scripts/verify_quick.sh` before opening or updating a PR.
8. Run `bash scripts/verify_full.sh` before merging broad changes.

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

## Naming Rules

- Use neutral names such as `session_root`, `sample_actor`, `sample_interactable`, `InteractionSystem`, and `SessionSummaryUI`.
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
