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
