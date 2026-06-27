# Testing

The template uses Godot headless scenes plus small Python static checks.

## Commands

```sh
bash scripts/verify_quick.sh
bash scripts/verify_full.sh
```

Quick verification covers:

- environment and Godot version
- static project contract
- import metadata hygiene
- secret hygiene
- headless editor load
- unit tests
- integration tests

Full verification adds:

- functional smoke
- runtime smoke for the main scene
- runtime smoke for the dev scene
- tooling regression checks

## Rooms Gate

```sh
bash scripts/verify_rooms.sh
```

The rooms gate protects the room, event-room, layout-generation, and currency
domain separately from the shared quick gate. It runs:

- `scripts/verify_room_coverage.py` to ensure every active domain script has a
  mapped test file
- headless Godot runtime coverage for the fixed room route
- performance budgets for `RoomLayoutGenerator`, layout validation, and
  `RoomManager.request_next_room()`

Future room-domain scripts must be added to the manifest in
`scripts/verify_room_coverage.py`. Placeholder manifest entries can stay disabled
until the corresponding script lands, but an existing script with a disabled or
missing manifest entry fails the gate.

## Web Preview

```sh
bash scripts/export_web_preview.sh
```

The Web Preview harness exports the existing Godot `Web` preset to
`build/web/index.html`. PRs run the read-only `Web Preview` build job, upload the
exported `build/web/` folder as a `web-preview-pr-<number>` artifact, and publish
same-repo PR builds from that artifact to the `web-previews` branch under
`pr-<number>/`. The workflow cancels older build runs for the same PR, and the
shared branch publish job is serialized so concurrent PRs cannot race on
`web-previews`.

Use Web Preview for fast browser-based UI and flow review. Keep Android device
checks for touch, safe-area, orientation, export, or platform-rendering risks.
If GitHub Pages is enabled with source set to `GitHub Actions`, the workflow
deploys the full `web-previews` branch through the official Pages artifact path.
The PR preview URL is:

```text
https://0xkkun.github.io/seoul-challenge/pr-<number>/
```

Fork PRs and manual runs still upload the artifact, but skip branch publishing
because the workflow token may not have write permission. Same-repo PRs also
skip the live URL when GitHub Pages is disabled or still configured for a branch
source; the artifact remains the review fallback.

## Test Locations

- `tests/unit/`
- `tests/integration/`
- `tests/performance/`
- `tests/functional/`
- `tests/tooling/`
- `tests/support/test_runner.gd`

Every `test_*` method must execute at least one assertion.

## Branch Protection

Recommended `main` protection:

- require pull requests before merging
- require the `Quick verification` status check
- require the `Rooms gate` status check for room-domain PRs
- require branches to be up to date before merging
- allow administrators to bypass only for repository recovery

Enable protection after the first green CI run confirms the workflow name and status check label.
